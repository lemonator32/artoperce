# 07 — Layers, Compositing, Masks, Selection, and Transform

## 1. Layer model

### 1.1 Stack

- A document is a tree of layers. The root holds the **background** layer, which is always at the bottom, and any number of raster layers, groups, and (P1) text layers above it.
- Layers are composited in tree order, bottom to top. Within a group, children composite in their own order.
- The background layer cannot be deleted, moved, or merged. It can be hidden, colored, and made transparent (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §8.1).

### 1.2 Layer types

| Type | Contents | Priority |
|---|---|---|
| Raster | Tiled RGBA pixels | P0 |
| Group | Child layers. Has its own visibility, opacity, blend, mask, and isolation setting. | P0 |
| Background | Color plus visibility. Raster-like, protected. | P0 |
| Reference | A raster layer marked as a fill and selection source. Not forced to be visible in the composite. | P0 |
| Text | Editable text until rasterized (see [11-extensions.md](11-extensions.md) §2). | P1 |

### 1.3 Layer properties

| Property | Type | Default |
|---|---|---|
| `id` | Stable identifier | Generated |
| `name` | 1–120 characters | "Layer N" |
| `visible` | Boolean | true |
| `opacity` | 0–100% | 100% |
| `blendMode` | Blend mode (§3) | Normal |
| `locks` | `alpha` (preserve transparency) and `all` (no edits) | none |
| `clipping` | Boolean (clip to the layer below) | false |
| `maskId` | Reference to a mask (§4) or null | null |
| `assist` | Boolean (guide assistance for this layer) | false |
| `reference` | Boolean | false |
| `isolated` | Groups only: isolated or pass-through | isolated |
| `transform` | Optional pending transform (§8) | none |

### 1.4 Limits

- The layer count is limited by the layer capacity formula in [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1.
- Adding a layer past the limit is blocked with the message and alternatives defined there.
- No layer is discarded silently.

## 2. Layer panel

### 2.1 Layout

- A compact overlay anchored to the Layers button. Width up to 360 pt. Expands to full height on small screens.
- **Header:** title "Layers", an add-layer button (**+**), and an options button.
- **Selected layer row controls:** a blend-mode selector (showing the current mode name), an **N / opacity** control, and the opacity value. Tapping the blend-mode name opens the blend list (§3).
- **Rows:** top to bottom in stacking order (top layer first). The selected row has the accent highlight and a distinct selected state that is not color alone (a left bar and bold name).
- **Selection banner:** when a selection is active, a thin banner under the header reads "Selection active" and offers Deselect.

### 2.2 Row contents

- A **visibility checkbox** at the left. A hidden layer's thumbnail is dimmed.
- A **thumbnail** of the layer's pixels. Groups show a composite of their children. Thumbnails regenerate within 500 ms of a change.
- A **name**. Tap to rename inline.
- **Badges:** a blend-mode badge when the mode is not Normal, and icons for clipping, mask, alpha lock, assist, and reference status. Icons are shown as text labels in the accessibility tree.
- A **disclosure** control for groups.
- A **mask thumbnail** beside the layer thumbnail when a mask exists. Selecting the mask thumbnail targets painting at the mask (§4.3).

### 2.3 Interactions

| Interaction | Behavior |
|---|---|
| Tap row | Select the layer. Tapping the selected row opens its options menu. |
| Two-finger tap on row | Opens the opacity slider for that layer. |
| Tap a second row while holding one | Multi-select. An action bar appears with Duplicate, Group, Merge, Delete. |
| Long-press and drag | Reorder, or drop into a group. A line or highlight shows the insertion point. |
| Swipe left on row | Reveal Lock, Duplicate, Delete. Delete confirms only when the layer has content. |
| Pinch two rows together | Merge the rows between the touch points. The preview shows the merge before release (P1). |
| Tap the N / opacity control | Opens the blend-mode list and the opacity slider. |
| Tap checkbox | Toggles visibility. Visibility never deletes content. |
| Tap group disclosure | Collapses or expands the group. Collapse state is saved per document. |

### 2.4 Add, delete, reorder, merge

- **Add:** creates an empty transparent raster layer above the active layer and selects it.
- **Duplicate:** creates an independent copy of pixels, mask, and properties, named "<name> copy". Subsequent edits never affect the original.
- **Delete:** removes the selected layer after a confirmation (required when the layer has content). Protected: the background layer.
- **Reorder:** by drag. Reordering never changes pixel content. The composite updates.
- **Merge down:** combines the selected layer with the layer below using the correct blend result (§3.3). The merged layer keeps the lower layer's name and properties.
- **Group:** wraps the selected layers in a new group. The group name defaults to "Group N".
- **Flatten:** combines all visible layers into one layer after confirmation. A checkpoint is written first. Hidden layers are removed after confirmation and stated in the confirmation.

### 2.5 Layer options menu

Opened from the options control, the row's long-press, or the row's menu button. Each command shows its shortcut when one exists.

| Command | Behavior | Disabled when |
|---|---|---|
| Rename | Inline edit. | Locked (all) |
| Select | Creates a selection from the layer's non-transparent pixels. | Layer is empty |
| Copy / Cut / Paste | Operate on the layer pixels or the active selection. | Nothing to copy, or locked |
| Fill layer | Fills the layer or the selection with the primary color. | Locked |
| Clear | Removes all pixels on the layer or the selection. | Locked or empty |
| Alpha lock | Toggles. A checkerboard appears in the thumbnail. | Never |
| Mask | Adds a layer mask (§4). | Mask exists |
| Clipping mask | Clips this layer to the layer below. | No layer below, or the layer below is a group |
| Reference | Marks the layer as the source for Quick Fill and automatic selection. Only one reference layer per document. | Never |
| Invert | Inverts the color values of the layer. Preserves alpha. | Locked |
| Merge down | See §2.4. | Lowest layer |
| Flatten | See §2.4. | Only one layer |
| Duplicate | See §2.4. | Never |
| Drawing assist | Toggles guide assistance for this layer. | No guide is visible |

**Rule:** a command that is unavailable is disabled with a one-line reason shown when the command is focused or long-pressed.

## 3. Compositing and blend modes

### 3.1 Compositing model

- Colors are stored as premultiplied-alpha values internally. Blending happens in the document color space.
- For a source layer with color `Cs` and alpha `αs` over a backdrop with color `Cb` and alpha `αb`, with blend function `B`:

```
αr = αs + αb × (1 − αs)
Cr = [ (1 − αb) × αs × Cs  +  αb × αs × B(Cb, Cs)  +  (1 − αs) × αb × Cb ] / αr
```

- **Layer opacity** multiplies `αs`.
- **Layer mask** multiplies `αs` per pixel.
- **Clipping** multiplies `αs` by the base layer's alpha.
- **Groups:** *isolated* (default) composites the group first, then blends the result as one layer. *Pass-through* blends each child directly into the stack below. The choice is a group property.
- When `αr` is 0, the output color is 0 and no division is performed.

### 3.2 Blend catalog

All formulas are per channel with values in [0, 1]. A mode must produce identical results in the live canvas, thumbnails, flattened export, and layered round trip.

| Group | Mode | Function B(Cb, Cs) | Priority |
|---|---|---|---|
| Normal | Normal | `Cs` | P0 |
| Darken | Darken | `min(Cb, Cs)` | P0 |
| | Multiply | `Cb × Cs` | P0 |
| | Color Burn | `1 − min(1, (1 − Cb) / Cs)`; `Cs = 0` gives 0 | P0 |
| | Linear Burn | `max(0, Cb + Cs − 1)` | P1 |
| | Darker Color | Whole-color: the color with the lower luminosity | P1 |
| Lighten | Lighten | `max(Cb, Cs)` | P0 |
| | Screen | `Cb + Cs − Cb × Cs` | P0 |
| | Color Dodge | `min(1, Cb / (1 − Cs))`; `Cs = 1` gives 1 | P0 |
| | Add (Linear Dodge) | `min(1, Cb + Cs)` | P0 |
| | Lighter Color | Whole-color: the color with the higher luminosity | P1 |
| Contrast | Overlay | Hard Light with `Cb` and `Cs` swapped | P0 |
| | Soft Light | W3C compositing specification soft-light function | P0 |
| | Hard Light | `Multiply(Cb, 2Cs)` if `Cs ≤ 0.5`; else `Screen(Cb, 2Cs − 1)` | P0 |
| | Vivid Light, Linear Light, Pin Light | Standard definitions | P2 |
| Difference | Difference | `abs(Cb − Cs)` | P0 |
| | Exclusion | `Cb + Cs − 2 × Cb × Cs` | P0 |
| | Subtract | `max(0, Cb − Cs)` | P1 |
| | Divide | `min(1, Cb / Cs)`; `Cs = 0` gives 1 | P1 |
| Color | Hue, Saturation, Color, Luminosity | Non-separable functions (§3.4) | P0 |

**Rules:**
- Division by zero is handled by clamping, never by producing NaN.
- Every output is clamped to [0, 1].
- P0 modes for 1.0 are: Normal, Multiply, Screen, Overlay, Darken, Lighten, Color Dodge, Color Burn, Soft Light, Hard Light, Difference, Exclusion, Add, Hue, Saturation, Color, Luminosity.
- Every mode has a human-readable name in the UI.

### 3.3 Merge rule

Merge down uses the same compositing formula as the canvas, with the upper layer as source and the lower layer as backdrop. The result's alpha is `αr`. The merge is identical to what the composite showed before the merge.

### 3.4 Non-separable modes

Let `Lum(C) = 0.3 × R + 0.59 × G + 0.11 × B` and `Sat(C) = max(R, G, B) − min(R, G, B)`.

- **SetLum(C, l):** shifts C by `d = l − Lum(C)`, then clips the color into [0, 1] by scaling toward `Lum`.
- **SetSat(C, s):** scales the channels so the saturation equals `s`, preserving their order. A channel set of equal values becomes 0.

| Mode | Result |
|---|---|
| Hue | `SetLum(SetSat(Cs, Sat(Cb)), Lum(Cb))` |
| Saturation | `SetLum(SetSat(Cb, Sat(Cs)), Lum(Cb))` |
| Color | `SetLum(Cs, Lum(Cb))` |
| Luminosity | `SetLum(Cb, Lum(Cs))` |

Darker Color and Lighter Color compare `Lum(Cb)` and `Lum(Cs)` and return the whole color with the lower or higher value.

### 3.5 Blend modes and export

- Blend mode is a layer property and survives native save and load, and layered export where the format supports it.
- Modes the target format cannot represent are reported in the export report (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §4.5).

## 4. Masks

### 4.1 Model

- A mask is an 8-bit grayscale surface at the layer's dimensions. White reveals. Black hides. Gray partially hides.
- The layer's pixels are unchanged by the mask. Masks are non-destructive.
- A layer has at most one mask. A group may have a mask (P1).

### 4.2 Commands

| Command | Behavior | Undo |
|---|---|---|
| Add mask | Creates a white mask (reveal all). | One step |
| Apply mask | Bakes the mask into the layer's alpha and removes the mask. | One step |
| Disable mask | Keeps the mask but ignores it in compositing. Toggle. | One step |
| Invert mask | Inverts the mask values. | One step |
| Delete mask | Removes the mask. | One step |

### 4.3 Painting on a mask

- Selecting the mask thumbnail targets painting at the mask. Painting uses the normal brush with the color constrained to grayscale (white reveals, black hides).
- Selecting the layer thumbnail targets the layer's pixels.
- The layer row shows which target is active with a highlight on the thumbnail.

### 4.4 Acceptance

Painting black on a layer mask hides pixels without altering layer data. Applying the mask bakes it in. One undo restores it.

## 5. Alpha lock, clipping, and references

### 5.1 Alpha lock

- Constrains painting to the existing non-transparent pixels of a layer.
- Toggle in the layer options menu. A checkerboard shows in the thumbnail.
- Painting on an alpha-locked layer leaves transparent pixels unchanged.
- Erase on an alpha-locked layer requires confirmation of the exception; otherwise it is blocked (see [05-brushes.md](05-brushes.md) §13).

### 5.2 Clipping mask

- A clipping layer's visible content is limited to the alpha of the layer directly below it.
- Multiple layers may clip to one base layer, forming a clipping group. The base layer is not clipped.
- Clipping does not apply to a group as a base.

### 5.3 Reference layer

- One reference layer per document. It is the source for Quick Fill (when Source is Reference), automatic selection (when source is reference), and the eyedropper (when sample source is reference).
- A reference layer may be hidden. Hiding it does not affect its use as a source.

### 5.4 Locks

| Lock | Effect |
|---|---|
| Alpha lock | See §5.1. |
| All lock | Blocks painting, transform, delete, and clear on the layer. Visibility and opacity remain editable. The row shows a lock icon. |

Locked-state commands in the layer menu are disabled with the reason "Layer is locked".

## 6. Recolor (P1)

- One-tap action in the layer menu. It re-hues the active layer to the primary color.
- Each pixel keeps its luminosity `L` and alpha. Hue and saturation come from the primary color.
- The result is deterministic. No tolerance setting is needed.

## 7. Selection

### 7.1 Selection model

- A selection is an 8-bit mask at the document's dimensions. A value of 255 is fully selected, 0 is unselected, and intermediate values are partially selected (feather).
- Strokes, fills, and adjustments are multiplied by the mask.
- The marching-ants boundary appears where the mask equals 50%.
- The selection persists across zoom, pan, and tool changes. It is cleared only by an explicit deselect, or by loading a different selection.
- The boundary is high-contrast and visible over both light and dark artwork.

### 7.2 Modes

| Mode | Behavior and parameters | Priority |
|---|---|---|
| Rectangle | Drag. Hold a second finger for a 1:1 aspect. Handles adjust before commit. | P0 |
| Ellipse | As rectangle, with an elliptical boundary. | P0 |
| Freehand | Draw a closed path. The endpoint closes with a straight segment. | P0 |
| Polygon | Tap to place points. Double-tap or tap the first point to close. | P1 |
| Automatic | Tap or drag to select contiguous pixels within a threshold. Source: active layer, merged composite, or reference layer. | P0 |
| Color range | Tap to select all pixels in the layer within a hue tolerance of the tapped pixel. | P1 |

**Automatic threshold:** range 0–100%, default 10%. A pixel is included when its color distance from the seed pixel is at most the threshold, as a fraction of the maximum distance. This matches the Quick Fill threshold definition (see [04-canvas-and-input.md](04-canvas-and-input.md) §7.2).

### 7.3 Boolean operations

- **Add**, **Subtract**, and **Intersect** combine the existing selection with the new shape.
- **Replace** is the default for a new selection.
- Invert flips the mask.

### 7.4 Refinement

| Operation | Range | Notes |
|---|---|---|
| Feather | 0–200 px | Gaussian edge softness. Live preview. |
| Grow | 1–200 px | Expands the selection. |
| Shrink | 1–200 px | Contracts the selection. |
| Invert | — | Flips the mask. |
| Save selection | — | Stores a named selection in the document (P1). |
| Load selection | — | Restores a named selection (P1). |

### 7.5 Copy, paste, and duplicate

- **Copy** copies the selected pixels with alpha.
- **Paste** creates a new layer containing the copied pixels, centered in the viewport or at the paste position.
- **Duplicate selection** creates a new layer with the selected pixels.

### 7.6 Scope

- Every selection operation names its scope in the UI: the active layer, multiple selected layers, or the merged visible composite.
- Scope is shown in the selection banner.

### 7.7 Deselect

- Ctrl or Cmd + D on desktop, or the Deselect button in the selection banner.
- Deselect is an undoable operation.

## 8. Transform

### 8.1 Modes

| Mode | Behavior | Priority |
|---|---|---|
| Move | Translates the target. | P0 |
| Uniform scale | Scales width and height together. | P0 |
| Freeform scale | Scales width and height independently. | P0 |
| Rotate | Rotates about the bounding-box center, or about a dragged pivot. | P0 |
| Distort | Moves each corner independently. | P0 |
| Warp | Mesh control points. Default 3 × 3 grid, adjustable up to 8 × 8. | P1 |
| Perspective | Four-corner perspective. | P1 |

### 8.2 Targets

- With no selection: the active layer. Multi-layer selections transform together (§8.4).
- With a selection: the selected pixels of the active layer are lifted into a floating transform.
- Groups: transform applies to the group's children (P1).

### 8.3 Bounding box and controls

- A bounding box with handles at corners and edges.
- The transform bar shows numeric fields for X, Y, width, height, rotation, skew, and an aspect-lock link (P1).
- Commit and Cancel are explicit buttons. A confirm checkmark commits. A cancel control restores the pre-transform state.
- **Cancel** restores the exact pre-transform pixel data, held in memory until commit or cancel.
- **Fit to canvas** scales the target to the canvas boundary.

### 8.4 Quality

- Preview uses bilinear sampling while dragging.
- Commit uses bicubic by default. The option Nearest-neighbor is available for pixel art.
- Each layer is resampled exactly once, at commit. Repeated transforms during one session are composed before commit.
- Alpha and edge quality are preserved.

### 8.5 Snapping

- Snaps to canvas edges, canvas center, guides, and layer bounds within 8 pt. A haptic tick and a visible snap line confirm.
- Hold a second finger to temporarily disable snapping.

### 8.6 Multiple layers

- A multi-selection transforms all targets about a common bounding box.
- Each layer is resampled once at commit.

### 8.7 Time-lapse

- Transform commits are recorded as operations (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §5.1).
