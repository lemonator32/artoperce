# 01 — Overview

## 1. Purpose

Artoperce lets an artist sketch, paint, ink, texture, composite, and finish raster artwork on a tablet with a pressure-sensitive stylus. The primary experience is a large, unobstructed canvas surrounded by compact tools that open on demand and close quickly. Drawing must feel immediate, and the editability expected of a professional graphics application must be preserved.

### 1.1 Primary goals

1. Low-latency freehand drawing with stylus pressure and tilt, and finger input as a usable fallback.
2. A configurable brush engine supporting different materials, stroke dynamics, textures, and blending.
3. Complex images built from independently editable layers.
4. Accurate color selection, reusable palettes, and eyedropper workflows.
5. A full project lifecycle: create, name, organize, reopen, duplicate, import, export, and recover.
6. Editing tools for selections, transforms, drawing aids, and image adjustments.
7. Work is preserved through autosave, undo and redo, and a crash-safe project format.

### 1.2 Success outcomes

| Area | Outcome |
|---|---|
| Drawing feel | A stroke follows the stylus with stable pressure response and no visible lag. |
| Workflow efficiency | Common actions take one or two deliberate interactions. The canvas stays the visual priority. |
| Editability | Layers, masks, selections, and transforms allow changes without repainting unrelated content. |
| Reliability | Interruption never loses a committed stroke or corrupts a project. |
| Interchange | Flattened images and a layered format can be exported. Native projects reopen with full editability. |

## 2. Product principles

1. **Canvas first.** Tools and panels do not dominate the work area when closed.
2. **Progressive disclosure.** Essential controls are visible first. Advanced brush and layer options live in focused panels.
3. **Immediate feedback.** Previews, sliders, brush samples, layer changes, and adjustments update as the user interacts.
4. **Reversible work.** Undo and redo are reliable. Destructive edits use preview-and-commit or masks.
5. **Predictable gestures.** Gestures are discoverable, configurable, and protected from accidental activation while drawing.
6. **Portable projects.** The native project is separate from flattened exports. Interchange behavior is explicit.
7. **Deterministic output.** The same inputs, seed, and parameters always produce the same pixels. This makes replay, undo, export, and tests reliable.

## 3. Platform and input

### 3.1 Target devices

- **Reference device:** landscape tablet, high-resolution touch display, pressure-sensitive stylus with tilt where the hardware reports it, at least 4 GB RAM.
- **Minimum supported device:** at least 3 GB RAM and a GPU supporting the platform's current graphics API. On this device the app states the effect of memory limits to the user (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1).
- **Orientation:** landscape and portrait. The workspace re-lays out without losing state.
- **Multitasking:** split-screen and floating windows down to 480 × 480 pt. The canvas stays responsive when resized.
- **Desktop support (P1):** a windowed build with mouse, trackpad, and keyboard shortcuts uses the same workspace and command set. Desktop-only additions are listed in [04-canvas-and-input.md](04-canvas-and-input.md) §8.

### 3.2 Input sources

The app must distinguish stylus, finger, mouse, and trackpad input at runtime. It must never assume tilt, hover, barrel buttons, or squeeze. Settings that depend on missing hardware are hidden or disabled with a note, never silently ignored.

| Source | Required behavior |
|---|---|
| Pressure stylus | Draws by default. Uses pressure, tilt, azimuth, and barrel roll when reported. |
| Finger | Draws only when "Draw with finger" is on. Otherwise it navigates and triggers gestures. |
| Mouse / trackpad | Click-drag draws with constant pressure. Scroll and pinch navigate. Keyboard modifiers apply. |
| Accessibility path | Every multi-finger gesture has a single-pointer equivalent (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §3). |

## 4. Scope

### 4.1 In scope for 1.0

Gallery and document lifecycle; new canvas with presets; raster painting with pressure and tilt; brush library and Brush Editor; color panel; layers with blend modes, masks, alpha lock, clipping, and groups; selection and transform; core adjustments; Drawing Guides and assisted drawing; reference window; undo and redo; autosave and recovery; PNG, JPEG, TIFF, and native export; image import; time-lapse recording and replay; settings; accessibility basics.

### 4.2 Deferred

Frame animation, text layers, vector-style shape tools, gradients, PSD and PDF interchange, 3D painting, CMYK, 16-bit documents, tiled canvas preview, and cloud sync. Each is specified in [11-extensions.md](11-extensions.md) and tagged P1 or P2 where it is defined in other files.

### 4.3 Out of scope

- Real-time co-editing and collaboration.
- Vector editing of artwork (SVG import and export).
- A brush marketplace.
- Network features in the core drawing path. The core app makes no network requests while drawing (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.3).

## 5. System architecture

### 5.1 Subsystems

| Subsystem | Responsibility |
|---|---|
| UI / Interaction | Toolbars, panels, gestures, navigation, accessible controls, state transitions. |
| Input service | Pointer sampling, pressure and tilt normalization, coordinate conversion, prediction, gesture arbitration. |
| Brush engine | Brush presets, stroke resampling, stamp generation, dynamics, stabilization, texture sampling, wet mix, live previews. |
| Canvas renderer | Layer compositing, blend modes, masks, selections, guides, transforms, display color conversion. |
| Document service | Project model, layer tree, metadata, save and load, migration, thumbnails, autosave, journal. |
| History service | Undo and redo command stack, memory accounting, checkpoints. |
| Color service | Color profiles, conversions, palettes, eyedropper sampling, export color management. |
| Adjustment service | Effect registry, parameter validation, previews, commit. |
| Import/export service | Format readers and writers, flattening, layered interchange, progress, error reporting. |
| Time-lapse service | Operation capture, keyframe scheduling, replay, compression, video export. |
| Settings service | Settings catalog, persistence per device, change notification. |

### 5.2 Extension points

Brush attributes, adjustment effects, import and export formats, blend modes, and guide types are registered through interfaces. Each registration has a stable identifier. The document schema must define compatibility behavior for every registered identifier, including identifiers an older reader does not know.

### 5.3 Rendering model

- Document pixels are stored independently of screen pixels.
- Layers are split into fixed-size tiles of 256 × 256 px. The renderer tracks dirty tiles and re-renders only those after a stroke or local adjustment.
- Display compositing uses the GPU when available. It applies each visible layer's opacity, blend mode, mask, clipping, and group isolation in layer order.
- In-progress strokes are drawn into a temporary stroke buffer. On pen-up the buffer is composited into the layer as one undoable operation.
- Layer composites and thumbnails are cached. Invalidation is per tile.

### 5.4 Threading

- Input sampling and gesture recognition run on a high-priority path. They never wait for disk I/O, encoding, or export.
- Thumbnail generation, compression, import, export, and non-interactive adjustments run on background workers and support cancellation.
- Stroke rendering takes priority over time-lapse encoding and thumbnail refresh.
- A new preview request for the same adjustment cancels the stale one.

## 6. Interaction quality requirements

- Direct manipulation. Strokes appear with low latency and follow the pointer closely.
- Touch targets are at least 44 × 44 pt. Selected states are obvious without relying on color alone.
- Frequent controls use non-modal popovers and panels. Complex brush editing and canvas setup use full-screen modal screens.
- Every control has a label, a value, and an accessible name. A slider supports fine adjustment and numeric entry where precision matters.
- Opening and closing a panel preserves tool state and canvas viewport. Dismissal returns focus to the canvas.
- Destructive actions are visually distinct, state what they affect, and are undoable where practical.

## 7. Delivery phases

Build in vertical slices. Each phase ends with a usable workflow. The mapping of specification areas to phases is in [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §7. Acceptance criteria for each phase are in §5 of the same file.

| Phase | Deliverables | Exit condition |
|---|---|---|
| 1. Canvas foundation | Gallery, new canvas, viewport pan and zoom, raster layer, stylus input, package save and load, undo and redo, layer-limit formula, gesture arbitration base, error model | Create a document, draw, close it, reopen it, and continue without losing content. |
| 2. Painting experience | Brush library, core brush engine, size and opacity controls, color panel, palettes, eyedropper, pressure calibration, Quick Fill, eraser and smudge rules | Paint and sketch with several brush behaviors and repeatable colors. |
| 3. Brush customization | Brush Editor with all groups, shape and grain sources, stabilization, taper, dynamics, `.brush` and `.brushset` import and export, default library | Modify, save, duplicate, and reuse brushes reliably. |
| 4. Composition | Layer panel, visibility, opacity, blend modes, reorder, duplicate, merge, alpha lock, clipping, masks, recolor | Build and edit a multi-layer artwork without destructive workarounds. |
| 5. Editing tools | Selection, transform, Curves, core adjustments, Drawing Guides, assisted drawing, Shape Snap, reference window | Revise regions and finish artwork using reversible previews. |
| 6. Project exchange | PNG, JPEG, TIFF, native export, image import, canvas information, time-lapse recording and replay, sharing, settings catalog | Move artwork into and out of the app and share outputs. |
| 7. Hardening | Performance tuning, recovery testing, accessibility audit, localization, device matrix, security fuzzing | Meets the budgets and acceptance criteria in [13-quality-and-acceptance.md](13-quality-and-acceptance.md). |

Every P0 item lands by phase 6. Phase 7 is required for release.
