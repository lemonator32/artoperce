# 04 — Canvas Viewport, Input, and Gestures

## 1. Viewport and coordinates

### 1.1 Coordinate systems

- **Document space:** fixed pixel coordinates with origin at the top-left of the canvas, x right, y down. Independent of screen size and of zoom, rotation, or pan.
- **View space:** points on screen after applying the viewport transform (pan, zoom, rotation).
- **Input space:** raw pointer coordinates in the platform's units, plus pressure, tilt, and timestamp.

Every pointer sample is converted from input space to document space before it is used for drawing, selection, or any stored data. The viewport transform is never applied to pixels.

### 1.2 Viewport transform

- The viewport stores zoom, rotation, and pan offset.
- **Zoom:** minimum 5%, maximum 6400%. Zoom is around the gesture's midpoint.
- **Rotation:** continuous. Soft snap to multiples of 90° within ±5°. The setting "Snap rotation to 0°" turns the snap on or off (default on).
- **Pan:** follows the gesture. On release, a two-finger drag continues with inertia that decays over 300 ms.
- **Pixel view:** Ctrl/Cmd + 1 sets zoom to 100% and centers the canvas.
- **Fit to screen:** scales the canvas to fit the viewport with a margin of 24 pt. Resets rotation when within 15° of upright.
- **Reset rotation:** command in Canvas tab and the Quick menu.
- **Previous viewport:** a command returns to the viewport before the last fit or reset.
- The viewport is preserved when a panel opens or closes, when the Layers or Color panel changes state, and when a tool changes.

### 1.3 Canvas surround

- The surround around the artwork uses `color.bg.surround`, with a subtle grid pattern (dot grid, 24 pt spacing, 6% contrast) as a background texture. The grid is not part of the artwork and is never exported.
- The artwork is bounded by a 1 pt edge. A soft shadow along the right and bottom edges is shown when the setting "Canvas edge shadow" is on (default on).
- When the artwork fills the viewport, the edge and shadow are not drawn.

### 1.4 Brush cursor

- The brush cursor is drawn in view space at the true brush footprint.
- It is controlled by the Brush cursor setting (see [05-brushes.md](05-brushes.md) §9 and [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1).

### 1.5 Brush scaling

- Setting "Brush scaling" (default Canvas): brush size scales with canvas zoom, so the stroke keeps its document-space size.
- Option Screen: brush size stays constant in screen points while zoom changes. The stroke's document-space width changes with zoom.

## 2. Input pipeline

The pipeline runs in this order for every stroke:

1. **Receive** timestamped pointer samples: position, pointer type, pressure, tilt (x and y, or azimuth and altitude), barrel roll if reported, hover flag, and device identifier.
2. **Filter** duplicate samples. Normalize pressure and tilt using the device calibration curve (see §5.3).
3. **Predict** the next position for low-latency preview only, if the Prediction setting is on. Predicted samples are drawn to the preview buffer and never stored.
4. **Convert** each sample to document space.
5. **Stabilize** and smooth the path according to the active brush (see [05-brushes.md](05-brushes.md) §4.2). Apply guide assistance (see [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §3).
6. **Render** into the temporary stroke buffer as stamps are produced.
7. **Commit** on pen-up: composite the stroke buffer into the active layer as one undoable operation. Remove prediction artifacts before commit.
8. **Journal** the committed stroke (see [12-data-and-engine.md](12-data-and-engine.md) §4).

Stroke samples are stored with the stroke as authoritative data, not the predicted data. Replay of a stored stroke must reproduce the same pixels.

## 3. Gesture arbitration

These rules are mandatory. They decide what a touch means when several inputs happen at once.

1. **Stylus wins.** Stylus contact always draws, or acts as the active tool. While a stylus is in contact, all touch gestures are suppressed, including for a 150 ms tail after the stylus lifts (palm rejection window, configurable 0–500 ms, default 150 ms).
2. **Finger drawing.** A single finger draws on the canvas only when "Draw with finger" is on. Otherwise it is ignored on the canvas, except for touch-and-hold (§4).
3. **Start threshold.** A gesture is recognized only after it passes its start threshold:
   - Two-finger drag or pinch gestures: fingers moved at least 8 pt.
   - Taps: each finger stays within 8 pt of its start and remains in contact for at least 150 ms before lifting.
   - This prevents accidental undo and accidental zoom.
4. **Late second finger.** If a second finger lands within 120 ms of the first, the touch is a multi-touch gesture. Cancel any stroke started by the first finger and remove its pixels without an undo entry. The removed pixels were never committed.
5. **Stylus in progress.** A two-finger tap while a stylus stroke is in progress does not undo. Stroke completion takes precedence.
6. **Conflicts.** A user-defined gesture cannot duplicate another action. The settings screen rejects the conflicting assignment and names the conflicting action (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §2).
7. **Alternatives.** Every gesture has an on-screen alternative for assistive use (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §3).
8. **Accidental marks.** Palm contact within the rejection window never creates a mark. Hover never creates a mark.

## 4. Touch gesture map

Each gesture is a default that the user may remap or disable. Priority values: P0 required for 1.0, P1 should ship in 1.0, P2 later.

| Gesture | Default action | Notes | Priority |
|---|---|---|---|
| Two-finger pinch / spread | Zoom around the midpoint | Limits per §1.2. Haptic tick at 100%. | P0 |
| Two-finger drag | Pan | Inertia on release, 300 ms decay. | P0 |
| Two-finger twist | Rotate view | Soft snap per §1.2. Rotation never changes pixels. | P0 |
| Fast two-finger pinch-in | Fit canvas to screen | Also resets rotation when within 15° of upright. | P0 |
| Two-finger tap | Undo | Hold to repeat (§11). | P0 |
| Three-finger tap | Redo | Hold to repeat (§11). | P0 |
| Three-finger swipe down | Open the Cut / Copy / Paste menu, anchored at the gesture centroid | Decision D5. | P1 |
| Three-finger scrub left-right | Clear the active layer | Requires a confirmation toast with Undo. | P2 |
| Four-finger tap | Toggle full-screen canvas (hide all chrome) | A single tap on a screen edge restores the chrome. | P1 |
| Touch and hold on canvas | Eyedropper | Loupe shows the sampled color. Release to commit. Delay per §10. | P0 |
| Draw a line or outline, then hold | Shape Snap | See §6. | P1 |
| Drag color swatch onto a closed region | Quick Fill | See §7. | P1 |
| Pinch layer rows together | Merge the pinched layers | Preview shows the merge before release. See [07-layers-and-selection.md](07-layers-and-selection.md) §2.3. | P1 |
| Swipe a layer row left | Reveal lock, duplicate, delete | Delete confirms only when the layer has content. | P1 |
| Swipe a gallery card right | Select the card and enter selection mode | See [03-gallery-and-documents.md](03-gallery-and-documents.md) §2. | P1 |

**Gestures not defined:** three-finger swipe left and right are not assigned in 1.0.

**Cancellation.** A gesture is canceled when the touch count changes so that it no longer matches the gesture, or when Escape is pressed on a keyboard. A canceled gesture makes no change.

## 5. Stylus

### 5.1 Basic behavior

- Pressure controls size and opacity through the active brush's pressure curves (see [05-brushes.md](05-brushes.md) §7).
- Tilt influences size, opacity, flow, and grain depth where the brush opts in and the hardware reports tilt.
- Azimuth and barrel roll rotate the stamp for brushes that opt in.
- The app detects stylus capability at runtime. Finger and mouse input use a constant pressure of 1.0, so size and opacity follow the brush's base settings.

### 5.2 Stylus actions

| Input | Default action | Alternatives |
|---|---|---|
| Barrel tap or squeeze (when reported) | Toggle eraser | Eyedropper, quick menu, swap primary and secondary colors, switch to previous tool |
| Double tap on the barrel (when reported) | Switch to the previous brush | Toggle eraser, quick menu, none |
| Eraser end (when present) | Selects the eraser tool for that contact only | None |
| Hover (when supported) | Shows the brush cursor outline at the true size and tilt direction | Off |

Each stylus action is assignable in the settings catalog (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1, Stylus). Actions for missing hardware are hidden.

### 5.3 Calibration

- Stylus calibration screen in Preferences: a pressure test pad plotting raw input against mapped pressure.
- Curve editor with at least three editable points, a reset, and presets Soft, Normal, and Firm.
- Calibration is per device and per stylus identifier when the platform exposes one.

### 5.4 Smoothing and prediction

- Smoothing 0–100% (default 0%). Applied before brush stabilization.
- Prediction on or off (default on). Prediction affects the preview only (§2).

## 6. Shape Snap (P1)

Shape Snap converts a freehand stroke into a clean primitive.

### 6.1 Trigger

- The user holds still at the end of a stroke for the Shape Snap delay (default 500 ms, range 200–1500 ms).
- The hold happens while the stylus or finger is still in contact with the screen at the end of the stroke.

### 6.2 Fitting

1. Consider the candidate primitives: straight line, circle, ellipse, rectangle, rounded rectangle, triangle, arc, and closed polygon with up to 12 vertices.
2. For each candidate, compute the best-fit geometry from the stroke's samples.
3. Compute the maximum deviation between the stroke and each candidate.
4. Choose the candidate with the smallest maximum deviation.
5. Accept only if that deviation is at most **4% of the stroke length**. Otherwise leave the stroke unchanged.

### 6.3 Constraint while held

- While the Shape Snap hold is active, a second finger on the canvas constrains the shape. Equal sides for rectangles and ellipses; 15° angle increments for lines.

### 6.4 Edit Shape

- After snap, an **Edit Shape** chip appears with control points on the shape.
- Dragging a control point changes the shape in real time, re-fitting the primitive as it moves.
- The chip dismisses when the user starts another stroke or taps elsewhere.

### 6.5 Fill and undo

- With "Auto-fill on Shape Snap" on, a closed snapped outline is filled with the current color (default off).
- Undo after snap reverts to the freehand stroke. A second undo removes the stroke. Two undo steps total, as stated in the acceptance criteria.

## 7. Quick Fill (P1)

Quick Fill pours the active color into the region under a drop point.

### 7.1 Trigger

- Drag a color swatch from the Color panel or the top bar onto the canvas and release over a region.
- The fill region is calculated from the drop point.
- After the drop, drag to raise or lower the threshold. The filled area updates live.

### 7.2 Parameters

| Parameter | Behavior |
|---|---|
| Source | Active layer by default. Options: merged visible composite, or the reference layer if one is set. |
| Threshold | Range 0–100%, default 10%. Maximum color distance between the seed pixel and a pixel for it to be included, as a fraction of the maximum possible distance. Live preview. |
| Gap closing | Range 0–8 px, default 2 px. Bridges small breaks in line art by dilating the barrier mask by the gap radius before the flood fill. |
| Edge expansion | Optional, 0 or 1 px. Expands the fill under line art to hide antialiasing halos. Default off. |
| Fill target | Active layer, or the selection if one exists. Locked layers refuse with a one-line explanation. |

### 7.3 Rules

- The fill is one undo step per drop.
- The fill uses the primary color.
- The fill does not change the active color.
- A drop on a locked alpha layer fills only within existing pixels (alpha lock rule).

### 7.4 Acceptance

Dropping a color on a closed outline with a 2 px gap fills inside only. Raising gap closing to 4 px fills a 3 px gap correctly. One undo removes the fill.

## 8. Keyboard and pointer shortcuts (desktop)

These apply on desktop builds and on tablets with a connected keyboard. Every shortcut is remappable from the Preferences screen, which includes a searchable cheat sheet.

| Action | Shortcut |
|---|---|
| Undo | Ctrl or Cmd + Z |
| Redo | Shift + Ctrl or Cmd + Z |
| Copy | Ctrl or Cmd + C |
| Cut | Ctrl or Cmd + X |
| Paste | Ctrl or Cmd + V |
| Zoom in / out | Ctrl or Cmd + Plus / Minus; scroll wheel with modifier |
| Fit to screen | Ctrl or Cmd + 0 |
| 100% view | Ctrl or Cmd + 1 |
| Pan | Hold Space + drag |
| Rotate view | Hold R + drag |
| Brush size smaller / larger | [ / ] |
| Eyedropper (while held) | Hold I, or Alt + click |
| Swap primary and secondary colors | X |
| Temporary eraser (while held) | Hold E |
| New layer | Shift + Ctrl or Cmd + N |
| Deselect | Ctrl or Cmd + D |
| Hide interface | Tab |
| Close topmost panel, or cancel the active modal or gesture | Escape |

**Pointer.** Mouse and trackpad: drag draws with constant pressure when no pressure source is present. Scroll pans. Pinch on a trackpad zooms.

## 9. Quick menu

- A list or radial popup holding up to 6 user-chosen actions.
- Opened by a configurable gesture. Default: touch and hold on the rail's Modifier button (see [02-workspace.md](02-workspace.md) §2.3).
- Default set: New layer, Copy, Paste, Flip view, Fit to screen, Show or hide guides.
- Customizable per tool. The per-tool set is saved in settings.
- Actions that are unavailable are shown dimmed with a reason.

## 10. Eyedropper

### 10.1 Trigger

- Touch and hold on the canvas for the eyedropper delay (default 400 ms, range 100–1500 ms).
- The rail's Modifier button, when it is assigned to eyedropper.
- Hold I, or Alt + click, on desktop.
- A stylus action (§5.2).
- Keyboard and switch control: a dedicated eyedropper button that arms for the next tap (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §3).

### 10.2 Loupe

- A ring showing the sampled color in its center. The previous color appears as an inner half ring.
- A magnified view of the area under the pointer, with a 1–31 px sample area shown.
- The loupe appears above the touch point, not under the finger.

### 10.3 Sampling

- **Sample source:** merged composite (default), active layer only, or reference layer.
- **Sample size:** single pixel, 3 × 3, 5 × 5, or 9 × 9 average. Default single pixel.
- **Transparency:** returns the composited color over the document background by default. "Pick unpremultiplied color" returns the stored color and alpha.
- **Commit:** on release. Dragging off the canvas cancels.
- The sampled color becomes the primary color and is added to recent colors (see [06-color.md](06-color.md) §5).

### 10.4 Color management

Sampling uses the document's color profile. The sampled value matches the displayed composite within the tolerance in [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §5.3.

## 11. Repeat, timing, and undo gestures

- **Hold to repeat:** for Undo and Redo, buttons and gestures repeat. First repeat after 400 ms, then every 80 ms.
- **Rapid undo delay:** the time threshold that separates a quick tap from a hold on the Undo and Redo controls. Default 0.65 s, range 0.1–1.0 s (decision D2). Taps shorter than the threshold undo one step. Holds repeat.
- **Minimum tap duration:** 150 ms (§3).
- **Hold delays for other features:** eyedropper 400 ms, Shape Snap 500 ms, quick menu 400 ms. Each has its own setting (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1).
- No function requires a gesture lasting longer than 3 seconds.
