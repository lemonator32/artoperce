# 08 — Adjustments, Drawing Guides, and Reference Window

## 1. Adjustment framework

### 1.1 Entry and panel

- The **Adjustments** button (magic wand) in the top bar opens the adjustments menu. The menu lists effects by category (Color, Blur, Detail, Stylize, Liquify, Clone).
- Choosing an effect opens a panel at the bottom (landscape) or side (wide portrait) with its controls. The panel stays open until Apply or Cancel.
- A top title bar on the canvas shows the active adjustment name and a dropdown chevron. The button turns blue while an adjustment is active.
- A **More (…)** button offers Reset to defaults, and Apply and Cancel. Previous and next adjustments are available in P1.

### 1.2 Targets

| Target | Behavior | Priority |
|---|---|---|
| Layer | Applies to the whole active layer, or to the selection if one exists. The scope is named in the title bar. | P0 |
| Pencil | Applies only where the user paints with the stylus, using a chosen brush. Strokes define a mask of influence. | P0 |
| Adjustment layer | Non-destructive adjustment as a layer. | P2 |

- Hidden layers are never modified.
- Adjustments never read from other layers, except where the effect samples the composite (Clone source modes and Liquify source modes).

### 1.3 Live preview and scrubbing

- Every control change updates the preview immediately.
- Previews render at reduced resolution while a control is being dragged. Each update takes under 50 ms. Full quality renders on release.
- **Scrubbing:** dragging one finger horizontally across the canvas changes the effect's primary parameter. The parameter name and value appear in a pill at the top of the canvas. Two-finger gestures still pan and zoom.
- The viewport remains usable during previews.

### 1.4 Commit and cancel

- **Apply** commits the result as one undo step.
- **Cancel** restores the layer exactly. The layer is byte-identical to its state before the adjustment opened.
- Changing the adjustment type while one is open asks whether to apply or cancel the current one.

### 1.5 Determinism

- The same parameters and seed produce identical output in preview and in Apply, at full quality.
- Effects that use randomness take a seed. The seed is stored in the operation record.
- Effects process at least 16-bit floating point internally, then convert to the document bit depth.

### 1.6 Brush-applied adjustments (Pencil target)

- The user chooses a brush, then paints over the artwork. The effect applies at each stamp with the stamp's opacity and flow.
- Painting uses the same stamp pipeline as paint (see [05-brushes.md](05-brushes.md) §4.4).
- Apply commits the accumulated influence as one undo step.

## 2. Effect catalog

Each entry gives parameters with range and default, and the algorithm notes needed to implement it.

### 2.1 Color

**Hue / Saturation / Brightness** (P0)
- Hue −180° to 180° (default 0). Saturation −100% to 100% (default 0). Brightness −100% to 100% (default 0).
- Operates in HSB. Clamped. Alpha preserved.

**Color Balance** (P0)
- Three paired sliders: Cyan ↔ Red, Magenta ↔ Green, Yellow ↔ Blue. Each −100 to 100, default 0 at center.
- P1: separate Shadows, Midtones, and Highlights tabs. Tone ranges are defined by overlapping luminance weighting curves.
- Alpha preserved.

**Curves** (P0; histogram P1)
- Composite (RGB) curve, and individual Red, Green, and Blue curves where the document color model supports them.
- Up to 16 points per curve. Gamma control.
- Interpolation is monotone cubic, so the curve has no overshoot.
- Output is a 256-entry lookup table.
- Controls: add a point by tapping the curve, move a point by dragging, delete a point by dragging it off the graph or using Delete.
- Endpoints stay at the graph edges unless "Endpoint movement" is enabled (P1).
- A square graph with an input–output curve, labeled axes or endpoint cues, and a neutral diagonal default.
- Reset to default and a preview toggle (before and after) are available.
- Acceptance: the canvas updates live while curve points move; Cancel restores the original; Apply creates one undo step.

**Gradient Map** (P1)
- Up to 16 color stops. Maps the luminance of each pixel to a gradient. Output = gradient(luminance). Alpha preserved.

**Invert** (P1)
- Inverts color values of the target. Alpha preserved.

### 2.2 Blur

**Gaussian Blur** (P0)
- Radius 0–500 px (default 0).
- Separable kernel. Above 100 px radius, use repeated box blur as an approximation.
- Layer or Pencil target.

**Motion Blur** (P1)
- Distance 0–500 px (default 0). Angle 0–360° (default 0°).
- Linear directional blur. Edge option: wrap or clamp.

**Perspective Blur** (P1)
- Distance 0–500 px. A draggable origin point.
- Radial or zoom blur from the origin.

### 2.3 Detail

**Sharpen** (P0)
- Amount 0–100% (default 0). Radius 0.1–10 px.
- Unsharp mask. A clipping warning appears at extreme values.

**Noise** (P0)
- Amount 0–100% (default 0). Scale 1–50 px. Mono or color. Seed.
- Seeded so preview and Apply match.
- Blended in linear light.

### 2.4 Stylize

**Halftone** (P0)
- Title shows the size percentage, for example "Halftone 22%".
- **Size:** 1–100%, default 22%. Larger values give larger dots.
- **Angle:** 0–90°, default 45°. Rotates the dot screen.
- **Style** (segmented control):
  - **Full Color:** each color channel is screened separately, with a different angle per channel.
  - **Screen Print:** a single-color dot screen in the shadows and midtones.
  - **Newspaper:** black dots on white, in grayscale.
- Procedural dot screen. Result is a high-contrast dot pattern on a grid.

**Bloom** (P1)
- Transition 0–100%. Size 0–100 px. Pressure on or off. Glow color mix.
- Algorithm: threshold bright areas, blur them, add the result back.

**Glitch** (P1)
- Amount, distortion, scale, RGB split, seed.
- Row and block displacement plus channel offset. Seeded.

**Chromatic Aberration** (P1)
- Distance 0–100 px. Direction or radial.
- Offsets the red and blue channels. Applies to the composite or the layer.

### 2.5 Liquify and Clone

Liquify (§4) and Clone (§5) are listed under the Liquify and Clone categories and follow the framework in §1.

## 3. Drawing Guides and assisted drawing

### 3.1 Concepts

- A **guide** is a document-level overlay with an optional stroke constraint.
- Guides are stored in the project. They are never exported with the artwork.
- A single **Drawing Guides** toggle controls visibility. It is in the Canvas tab of the Actions panel and in the Quick menu.
- Guides are edited in the **Drawing Guides** full-screen editor (see [02-workspace.md](02-workspace.md) §1). The editor has Cancel and Apply, a hue-spectrum bar at the top, a canvas preview with guides overlaid, and a bottom panel with the guide type selector and its controls.

### 3.2 Common properties

| Property | Range | Default |
|---|---|---|
| Line color | Any color | Light cyan |
| Line opacity | 5–100% | 50% |
| Line thickness | 0.5–10 pt | 1 pt (screen space; does not scale with zoom) |
| Grid spacing | 1–2000 px | 250 px |
| Assisted drawing | On / off | Off |
| Per-layer assistance | On / off per layer | Off |

**Per-layer assistance** is a layer flag. A layer row with assistance active shows an icon.

### 3.3 Guide types

| Guide | Geometry | Editing controls |
|---|---|---|
| 2D grid | Orthogonal lines at the configured spacing. | Spacing slider. Optional minor subdivisions (1–10). |
| Isometric | Three line families at 30°, 150°, and 90° from the horizontal. The angle is configurable from 15° to 45°. | Spacing. Left, right, and top planes can be hidden individually. |
| Perspective | 1, 2, or 3 vanishing points on a horizon line. | Drag each vanishing point and the horizon. Lock horizon. Lines-per-point density 8–180. |
| Symmetry | Mirror axes: vertical, horizontal, quadrant, or radial with 2–16 segments. | Drag axis position and rotation. Rotational option. Per-layer enable. |

**Perspective tapping:** in perspective mode, tapping the canvas creates vanishing points. The hint line reads "Tap to create vanishing points".

### 3.4 Assisted drawing

Assistance applies to the stabilized, document-space path before stamping. Brush dynamics are unaffected.

| Guide | Constraint |
|---|---|
| 2D grid | After the stroke moves more than 8 pt, it snaps to the nearest horizontal or vertical direction, based on the dominant direction. |
| Isometric | After 8 pt of movement, the stroke snaps to the nearest of the three axes (30°, 150°, 90°). |
| Perspective | The first 8 pt of movement choose the vanishing point whose line is closest to the stroke direction. The rest of the stroke is projected onto the line through the start point and that vanishing point. |
| Symmetry | Each input sample is reflected or rotated about the axes. Reflections compose: quadrant symmetry produces four stamps per sample, and radial N produces N stamps. |

**Symmetry rule:** the result with symmetry must equal the union of N independently transformed copies of the primary stroke, rendered with the same brush seed, so grain and jitter mirror as well. All mirrored marks go to the same layer in one history step.

**Straight-line assistance** releases when the stylus lifts. A two-finger hold, or the Shape Snap hold, can convert a free line to the nearest guide direction.

**Visibility:** when assistance is active on the current layer, the layer row icon and the brush cursor show it.

### 3.5 Snapping and measurement

| Feature | Behavior | Priority |
|---|---|---|
| Snap to guides | Transform, selection, and shape tools snap to guide lines, canvas edges, center lines, and layer bounds within 8 pt. Haptic tick and visible snap line. | P1 |
| Rulers | Optional horizontal and vertical rulers in the document unit. A guide line can be pulled from each ruler. | P2 |
| Canvas center and thirds | Static composition overlays (center cross, rule of thirds, golden ratio). Separate from drawing guides. | P2 |
| Pixel grid | At 800% zoom and above, a pixel boundary grid appears automatically. The user can disable it. | P2 |

## 4. Liquify (P1)

Liquify deforms a layer by painting into a displacement field. It never resamples repeatedly during a stroke.

### 4.1 Modes

| Mode | Behavior |
|---|---|
| Push | Drags pixels along the stroke direction. |
| Twirl clockwise / counter-clockwise | Rotates pixels around the brush center while held. |
| Pinch | Moves pixels toward the brush center. |
| Expand | Moves pixels away from the brush center. |
| Crystals | Pushes pixels outward in shard-like bursts. |
| Edge | Pushes pixels away from the stroke edge, creating contour distortions. |
| Reconstruct | Restores the displacement field toward the original. |

### 4.2 Controls

| Control | Range | Default |
|---|---|---|
| Size | 1–2000 px | 200 px |
| Pressure sensitivity | 0–100% | 100% |
| Distortion strength | 0–100% | 50% |
| Momentum (effect continues after the stylus moves) | 0–100% | 0% |
| Reset | Command | — |

### 4.3 Processing

- The displacement field is stored at half resolution.
- The field is applied once at commit with bicubic sampling.
- Apply creates one undo step. Cancel restores the layer exactly.

## 5. Clone (P1)

- Touch and hold, with the sample gesture, to set a source anchor. Later strokes copy pixels from the offset between the source anchor and the first stroke point.
- **Aligned** mode: the offset persists across strokes.
- **Fixed** mode: every stroke restarts from the anchor.
- **Sample source:** active layer or composite.
- The anchor is shown as a crosshair and may be reset at any time.
- Controls: brush size, opacity, alignment mode, and a reset-source command.
- Clone writes through the normal paint pipeline, so it is undoable and recorded in time-lapse.

## 6. Reference window

A floating window that shows a reference image or a live view of the canvas. It never changes the document.

### 6.1 Modes

| Mode | Contents |
|---|---|
| Image | An imported file, a photo, or pasted clipboard image. |
| Canvas | A live, uneditable mirror of the current document composite. |

### 6.2 Controls

- Move by drag.
- Resize with aspect lock.
- Pinch to zoom.
- Rotate with two fingers.
- Flip horizontally, for a quick mirrored view of drawn work.
- Opacity 25–100%. Default 100%.
- Close and hide. Hiding keeps the window's state.
- Touch and hold samples color with the same eyedropper loupe as the main canvas (see [04-canvas-and-input.md](04-canvas-and-input.md) §10).

### 6.3 Persistence and storage

- The window position, size, and loaded image persist per document across sessions.
- The image is stored in the project only if the user chooses **Keep with project**. Otherwise the reference image is kept only for the session.
- The reference window's content is never part of exported artwork. It becomes artwork only if the user inserts it as a layer.

### 6.4 Opening

- From Actions → Add → Reference.
- Drag and drop onto the reference window loads the dropped image as the reference (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §2.1).
- Only one reference window per document.

### 6.5 Acceptance

Opening, moving, resizing, zooming, and hiding the reference window does not change the document. Undo history is unaffected.
