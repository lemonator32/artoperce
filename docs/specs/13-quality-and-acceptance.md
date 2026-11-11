# 13 — Quality, Performance, Security, Acceptance, and Delivery

This file defines what "done" means for Artoperce. A release candidate must meet every P0 criterion in §5 and every budget in §2.

## 1. Scope

- Performance budgets (§2)
- Device and test matrix (§3)
- Reliability, security, privacy, and observability (§4)
- Acceptance criteria by area (§5)
- Open product questions (§6)
- Feature-to-phase mapping (§7)

## 2. Performance budgets

Measured on the reference device unless noted. Report the 50th, 95th, and 99th percentiles. A regression of more than 10% against the previous release candidate blocks release.

| Metric | Budget |
|---|---|
| Interactive drawing frame rate | At least 60 fps for typical canvas sizes. Higher refresh rates supported when available. |
| Stroke latency (input sample to visible mark) | Median under 30 ms. Tail latency measured and reported. |
| Stabilization lag | At Stabilization 50%, added lag at most 60 ms. |
| Pan, zoom, and rotate | No visible stutter with a medium-complexity document open. |
| Cold start to gallery | Under 2.0 s (median). The gallery is usable before all thumbnails load. |
| Open a typical document (4096 × 4096, 20 layers) | Under 3.0 s to the first drawable frame. Remaining tiles load progressively. |
| Brush switch | Under 100 ms to be drawable. |
| Layer thumbnail refresh | Under 500 ms after a stroke. |
| Full-canvas adjustment apply | Under 1.5 s for a 4096 × 4096 layer. |
| Undo or redo step | Under 100 ms for a typical stroke. Under 500 ms for a full-layer operation. |
| Export PNG (4096 × 4096) | Under 5 s. |
| Adjustment preview update while dragging | Under 50 ms. |
| Panel response | State changes shown immediately. Large lists populate progressively. |
| Autosave | A completed stroke is committed promptly. Background serialization never blocks drawing. |
| Sustained 30-minute drawing session | Frame rate below 50 fps for under 5% of frames. No unbounded memory growth. |
| Thermal and battery | No forced frame-rate reduction in a 30-minute session at room temperature. Background work (time-lapse encoding, thumbnails) pauses in low-power mode. |
| Time-lapse recording overhead | Under 3% of frame time. |

## 3. Device, platform, and test matrix

### 3.1 Devices

| Tier | Requirement |
|---|---|
| Minimum | At least 3 GB RAM. GPU supporting the platform's current graphics API. Canvas limits follow [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1. The app tells the user the effect of memory limits. |
| Reference | Landscape tablet, high-resolution display, pressure-sensitive stylus, at least 4 GB RAM. |
| Highest end | Highest-capability supported device. Used for upper-bound tests. |

### 3.2 Platform support

- **Orientation:** landscape and portrait, with state preserved across rotation.
- **Multitasking:** split-screen and floating windows down to 480 × 480 pt. The canvas stays responsive when resized.
- **Input:** the app works with finger only, stylus only, and mouse or trackpad. It detects stylus capability at runtime and never assumes tilt or hover.
- **OS support:** the current and previous major releases. The policy is documented and enforced at install.

### 3.3 Test matrix

Run acceptance on the reference device and on at least one minimum-tier device. Each tier is tested with and without a stylus.

## 4. Reliability, security, privacy, and observability

### 4.1 Reliability

- Autosave after each committed stroke and structural change, using transactional writes or the recoverable journal (see [12-data-and-engine.md](12-data-and-engine.md) §4).
- Atomic replacement or append-only semantics. An interruption cannot leave a half-written project as the only copy.
- On startup, validate the most recent state and offer recovery if the last save was interrupted.
- Keep a safe checkpoint before destructive operations (flatten, resample, crop, format conversion).
- Undo and redo remain consistent after save, load, and migration.
- Log operation failures with codes. Never log artwork contents or private data.

### 4.2 Resource management

- Monitor memory for layer buffers, temporary strokes, adjustment previews, brush textures, and undo history.
- Release inactive previews and cache resources with a predictable eviction policy.
- Under memory pressure: save pending work, warn before an operation that cannot proceed, and offer options. Never flatten or discard content silently.

### 4.3 Network

- The core drawing app makes **no network requests** while drawing.
- Any future network feature must be opt-in and encrypted in transit (see [11-extensions.md](11-extensions.md) §14).

### 4.4 Security

| Risk | Required control |
|---|---|
| Malformed image, PSD, or PDF | Parse in a restricted, time-limited context. Reject on size, dimension, or decompressed-size limits. Fuzz test every parser. |
| Archive bombs (project, brush, palette) | Cap total uncompressed size and file count. Refuse path traversal entries (`..` or absolute paths). Never extract outside the package sandbox. |
| Untrusted brush or palette packages | Contain data only. No executable code, scripts, or network references. |
| Imported fonts | Validate with the system font parser. Do not run font hinting programs from untrusted files outside platform protections. |
| Clipboard and drag content | Validate type and size before use. Paste never runs an action beyond creating a layer. |
| Local data | Rely on platform file protection. Documents are unreadable while the device is locked. |
| Dependencies | Track third-party libraries and their licenses. Update promptly for published vulnerabilities. |

### 4.5 Privacy

- Artwork, time-lapse data, and imported references never leave the device unless the user shares them.
- Exports strip metadata (author, location, device information) by default. The user may add an author name and copyright.
- Diagnostic reports and crash logs exclude artwork, titles, and file paths unless the user chooses to attach them.
- Permissions (photo library, files, camera for palette capture) are requested at the point of use, with a plain-language reason. Microphone is not used.
- Analytics: off by default or opt-in. Aggregate only. No artwork content. A visible setting disables it (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1.8).

### 4.6 Storage lifecycle

- Projects live in the app's private storage. The gallery is a view over that storage.
- Export copies data out. It never moves it.
- Free-space checks run before create, duplicate, export, and import.
  - Below 200 MB free: show a warning.
  - Below 50 MB free: block operations that need writes, except saving the current document.
- Autosave and recovery journals are cleaned after a successful save or after 7 days.
- Uninstalling the app or clearing its data removes all local artwork. The first-run text and the settings screen explain this and point to export and backup.
- Documents are kept in a backup-friendly location. Caches and temporary files are excluded from backup.

### 4.7 Observability and safe mode

- Crash reports are collected only with the user's consent.
- Operation failures are logged with codes. Artwork content is never logged.
- Performance counters are recorded in memory and included in the diagnostic report.
- **Safe mode:** offered after two consecutive crashes. Disables hardware acceleration and third-party resources.

## 5. Acceptance criteria

Each criterion is a test. Automated tests are noted where a criterion lends itself to one.

### 5.1 Canvas and input

- **A1.** Given a new canvas, when the user draws with a supported pressure stylus, then a stroke appears at the correct document coordinates and reflects pressure changes.
- **A2.** When the user pinches and rotates the canvas, then the viewport changes and the underlying pixel data is unchanged. *(automated)*
- **A3.** When the finger-input option is on, a single-finger drag creates a stroke. When it is off, the same drag navigates. *(automated, integration)*
- **A4.** When the user undoes and redoes a stroke, the visible result returns exactly to the prior and subsequent state. *(automated, property-based)*
- **A5.** With a stylus stroke in progress, a two-finger tap does not undo.
- **A6.** Palm contact within the rejection window never creates a mark. Hover never creates a mark.
- **A7.** A second finger landing within 120 ms of the first cancels the first finger's stroke, removes its pixels, and adds no undo entry.
- **A8.** Pinch, pan, stylus drawing, and panel interactions do not cause accidental marks or lose document state. *(integration)*

### 5.2 Brushes

- **B1.** Changing spacing in the Brush Editor visibly changes stamp separation on the Drawing Pad.
- **B2.** Changing Stabilization changes the Drawing Pad stroke without exceeding the lag budget in §2.
- **B3.** Changing the shape or grain source updates the Drawing Pad to show the new texture.
- **B4.** Cancel in the Brush Editor leaves the original brush unchanged.
- **B5.** Apply saves the new settings. After closing and reopening the project, the saved brush uses them.
- **B6.** Replaying a stored stroke with its seed on the same brush reproduces the original pixels exactly. *(automated, golden)*
- **B7.** Opening a document created before a brush update renders its existing strokes with the stored brush snapshot.

### 5.3 Color, layers, and export tolerance

- **C1.** Choosing a swatch makes it the active drawing color and the color used by the next stroke.
- **C2.** Sampling a visible pixel returns a color that matches the displayed composite within **±2 per 8-bit sRGB channel**.
- **C3.** Hiding a layer removes its contribution to the composite. Showing it again returns its content unchanged.
- **C4.** Changing opacity or blend mode changes only that layer's compositing.
- **C5.** Duplicating or reordering a layer keeps its pixel content identical, and the composite updates correctly.
- **C6.** Every blend mode in [07-layers-and-selection.md](07-layers-and-selection.md) §3.2 matches reference output within **±1 per 8-bit channel**, with no NaN or out-of-range values. *(automated, golden)*
- **C7.** Painting black on a layer mask hides pixels without altering layer data. Applying the mask bakes it in. One undo restores it.
- **C8.** A flattened PNG export matches the visible canvas within the tolerance in C2, and keeps transparency when the background is hidden. *(automated)*

### 5.4 Recovery

- **R1.** Killing the process immediately after a committed stroke, then reopening, recovers the stroke or offers a valid recovery copy.
- **R2.** Killing the process 100 times at random points during stroke commits leaves the project loadable every time, with at most the in-progress stroke lost. *(soak and chaos)*
- **R3.** When export is canceled or fails, the source project is intact.

### 5.5 Adjustments and transforms

- **D1.** For every effect, the same parameters and seed produce identical output on preview and Apply. *(automated)*
- **D2.** Cancel after an adjustment leaves the layer byte-identical to its prior state. *(automated)*
- **D3.** Curves: the canvas updates live while points move. Apply creates one undo step.
- **D4.** Transform cancel restores the exact pre-transform pixels.
- **D5.** Liquify and Clone commit as one undo step each.

### 5.6 Shape Snap, Quick Fill, and symmetry

- **E1.** Drawing an approximate circle and holding for 500 ms produces a circle within 4% tolerance, with an Edit Shape chip. One undo reverts to the freehand stroke, and a second removes it.
- **E2.** Dropping a color on a closed outline with a 2 px gap fills inside only. Raising gap closing to 4 px fills a 3 px gap correctly. One undo removes the fill.
- **E3.** With quadrant symmetry on, one stroke yields four mirrored stamps per sample, byte-identical after mirroring, in one undo step. *(automated, golden)*

### 5.7 Gestures and settings

- **G1.** Every gesture can be disabled or remapped.
- **G2.** A conflicting gesture or shortcut assignment is refused with a named conflict.
- **G3.** Every function remains reachable through the assistive alternatives in [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §3.

### 5.8 Layer limit and documents

- **L1.** On a 4096 × 4096 canvas, the New Canvas screen shows a maximum layer count equal to the formula in [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1 for the device's memory budget. Adding layers beyond it is blocked with the documented alternatives.
- **L2.** A project saved by version N opens in version N+1 and is migrated on a copy. An older reader refuses a newer major version without altering it. *(automated, fixtures)*
- **L3.** Time-lapse: a canvas resample inserts a keyframe, and replay shows the resampled result. Exporting a 30-second version completes without changing the project. *(automated)*

### 5.9 Import safety

- **I1.** A corpus of malformed and oversized files is rejected without crash or hang within the documented limits. *(fuzz)*
- **I2.** A supported layered document imports with compatible layers and blend properties still editable (P1).
- **I3.** Importing a native project with a newer `minReaderVersion` is refused with an explanation.

### 5.10 Accessibility

- **X1.** Screen-reader users can navigate the gallery, layer panel, settings, and menus, and can open, rename, duplicate, and export documents.
- **X2.** The canvas exposes an accessible description of the current tool, active layer, zoom, and selection, and announces changes.
- **X3.** Non-canvas interface elements meet WCAG 2.2 AA.
- **X4.** No function requires a gesture lasting longer than 3 seconds.

## 6. Open product questions

These decisions change scope or cost. Each has a provisional default in this specification set, which applies until the product team decides otherwise.

| Question | Provisional default | Where it applies |
|---|---|---|
| Is frame animation in the first public release? | Deferred to P1. | [11-extensions.md](11-extensions.md) §1 |
| Is a text tool required for 1.0? | Deferred to P1. | [11-extensions.md](11-extensions.md) §2 |
| Are CMYK and print soft-proofing in scope? | P2. | [11-extensions.md](11-extensions.md) §6.1 |
| Which minimum device and OS define the memory budget? | Not decided. Must be decided before phase 3 because it sets the layer capacity. | [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1 |
| Is cross-platform support (desktop, Android, web) planned? | Tablet-first. Desktop builds are P1 (see [01-overview.md](01-overview.md) §3.1). Android and web are out of scope for 1.0. | [01-overview.md](01-overview.md) §3.1 |
| Which languages ship at launch? | English for 1.0. | [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §6 |
| Native file extension and registration | `.artoperce` (D1). Registration to confirm with the platform. | [12-data-and-engine.md](12-data-and-engine.md) §1 |
| Does project sharing include time-lapse by default? | No. Explicit choice each time (D15). | [09-import-export-timelapse.md](09-import-export-timelapse.md) §6.2 |
| Does the app offer cloud sync or backup, and under which privacy terms? | Not planned for 1.0. | [11-extensions.md](11-extensions.md) §14 |
| Who owns brush, palette, and texture content, and what are the licensing rules for bundled assets? | Artoperce owns all bundled assets. Each must be original and licensed for redistribution. | [05-brushes.md](05-brushes.md) §11, [06-color.md](06-color.md) §4.5 |

## 7. Feature-to-phase mapping

The seven phases and exit conditions are defined in [01-overview.md](01-overview.md) §7. This table maps each specification area to the phase where it lands.

| Phase | Specification areas |
|---|---|
| 1. Canvas foundation | Layer-limit formula and size limits ([03](03-gallery-and-documents.md) §6.1); presets ([03](03-gallery-and-documents.md) §6.3); gesture arbitration and base gestures ([04](04-canvas-and-input.md) §3–§4); package layout, tile storage, journal, undo contract ([12](12-data-and-engine.md) §1–§5); error model ([12](12-data-and-engine.md) §9); gallery and documents ([03](03-gallery-and-documents.md) §1–§5) |
| 2. Painting experience | Pressure calibration and curve ([04](04-canvas-and-input.md) §5.3; [10](10-settings-accessibility-help.md) §1.3); color panel modes, palettes, eyedropper ([06](06-color.md) §1–§5; [04](04-canvas-and-input.md) §10); Quick Fill ([04](04-canvas-and-input.md) §7); eraser and smudge rules ([05](05-brushes.md) §13); brush library ([05](05-brushes.md) §1) |
| 3. Brush customization | Brush Editor parameter reference ([05](05-brushes.md) §2–§8); stamp pipeline and seed ([05](05-brushes.md) §4.4); shape and grain editors ([05](05-brushes.md) §5.3); default library ([05](05-brushes.md) §11); `.brush` and `.brushset` ([05](05-brushes.md) §12; [12](12-data-and-engine.md) §6) |
| 4. Composition | Compositing model and blend catalog ([07](07-layers-and-selection.md) §3); layer panel and menu ([07](07-layers-and-selection.md) §2); masks and recolor ([07](07-layers-and-selection.md) §4, §6); alpha lock and clipping ([07](07-layers-and-selection.md) §5) |
| 5. Editing tools | Selection ([07](07-layers-and-selection.md) §7); transform ([07](07-layers-and-selection.md) §8); adjustment framework and catalog ([08](08-adjustments-guides-reference.md) §1–§2); Liquify and Clone ([08](08-adjustments-guides-reference.md) §4–§5); Drawing Guides and assisted drawing ([08](08-adjustments-guides-reference.md) §3); Shape Snap ([04](04-canvas-and-input.md) §6); reference window ([08](08-adjustments-guides-reference.md) §6) |
| 6. Project exchange | Format matrix and import rules ([09](09-import-export-timelapse.md) §1–§2); export ([09](09-import-export-timelapse.md) §3–§4); time-lapse ([09](09-import-export-timelapse.md) §5); sharing ([09](09-import-export-timelapse.md) §6); gallery additions (stacks, trash, preview) ([03](03-gallery-and-documents.md) §2–§5); canvas information ([03](03-gallery-and-documents.md) §7); settings catalog ([10](10-settings-accessibility-help.md) §1) |
| 7. Hardening | Performance tuning ([13](13-quality-and-acceptance.md) §2); reliability and recovery ([13](13-quality-and-acceptance.md) §4.1–§4.2); security and fuzzing ([13](13-quality-and-acceptance.md) §4.4); accessibility and localization ([10](10-settings-accessibility-help.md) §4, §6); device matrix ([13](13-quality-and-acceptance.md) §3); help and onboarding ([10](10-settings-accessibility-help.md) §5) |
| After 1.0 (P1/P2) | Frame animation ([11](11-extensions.md) §1); text ([11](11-extensions.md) §2); shapes and gradients ([11](11-extensions.md) §3–§4); harmony and palette capture ([06](06-color.md) §3–§4.3); PSD and PDF ([09](09-import-export-timelapse.md) §1); 3D painting ([11](11-extensions.md) §5); tiled preview ([11](11-extensions.md) §7); CMYK and 16-bit ([11](11-extensions.md) §6) |

Every P0 item lands by phase 6. Phase 7 is required for release.

## 8. Final release checklist

- [ ] Every P0 acceptance criterion in §5 passes on the reference device.
- [ ] Every P0 acceptance criterion in §5 passes on a minimum-tier device.
- [ ] Every budget in §2 is met, or a documented exception is approved.
- [ ] Format fixtures for every shipped format version open and round-trip (§5.8, L2).
- [ ] Fuzzing corpus is clean (§5.9, I1).
- [ ] Accessibility audit is complete (§5.10).
- [ ] No provenance language, third-party names, or source-product references appear in the app, its strings, or its files.
- [ ] Every open question in §6 has a recorded decision.
