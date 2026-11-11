# Artoperce for iOS / iPadOS — Implementation Plan

Status: draft for review. Source of truth for behavior is `docs/specs/` (start at [00-README.md](../specs/00-README.md)). This plan covers *how* to build it in Swift. Where the spec is silent on a technical choice, this plan makes one and says so.

## 1. Scope and targets

- **Primary target:** iPad (landscape and portrait, Split View and Slide Over down to 480 × 480 pt). Apple Pencil is the reference input.
- **Secondary:** iPhone is not in the spec. Do not build iPhone layouts in 1.0. Keep the app universal only if it costs nothing; otherwise iPad-only.
- **Desktop (macOS "Designed for iPad" or Catalyst):** P1. Keep the engine free of UIKit so a later macOS target can reuse it.
- **Out of scope for 1.0** (see spec §4.2–4.3): frame animation, text, shapes, gradients, PSD/PDF, 3D, CMYK, 16-bit, cloud sync, collaboration, any network call in the drawing path.

### 1.1 Decisions this plan makes

| # | Decision | Reason |
|---|---|---|
| T1 | **OS support: current and previous major iPadOS release** (spec §3.2). As of this plan that is iPadOS 27 and 26; set the deployment target to the previous major and confirm it at project setup. | Spec policy. Keeps the SwiftUI `DocumentGroup` and Metal features used below available without fallbacks. |
| T2 | **Swift 6 language mode** for the engine module; UI module may stay on Swift 5 mode while migrating. | Strict concurrency catches data races in the render and I/O workers (spec §5.4). |
| T3 | **No third-party dependencies.** Use Apple frameworks only: Metal, Compression, CryptoKit, UIKit, SwiftUI. | Privacy and no-network rule (spec §4.3, §13 §4.3); fewer supply-chain risks (spec §4.4). |
| T4 | **Do not use PencilKit.** Build a custom stamp engine. | PencilKit cannot meet the brush model (spec §5), Glaze/Blending modes, Wet Mix, or deterministic output. |
| T5 | **Canvas view is UIKit** (`UIView` subclass hosting a `CAMetalLayer`) wrapped into SwiftUI with `UIViewRepresentable`. Panels, Brush Editor, gallery, and settings are SwiftUI. | Raw `UITouch` access (force, altitude, azimuth, coalesced and predicted touches) is needed for the input pipeline; SwiftUI gesture modifiers are not precise enough. |
| T6 | **Rendering is Metal.** CPU fallback (Core Graphics or Accelerate) only for the Phase 1 raster path and for tests. | Tile compositing, blend modes, and dirty-tile re-rendering (spec §5.3) are GPU work. |
| T7 | **Pixel format: premultiplied RGBA8** (`.rgba8Unorm`) for layer tiles and render targets; masks are `.r8Unorm`. | Spec §3 mandates premultiplied 8-bit. |
| T8 | **Tile compression: LZ4** via `Compression` framework (`COMPRESSION_LZ4`). **Checksums: CRC-32C** implemented in-house (small, table-driven) or SHA-256 via CryptoKit for manifest hashes. | Spec §3 allows zstd or LZ4; Apple's `Compression` has LZ4, not zstd. Avoids a dependency. |
| T9 | **Document package: directory form** (`.artoperce` folder) with a `UTType` conforming to `com.apple.package`, managed through `UIDocument` / `DocumentGroup`. ZIP form for export only. | Spec D1, D14, §1.1. |
| T10 | **Gallery owns its library** in the app container (Application Support). Files app access through `LSSupportsDocumentBrowser` and exported UTI, so users can open and move packages. | Keeps the spec's gallery model (stacks, trash, selection) under app control. |

## 2. Architecture

Three Swift packages (or local modules inside one Xcode project), with a strict dependency direction: `Engine` ← `Document` ← `App`.

```
ArtoperceEngine      (no UIKit, no SwiftUI; testable on macOS CI)
  Geometry           points, rects, affine transforms, document-pixel conversion
  Pixels             RGBA8 premultiplied buffers, mask buffers, blend math (CPU reference)
  Tiles              256 × 256 tile store, dirty tracking, LZ4 codec, CRC-32C
  Brush              preset model (Codable, versioned), stamp generator, dynamics, stabilization, taper, seeded RNG
  Render             Metal renderer: tile compositing, blend modes, masks, selection overlay, guides overlay
  Color              sRGB / Display P3 conversion, palettes (.swatches), Color Dynamics math
  Adjust             effect registry and implementations (Color Balance, HSB, Curves, Halftone, Blur, Sharpen, Noise)
  Transform          affine transform preview and commit
  Selection          8-bit mask ops, boolean ops, refinement
  Guides             Drawing Guide geometry and snapping (project data only)

ArtoperceDocument    (depends on Engine)
  Package            .artoperce directory I/O, manifest.json (Codable), atomic replace, path-safety checks
  Journal            append-only journal.log, commit markers, recovery replay
  History            undo/redo command stack, before-image store, memory budget (25% of canvas budget, ≥100 steps)
  Commands           one type per undoable operation (spec §5.2)
  Autosave           background serialization queue, debounced
  TimeLapse          event log and keyframes (P0 for recording/replay per spec §5)
  Import / Export    PNG, JPEG, TIFF via ImageIO; native ZIP; flattening; export report

ArtoperceApp         (SwiftUI + UIKit)
  Gallery            grid/list, thumbnails, selection mode, stacks, trash, rename, duplicate
  Workspace          canvas host (UIKit), top bar, left rail, Actions panel, popovers, drawers
  Input              UITouch pipeline, gesture arbitration, Pencil actions, keyboard shortcuts
  BrushUI            brush library, Brush Editor (full-screen), Drawing Pad (isolated renderer)
  ColorUI            Color panel (Disc, Classic, Value, Palettes), eyedropper loupe
  LayersUI           layer panel, options menu, mask and clipping controls
  Settings           settings catalog (spec §10 §1), gesture configuration, Help
```

### 2.1 Threading model (spec §5.4)

- **Main thread:** UI state and `UITouch` handling only. Samples are appended to a lock-free ring buffer and handed to the render actor. Never block on I/O.
- **Render actor (serial, high-priority QoS `.userInteractive`):** brush stamping, stroke buffer compositing, dirty-tile invalidation. Owns the Metal command queue for strokes.
- **I/O actor (`.utility`):** tile writes, journal appends, manifest writes, thumbnails.
- **Background workers (`.utility`, cancellable):** import, export, non-interactive adjustments, time-lapse encoding (lowest priority, pauses in Low Power Mode via `ProcessInfo.isLowPowerModeEnabled`).
- A new preview for the same adjustment cancels the previous task (`Task.cancel()` checked at tile boundaries).

### 2.2 Stroke path (spec §4.4, §5.3, §8.1 in 12-data-and-engine)

1. `touchesBegan/Moved` → read `force`, `altitudeAngle`, `azimuthAngle(in:)`, `timestamp` from coalesced touches; use `predictedTouches` only for the preview stroke, never for stored samples.
2. Convert view points to document pixels via the viewport transform *before* storing (spec Conventions).
3. Stabilization and resampling in the Brush module (deterministic, no wall-clock input).
4. Stamps drawn into a per-stroke **stroke buffer** (GPU texture, sized to the dirty bounding box).
5. On pen-up: journal record `committed: false` → write dirty tiles atomically → journal commit marker → manifest atomic replace (spec §4.2). Then composite the stroke buffer into the layer as one undo step.

### 2.3 Determinism (spec §2 principle 7)

- All randomness goes through a seeded PRNG (e.g., SplitMix64) seeded from the stroke record. Never use `Float.random` or system RNG in the engine.
- Stamp math uses `Float` consistently on CPU and GPU; the same stamp list must produce the same pixels on CPU reference and GPU path within the tolerance in spec §5.3.
- Golden-image tests run the CPU reference path in CI (no GPU variance). GPU output is compared against the CPU reference within tolerance on device.

## 3. Phases

The spec defines seven phases (spec §7; mapping in spec §13 §7). Each phase below lists the Swift work, the exit test, and the risks. Each phase must end with a usable build on device.

### Phase 1 — Canvas foundation
**Work**
- Xcode project, packages, CI (GitHub Actions or Xcode Cloud) running `swift test` on Engine and Document on macOS.
- Gallery shell with `DocumentGroup`-backed document type; `.artoperce` UTType declared in Info.plist.
- `CAMetalLayer` canvas host; viewport transform (pan, zoom, rotate) with two-finger and one-finger gestures from spec §4 §4 and §3 arbitration.
- Raster layer with tile store; single "draw" brush (a simple round stamp, pressure→size only).
- Package save/load (manifest, tiles, journal, thumbnail); autosave on background queue.
- Undo/redo for strokes; before-image store.
- Layer-limit formula (spec §03 §6.1) using `ProcessInfo.processInfo.physicalMemory` and `os_proc_available_memory()` for the "available RAM" input; show live count on New Canvas.
- Error model: typed `ArtoperceError` with codes from spec §12 §9.2 surfaced as alerts.

**Exit test:** create, draw with Pencil and finger, close, reopen, continue; force-quit during 20 random stroke commits (automated via a debug kill switch) and reopen every time.

**Risks:** Gesture conflicts between Pencil and finger (`UIGestureRecognizer` delegate rules needed; prototype early). Metal texture memory for large canvases.

### Phase 2 — Painting experience
**Work**
- Brush library (Codable presets, `.brush` read/write later in Phase 3); size and opacity controls with the brush cursor (spec §05 §9).
- Pressure curve and calibration (spec §04 §5.3; stored in settings).
- Color panel: Disc, Classic, Value, Palettes; `.swatches` import/export; recent colors; eyedropper with loupe (magnified via `Metal` snapshot of the canvas, not `UIView.drawHierarchy`).
- Quick Fill (P1 per spec, but listed in Phase 2 — schedule it here only if the eraser/smudge rules need flood fill).
- Eraser and smudge rules (spec §05 §13).
- Color management: convert to working space; export tagging per spec §06 §6.

**Exit test:** paint with at least four brush behaviors, reuse colors from palettes, and sample from the canvas with the eyedropper.

**Risks:** Color accuracy in Display P3 vs sRGB; decide the working space before this phase starts (proposal: sRGB working space, Display P3 display conversion).

### Phase 3 — Brush customization
**Work**
- Full Brush Editor (full-screen SwiftUI, all attribute groups from spec §05 §2–§8) with the Drawing Pad as an isolated `MTKView` that never touches layers.
- Shape and grain sources (images stored under `resources/`), grain scale and movement.
- Stabilization (with the 60 ms lag budget at 50%), taper, dynamics, stylus curves (spec §05 §7.4 curve editor).
- Rendering modes: six Glaze and Blending modes (D4). Wet Mix (spec §05 §6.3) — schedule last in this phase; it is the highest-risk rendering item.
- `.brush` and `.brushset` import/export (spec §05 §12), with conflict handling and schema validation (`Codable` with explicit version checks, unknown keys preserved).
- Default library: 11 categories (D10). Assets must be original and licensed for redistribution (spec §13 §6). Asset creation is a content task, not code; track it as a blocker.

**Exit test:** modify, save, duplicate, and reuse a brush after relaunch; import a `.brushset` with a conflict and resolve it.

**Risks:** Wet Mix performance; the 100 ms brush-switch budget with large grain textures (preload and cache grain by content hash).

### Phase 4 — Composition
**Work**
- Layer tree (groups, raster layers, reference layers) in the manifest; layer panel (SwiftUI list with drag reorder); visibility, opacity, blend modes (catalog in spec §07 §3.2; non-separable modes in §3.4).
- Merge, duplicate, reorder, group undo steps (spec §5.2).
- Masks: 8-bit mask tiles; paint on mask; apply, disable, invert.
- Alpha lock and clipping masks in the renderer (Metal blend stage per layer).
- Recolor (P1): schedule after the rest of Phase 4 if time is short.

**Exit test:** build a 10-layer artwork with clipping, masks, and blend modes; undo and redo every operation; re-open and compare pixels to a golden image.

**Risks:** Blend-mode parity between CPU reference and Metal shaders. Keep one shader per mode with a CPU test for each.

### Phase 5 — Editing tools
**Work**
- Selection: marquee, lasso, magic wand, boolean ops, refinement; mask visibility default 25% (D3); copy, paste, duplicate.
- Transform: free, scale, rotate, flip with preview and commit as one undo step; snapping.
- Adjustments: framework with live preview (throttled, cancellable); Color Balance, Hue/Saturation/Brightness, Curves (Curves editor in SwiftUI), Halftone (D6), Gaussian Blur, Sharpen, Noise. Preview under 50 ms while dragging: run on a downsampled tile set and refine on release.
- Drawing Guides: 2D Grid, Isometric, Perspective, Symmetry; assisted drawing; guides are never exported (D16).
- Shape Snap (P1) and Liquify and Clone (P1): schedule after the P0 set.
- Reference window (floating, resizable, not undoable, not document content).

**Exit test:** revise a region with selection, transform, and an adjustment; undo each; export without guides.

**Risks:** Adjustment performance on 4096 × 4096 layers (budget 1.5 s). Use Metal compute kernels, not CPU loops.

### Phase 6 — Project exchange
**Work**
- Export PNG, JPEG, TIFF via `ImageIO` with the metadata and color rules in spec §09 §3–§4; export report and failure handling.
- Import images via `PHPicker`, Files, and drag and drop (`UIDropInteraction`), with import safety from spec §13 §5.9.
- Native export as ZIP with path-safety checks (spec §12 §1.2): reject `..`, absolute paths, and entries outside the package; cap uncompressed size and file count.
- Time-lapse recording (event log plus keyframes) and replay; recording overhead under 3% of frame time; export video via `AVAssetWriter`.
- Sharing: `UIActivityViewController`; "Include time-lapse" choice each time, default off (D15).
- Gallery additions: stacks, trash (with the 7-day rule), preview, duplicate.
- Settings catalog (spec §10 §1) and Help tab.

**Exit test:** round-trip a document through ZIP export and import with pixel equality; import a malicious ZIP fixture and confirm rejection.

**Risks:** Video export under memory pressure; cancel and resume rules.

### Phase 7 — Hardening
**Work**
- Instruments: Metal System Trace, Time Profiler, Allocations, Leaks. Check every budget in spec §13 §2 at p50, p95, p99.
- Recovery testing: process kill during commits (automated), disk full, interrupted ZIP import.
- Security fuzzing: `Codable` manifests, brush files, ZIP entries, PNG and JPEG imports (libFuzzer-style harness via Swift packages or a small custom driver).
- Accessibility audit: VoiceOver labels and values on every control (spec §10 §4), Dynamic Type where applicable, Reduce Motion, Full Keyboard Access, Switch Control.
- Localization scaffolding: String Catalogs; English only for 1.0 (spec §13 §6).
- Device matrix: reference iPad (≥4 GB RAM) and minimum tier (≥3 GB RAM), each with and without Pencil (spec §13 §3.3).
- Privacy: no network calls (verify with a network-blocked UI test run), privacy manifest (`PrivacyInfo.xcprivacy`) listing required-reason APIs used.

**Exit:** every P0 acceptance criterion in spec §13 §5 passes; release checklist in spec §13 §8 signed off.

## 4. Testing strategy

| Layer | Tool | What it proves |
|---|---|---|
| Engine unit | XCTest on macOS CI | Blend math, brush stamp generation, dynamics curves, RNG determinism, tile codec round-trip, CRC checks |
| Property tests | XCTest with generators | Undo then redo restores pixels exactly (spec §5.5); commit order invariants |
| Golden images | CPU reference renderer, committed PNG fixtures | Brush and blend output does not change unintentionally |
| Crash and recovery | Debug-only kill switch plus harness that relaunches the app | Spec §4.5 durability target |
| Document format | Fixture packages from each format version | Migration and unknown-key preservation (spec §12 §7) |
| Security | Malformed ZIP, JSON, and image fixtures | Path safety and limits (spec §13 §4.4) |
| UI | XCUITest for flows, plus manual Pencil testing on device | Gesture arbitration, panel behavior, accessibility |
| Performance | XCTest `measure` plus Instruments traces on device | Budgets in spec §13 §2 |

Pencil and tilt cannot be fully simulated. Any change to the input pipeline needs a manual device pass, recorded in the phase exit notes.

## 5. Project setup checklist

1. Create the Xcode project (iPad app, SwiftUI lifecycle, Swift 6, iPadOS 17 minimum), bundle ID owned by the team, `.artoperce` exported UTType (`com.apple.package` conformance, file extension `artoperce`).
2. Add `ArtoperceEngine` and `ArtoperceDocument` as local Swift packages with test targets.
3. Add CI: `swift test` on both packages on every push.
4. Set up the `PrivacyInfo.xcprivacy` file and the empty network policy test.
5. Commit a fixture directory `Tests/Fixtures/` with one `.artoperce` package per format version.
6. Confirm the reference device specs with the product team (spec §13 §6: memory budget must be decided before Phase 3).

## 6. Open items that block work

| Item | Blocks | Owner |
|---|---|---|
| Minimum device and OS for the memory budget (spec §13 §6) | Layer capacity formula final values; must be decided before Phase 3 | Product |
| Final working color space (sRGB proposed) | Phase 2 color panel and export | Product and engineering |
| Brush and texture asset creation, with licensing | Phase 3 default library | Art |
| Apple Developer account, bundle ID, and `.artoperce` UTType registration (spec §13 §6) | Phase 1 on-device testing | Product |
| Wet Mix acceptance tolerance | Phase 3 exit | Engineering and art |

## 7. Immediate next steps

1. Resolve the open items that block Phase 1 (Apple Developer setup, bundle ID, UTType).
2. Create the project skeleton and CI from §5.
3. Implement the Phase 1 engine pieces first (Tiles, Package, Journal, History) with tests, before any UI. These carry the spec's reliability requirements and are the hardest to retrofit.
4. Build the canvas host and the stroke path, then measure stroke latency on a real iPad before writing more UI.
