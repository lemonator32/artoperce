# 02 — Workspace, Navigation, and Visual Design

## 1. Screens

| Screen | Entered from | Exits to |
|---|---|---|
| Gallery | App launch; Gallery button | Canvas (tap a document or "+"); Selection mode; New Canvas dialog; Preferences |
| Gallery selection mode | Select button | Gallery (Done) |
| Canvas (workspace) | Gallery document tap; New Canvas | Gallery (Gallery button) |
| Actions panel | Wrench button | Canvas (dismiss) |
| Brush library | Brush button (second tap) or Actions | Canvas |
| Color panel | Color swatch button | Canvas |
| Layers panel | Layers button | Canvas |
| Adjustments panel | Magic-wand button | Canvas (Apply or Cancel) |
| Drawing Guides editor | Actions → Canvas, or Adjustments panel | Canvas (Apply or Cancel) |
| Brush Editor | Brush library → brush options, or "Edit brush" | Canvas (Apply or Cancel) |
| Reference window | Actions → Add → Reference | Canvas (close) |
| Time-lapse replay | Actions → Video | Canvas |
| New Canvas dialog | Gallery "+" | Canvas (Create) or Gallery (Cancel) |
| Export sheet | Actions → Share, or Gallery Share | Canvas or Gallery |
| Preferences | Actions → Preferences, or Gallery settings | Previous screen |
| Help | Actions → Help | Previous screen |

**Common rule for full-screen editors** (Brush Editor, Drawing Guides, New Canvas, Adjustments commit): a top-right gray **Cancel** pill and a blue circular **Apply** button with a white checkmark. Cancel discards all edits made in the screen. Apply commits them as one undoable operation. Edits made in a full-screen editor are not visible on the artwork until Apply, except where the screen states a live preview.

**Common rule for panels** (Actions, Brush library, Color, Layers): a panel is dismissed by tapping outside it, by swiping it down, or by its close control. Dismissal never discards committed changes. Panels do not change the active tool.

## 2. Canvas workspace layout

The canvas occupies most of the screen. Chrome is limited to a top bar, a left control rail, and transient overlays.

### 2.1 Regions

| Region | Contents | Behavior |
|---|---|---|
| Top bar | Gallery button, Actions, Adjustments, Selection, Transform (left group); Brush, Smudge, Eraser, Layers (right group); Color swatch (far right) | Fixed height about 74 pt on a 1000 pt-wide display (about 88 px on the reference display). Dark, slightly lighter than the canvas surround. |
| Left control rail | Brush size slider, Modifier button, Opacity slider, Undo, Redo | Vertical capsule along the left edge below the top bar. Mirrors to the right in right-handed layout (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1). Can be hidden. |
| Canvas viewport | Artwork, background grid, guide overlays, selection outline, transform handles, brush cursor | Pan, zoom, rotate, and draw (see [04-canvas-and-input.md](04-canvas-and-input.md)). |
| Status line | Save state, export progress, transient tool feedback | Thin line under the top bar or above the rail. Auto-hides after 2 s. |
| Overlay panels | Panels and popovers listed in §1 | Slide in from the invoking control. Never permanently obscure the active artwork area. |

### 2.2 Top bar controls

| Position | Control | Action | Active state |
|---|---|---|---|
| Left | Gallery (text button) | Return to gallery. Autosaves first. | — |
| 2 | Wrench | Opens Actions. | Blue while open |
| 3 | Magic wand | Opens Adjustments. | Blue while an adjustment is active |
| 4 | Selection (S-curve icon) | Activates the Selection tool. Tap again to open its mode menu. | Blue when active |
| 5 | Transform (arrow icon) | Activates the Transform tool for the active layer or selection. | Blue when active |
| Right group | Brush | Activates the Paint tool. Tap again on an active Paint tool to open the brush library. | Blue when active |
| Right group | Smudge (drop icon) | Activates the Smudge tool. | Blue when active |
| Right group | Eraser | Activates the Erase tool. | Blue when active |
| Right group | Layers (two-squares icon) | Opens the Layers panel. | Blue when open |
| Far right | Color swatch | Opens the Color panel. Filled with the primary color. | — |

**Tool tap rule.** Tapping an inactive tool activates it. Tapping an already-active Paint, Smudge, or Erase tool opens its brush library. Tapping the active Selection or Transform tool opens its options.

**Mutual exclusion.** Paint, Smudge, and Erase are mutually exclusive. Selection and Transform are edit modes and are mutually exclusive with each other. A paint tool and an edit mode may not be active at the same time, except the Selection tool, which persists while painting so that strokes are clipped to the selection.

### 2.3 Left control rail

| Control | Behavior |
|---|---|
| Brush size slider (top) | Vertical slider. Range 1–8000 px, logarithmic scale. Value pill shown while dragging. Changes the active brush's size for the current tool. |
| Modifier button (middle) | A configurable quick action. Default: touch and hold opens the Quick menu (see [04-canvas-and-input.md](04-canvas-and-input.md) §9). Tap is unassigned by default. Assignable actions: Eyedropper, Undo, Redo, Toggle guides, Flip view, Fit to screen, Swap colors. |
| Opacity slider (bottom) | Vertical slider, 0–100%. Changes the active brush's opacity. Track fills from the bottom. |
| Undo (lower) | Undoes the last operation. Long-press repeats per gesture repeat rule (400 ms, then every 80 ms). |
| Redo (lowest) | Redoes. Same repeat rule. |

**Brush size and opacity link.** Setting "Brush size and opacity link" (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1) defaults to Independent. When linked, changing size and opacity changes both sliders together, and the rail shows both values.

**Visibility.** The rail remains visible with the canvas. It can be hidden from the Actions panel's Canvas tab and by the four-finger tap gesture. Sliders may be hidden independently in settings.

## 3. Actions panel

The Actions panel is a tabbed panel that anchors under the wrench button. It has a top row of six tabs with labels and icons, in this order:

1. **Add** (default selected)
2. **Canvas**
3. **Share**
4. **Video**
5. **Preferences**
6. **Help**

### 3.1 Add tab

Two groups separated by a divider.

**Insert group**
- Insert file (P0)
- Insert photo (P0)
- Take photo (P1, requires camera permission at the moment of use)
- Add text (P1, see [11-extensions.md](11-extensions.md) §2)
- Add reference window (P0)

**Edit group**
- Cut (disabled when there is no selection and no selected layer)
- Copy (disabled when there is no selection and no selected layer)
- Copy canvas (copies the flattened visible composite; disabled when no selection)
- Paste (disabled when the clipboard has no supported content)

A disabled item is dimmed to 40% opacity and shows a one-line reason when focused or long-pressed.

### 3.2 Canvas tab

- Canvas information (opens the read-only information sheet, see [03-gallery-and-documents.md](03-gallery-and-documents.md) §7)
- Resize canvas (opens the canvas size sheet with crop, resample, and anchor options, see [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.3)
- Flip view horizontal and vertical (display only)
- Flip canvas horizontal and vertical (destructive, undoable)
- Rotate canvas 90° and 180° (destructive, undoable)
- Drawing Guides (toggle visibility, and "Edit guides" opens the editor)
- Show grid overlay toggle
- Show canvas boundary toggle

### 3.3 Share tab

- Export (opens the export sheet, see [09-import-export-timelapse.md](09-import-export-timelapse.md) §4)
- Share image (quick PNG export with the default options, then the platform share sheet)
- Export layers as files (P1)

### 3.4 Video tab

- Time-lapse on or off for this document
- Replay (opens replay, see [09-import-export-timelapse.md](09-import-export-timelapse.md) §5.2)
- Export time-lapse video
- Clear time-lapse (explicit, shows reclaimed space)

### 3.5 Preferences tab

Lists the groups from the settings catalog in [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1. Changing a setting applies immediately.

### 3.6 Help tab

Opens the Help screen described in [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §5. It includes the gesture guide, keyboard cheat sheet, how-to articles, feedback, and a diagnostic report export.

## 4. Brush library panel

Slides in from the right edge of the canvas. Covers at most 45% of the screen width in landscape. Full-height sheet in portrait.

- **Header:** library name with a dropdown chevron (switch between brush sets), a search field, and a **+** button (create brush, duplicate, or new set).
- **Left column:** categories as rounded rectangles with icon and label. The list scrolls.
- **Right column:** brushes in the selected category. Each row shows the brush name above a horizontal stroke sample rendered with that brush.
- **Selected brush:** solid blue row background with white text. Selected state also shows a checkmark.
- **Long-press a brush:** menu with Edit, Duplicate, Rename, Export, Reset to default (built-in brushes only), Delete (user brushes only).
- **Favorites and recents (P1):** a Recent row at the top and a star toggle per brush.

Details of the brush library and its data are in [05-brushes.md](05-brushes.md).

## 5. Color panel

Covered in [06-color.md](06-color.md). Layout summary:

- Drag handle at top. Header "Colors" with the primary and secondary swatches at the right.
- Mode selector at the bottom with five modes: Disc, Classic, Harmony, Value, Palettes.
- Panel remembers its last mode.

## 6. Layers panel

Covered in [07-layers-and-selection.md](07-layers-and-selection.md) §2. Layout summary:

- Compact overlay anchored to the Layers button.
- Header with an add-layer control, a blend-mode selector and opacity control for the selected layer, and an options control.
- Rows listed top to bottom in stacking order (top layer first).

## 7. Panels, popovers, and drawers

### 7.1 Placement

- Panels open adjacent to the control that invoked them, without covering that control.
- On large displays, panels occupy at most one third of the width.
- On small displays (under 700 pt wide), panels become full-height drawers or modal sheets with the same hierarchy.

### 7.2 Exclusivity

- Only one major panel is expanded at a time. Opening another major panel closes the first.
- Exceptions: the reference window and the time-lapse replay are floating and may coexist with one major panel.
- The brush cursor and the rail remain visible with any panel.

### 7.3 Tool state

- Opening a panel never changes the active tool or the active layer.
- Opening the Color panel never changes the active brush.
- Opening Layers never clears the selected layer.
- Dismissing a panel restores the same viewport (zoom, rotation, pan).

### 7.4 Modal operations

A modal operation (canvas resize, export format, delete confirmation, profile conversion) temporarily blocks canvas input. It states how to cancel or continue. Canvas gestures are suspended until the modal closes.

## 8. Visual design

### 8.1 Theme

- **Dark** is the default theme (D8). Options: Follow system, Dark, Light.
- The canvas surround is dark in dark theme and mid-gray in light theme. The artwork remains bounded by a visible edge.
- Panels in dark theme are slightly lighter than the background and use rounded corners with soft shadows.

### 8.2 Design tokens

Define these as named tokens. Do not hard-code values in views.

| Token | Dark theme | Light theme | Use |
|---|---|---|---|
| `color.bg.app` | `#1E1E1E` | `#F2F2F4` | Workspace background |
| `color.bg.surround` | `#161616` | `#D9D9DE` | Canvas surround |
| `color.bg.panel` | `#2A2A2C` | `#FFFFFF` | Panels, popovers |
| `color.bg.topbar` | `#242426` | `#F7F7F9` | Top bar |
| `color.text.primary` | `#F2F2F2` | `#1C1C1E` | Labels |
| `color.text.secondary` | `#A0A0A6` | `#6E6E73` | Dimensions, hints |
| `color.accent` | `#0A84FF` | `#0A7AFF` | Apply, selected states, active tool, slider fill |
| `color.accent.text` | `#FFFFFF` | `#FFFFFF` | Text on accent |
| `color.control.track` | `#4A4A4E` | `#C7C7CC` | Toggle off, slider track |
| `color.danger` | `#FF453A` | `#FF3B30` | Destructive actions |
| `color.disabled.opacity` | 0.40 | 0.40 | Disabled controls |
| `color.focus` | `#FFFFFF` at 2 pt ring | `#0A84FF` at 2 pt ring | Keyboard focus ring |

Accent colors may differ slightly per platform but must keep the same role.

### 8.3 Shape and spacing

| Token | Value |
|---|---|
| `radius.panel` | 20–28 pt (use 24 pt) |
| `radius.pill` | Full height |
| `radius.thumbnail` | 6 pt |
| `size.icon.button` | 52 pt circular |
| `size.touch.min` | 44 pt |
| `size.slider.track` | 3 pt (range 2–4) |
| `size.slider.thumb` | 20 pt white circle |
| `spacing.s` | 8 pt |
| `spacing.m` | 12 pt |
| `spacing.l` | 16 pt |
| `shadow.panel` | Blur 24 pt, offset y 8 pt, black at 35% (dark theme); black at 12% (light theme) |

### 8.4 Typography

- System sans-serif at the platform's default family.
- Section headers: bold, 22 pt at reference scale.
- Labels: regular, 17 pt.
- Values: 15 pt inside a pill.
- Gallery names: semibold, secondary text color. Gallery dimensions: 13 pt, secondary text color.
- Support Dynamic Type or the platform equivalent up to 150%, subject to the layout rules in [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §4.

### 8.5 Controls

- **Icon buttons:** monochrome line icons, 1.5–2 pt stroke, a single color that matches the label state (text primary normally, accent when active).
- **Pill buttons:** text in a capsule. Used for Cancel and for Drawing Pad labels.
- **Toggles:** platform-style switch. On is accent track with white knob on the right. Off is track color with white knob on the left.
- **Sliders:** 3 pt track, 20 pt white thumb, accent fill to the value. The value appears in a pill to the right of the label. Long-press the value to type a number.
- **Selected list row:** solid accent background with white text and a checkmark where the list is single-select.
- **Disabled:** 40% opacity and no hit response, except for the one-line reason shown on focus or long-press.

### 8.6 Icons and state

- Do not rely on color alone. Active tools show color and a filled icon variant. Selected rows show a checkmark. Dimmed items show the reason text.
- Destructive buttons show the danger color and a trash or warning icon.

### 8.7 Motion

- Panels slide in and out over 220 ms with an ease-out curve.
- Modal fades last 180 ms.
- Delete confirmation in gallery: centered modal with the artwork name, a dimmed background, and a checkmark on completion. Lasts 900 ms, then the item is removed.
- With "Reduce motion" on, transitions become cross-fades of 120 ms and no movement.

## 9. Workspace state persistence

The following is restored when a document is reopened:

- Active tool, active brush, and brush size and opacity.
- Active layer and layer panel expansion state.
- Viewport: zoom, pan, and rotation. The last viewport is saved in the manifest.
- Rail visibility and reference window position (see [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §6).
- Last open panel mode for the color panel (global, not per document).

The following is not restored: an open panel, an in-progress stroke, an unfinished adjustment preview. Each of these is canceled cleanly on close and the document is saved in its last committed state.
