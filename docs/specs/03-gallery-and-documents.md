# 03 — Gallery, Documents, and Canvas Setup

## 1. Gallery

The gallery is the document home. It lists every artwork, stack, and trashed item the user owns in Artoperce storage. It is a view over the document store; it never moves or copies documents.

### 1.1 Layout

- **Title:** "Gallery" heading at top left.
- **Top-right capsule group:** **Select**, **Import**, **Photo**, then a circular **+** button for a new canvas. In portrait, the capsule collapses to a single **…** menu containing Import and Photo.
- **Search field:** below the title. Filters by title. Searching never changes stored order (P1: search by tag).
- **Grid:** cards left to right, wrapping. Card minimum width 160 pt; column count adapts to width.
- **Card contents:**
  - Thumbnail with the artwork's aspect ratio preserved. Landscape 4:3 and portrait (for example 2340 × 3120 px) both occur.
  - Name below the thumbnail: semibold, secondary text color.
  - Dimensions below the name in pixels, for example "4000 × 3000 px", smaller and dimmer.
  - Thumbnails have a 1 pt light border and a soft drop shadow.
  - Stacks show the cover thumbnail with two offset cards behind it and the stack count.
- **Background:** dark charcoal (`color.bg.app`). Text light gray.
- **Empty state:** centered message "Create your first artwork" with a one-line explanation and **New canvas** and **Import** buttons.

### 1.2 Thumbnails

- Generated from the artwork's flattened composite (background included when visible; checkerboard when transparent).
- Cached as `thumbnail.png` inside the document package (see [12-data-and-engine.md](12-data-and-engine.md) §1).
- Regenerated asynchronously after a save that changed pixels. Thumbnails update within 500 ms of a change.
- A missing thumbnail never blocks opening the document. The card shows a neutral placeholder and regenerates in the background.

### 1.3 Sorting

- Sort by: Last modified (default), Created, Name, Custom order.
- Custom order allows drag reordering in the grid.
- The chosen sort is a global setting (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1, Files).

### 1.4 Opening and creating

- Tap a card to open the document in the canvas workspace. The gallery shows a short open animation (fade and scale, 220 ms) unless Reduce motion is on.
- Tap **+** to open the New Canvas dialog (§6).
- **Import** and **Photo** create a new canvas from the chosen image at its pixel size (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §2).

### 1.5 Gallery settings

The gallery respects the sort setting, the trash retention setting, and the theme. The view remembers its scroll position and the last selection-mode exit.

## 2. Selection mode

Entered by **Select**. Each card gets a hollow circle in its top-right corner.

### 2.1 Behavior

- Tapping a card toggles its selection. The circle fills with the accent color and shows a checkmark.
- A selection count appears in the header: "3 selected".
- The top-right capsule changes to actions: **Stack**, **Preview**, **Share**, **Duplicate**, **Delete**.
- **Select all** and **Clear selection** appear in the header menu.
- The **+** button is replaced by a blue circular **Done** checkmark. Tapping it leaves selection mode.
- Single-item actions (Rename, Edit details) are hidden when more than one item is selected.
- Swipe a card right to select it and enter selection mode (P1).

### 2.2 Action rules

| Action | Rule |
|---|---|
| Stack | Groups the selected documents into a new stack (§3.2). Requires at least two items. |
| Preview | Opens the read-only preview (§5.2). With more than one item, opens the swipe-between preview. |
| Share | Opens the export sheet for the selection. Multi-item share asks first whether to share flattened images or project files (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §6). |
| Duplicate | Creates an independent copy of each selected document (§5.3). |
| Delete | Moves the selected documents to the trash after a confirmation (§4). |

## 3. Stacks, grouping, and reordering

### 3.1 Drag and drop

- Long-press a card to lift it. Drop onto another card to create a stack, or onto a gap to reorder.
- Dragging a card out of a stack removes it from the stack. The stack collapses to one card when it holds a single item.
- Drop on the gallery edge (left or right) to move the card to the top or bottom of the grid.

### 3.2 Stack rules

- A stack is a named group of documents shown as one tile.
- Each stack has a cover: the first document by default, or any chosen document.
- A stack may be renamed. Its default name is "Stack" followed by a number.
- A stack holds at most 200 items.
- Opening a stack shows its items in a sheet with the same card layout.

## 4. Trash and deletion

- Delete moves documents to Trash. The Trash appears as a fixed item at the bottom of the gallery and in the storage view.
- **Confirmation:** every deletion asks for confirmation. The confirmation names the documents, states they go to Trash for the retention period, and offers Delete and Cancel.
- **Animation:** the confirmed delete shows the centered modal with the artwork name and a checkmark (see [02-workspace.md](02-workspace.md) §8.7).
- **Retention:** default 30 days. Options: 7, 14, 30, 90 days, or never. See [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1.
- Each Trash item shows days remaining.
- **Restore:** returns the document to the gallery at its previous position in sort order.
- **Empty Trash:** requires confirmation that states the number of items and total size. It cannot be undone.
- Trashed documents keep their pixels and time-lapse data. They are excluded from the gallery count.
- Expired items are removed by a background sweep. The sweep runs at launch and at most once per day.

## 5. Preview, rename, and duplicate

### 5.1 Rename

- Inline edit on the card label, or **Rename** in the card's long-press menu.
- Renaming changes only the title in the manifest and the gallery label. It never changes pixels or history.
- Titles are 1–120 characters. Empty titles are not allowed; the document falls back to "Untitled" plus a number.

### 5.2 Preview

- A read-only view of the document composite with pinch to zoom and pan.
- A swipe moves between selected items, or between gallery items when opened from a single card.
- Preview never writes to the document. It does not update the modified date.
- A **Open** button in the preview opens the document in the canvas workspace.

### 5.3 Duplicate

- Creates a new document with the title suffixed " copy" (for example "Harbor study copy"). A number is added when the suffix already exists.
- The copy has its own history, its own time-lapse data, and its own journal.
- Subsequent edits to either document never affect the other.

## 6. New canvas

### 6.1 Limits and layer capacity

Canvas limits are computed, never hard-coded.

| Limit | Value |
|---|---|
| Minimum canvas edge | 1 px |
| Maximum canvas edge | 16,384 px, subject to GPU texture limits and the layer capacity formula |
| Maximum total pixels | 268,435,456 (16,384 × 16,384). Warn above 100 million. |
| Minimum layer count | 2 (background plus one layer). If the formula yields fewer, refuse creation and explain. |

**Layer capacity formula:**

```
B_canvas = min(0.40 × available_device_ram, 6 GB)     # "Automatic" memory budget
b_px     = 4 bytes for 8-bit RGBA, 8 bytes for 16-bit RGBA
R        = 4                                          # reserved layers: stroke buffer,
                                                      # selection mask, transform preview,
                                                      # undo scratch
N_layers = floor( B_canvas / (w × h × b_px) ) − R
```

- Under the "Conservative" memory budget setting (see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1, Advanced), B_canvas uses 25% of available RAM and a 3 GB cap.
- The New Canvas screen shows the computed maximum layer count live as dimensions change.
- Adding a layer beyond N_layers is blocked. The message states the limit and offers: flatten selected layers, reduce canvas size, or close other memory-heavy documents.
- The layer count includes every frame in animation mode (see [11-extensions.md](11-extensions.md) §1).

### 6.2 Dialog

Fields, in order:

1. **Name.** Defaults to "Untitled" plus a number.
2. **Preset.** Picker of built-in and saved presets (below).
3. **Width and height.** Numeric fields with unit menu. Units: pixels (default), inches, millimeters, centimeters.
4. **Resolution (DPI).** Default 300. Range 1–2400. Shown only when unit is physical. Pixel size stays authoritative.
5. **Orientation.** Swap button.
6. **Color profile.** sRGB (default) or Display P3 (P1 if not on the platform). See §6.4.
7. **Background.** White (default), Color (with picker), or Transparent.
8. **Bit depth.** 8-bit per channel (fixed in 1.0; 16-bit is P2).
9. **Preview** of aspect ratio, pixel size, estimated memory, and maximum layer count.
10. **Create** (primary) and **Cancel**.

Presets are shown in a list with name and size. Tapping a preset fills the fields without creating anything.

**Validation:** width and height must be positive integers within the limits in §6.1. Invalid fields are highlighted with a one-line explanation. Create is disabled while any field is invalid.

A successful create opens the new document directly. Cancel returns to the gallery without creating a document.

### 6.3 Built-in presets

Presets are editable copies. Editing a preset never changes another. Built-in presets can be reset to their defaults.

| Preset | Pixels | Notes |
|---|---|---|
| Screen | Device resolution | Uses the display's native pixel size |
| Square | 2048 × 2048 | |
| 4K | 3840 × 2160 | |
| HD | 1920 × 1080 | |
| A4 | 2480 × 3508 | 300 DPI |
| US Letter | 2550 × 3300 | 300 DPI |
| A3 | 3508 × 4961 | 300 DPI |
| Poster | 3600 × 5400 | 24 × 36 in at 150 DPI |
| Social post | 1080 × 1080 | |
| Story | 1080 × 1920 | |
| Icon | 1024 × 1024 | |
| Banner | 1500 × 500 | |

**Custom presets (P0):** a user may save a preset with name, width, height, unit, DPI, profile, background, and bit depth. Presets can be reordered and deleted. Deleting a preset never affects documents created from it.

## 7. Canvas information

A read-only sheet from Actions → Canvas → Canvas information. It can be opened during drawing without changing the canvas.

| Field | Source |
|---|---|
| Title and optional description | Manifest (description is editable here) |
| Width × height in pixels | Manifest |
| Width × height in the current unit | Derived from DPI |
| DPI | Manifest |
| Color profile and bit depth | Manifest |
| Background mode | Manifest |
| File size on disk | Package size, refreshed on save |
| Layer count against the computed maximum | Layer tree; limit from §6.1 |
| Stroke count | Statistics |
| Active drawing time | Statistics; pauses after 60 seconds of inactivity |
| Created and modified dates | Manifest |
| Last export date and format | Export log in manifest |

Statistics update incrementally and are stored in the manifest.

## 8. Canvas setup and transforms

### 8.1 Canvas background

- The background is a dedicated bottom layer with a color and a visibility toggle.
- Hiding the background exposes a checkerboard. The checkerboard is never exported.
- A document can start with a transparent background. The background color is kept as a hidden property and restored when the background is shown again.
- Flatten and export respect the background visibility. PNG export preserves transparency only when the background is hidden.

### 8.2 Canvas resize, crop, and resample

These are separate actions with a before and after preview and a confirmation.

| Command | Effect | Destructive | Undoable |
|---|---|---|---|
| Crop | Changes the canvas boundary. Pixels outside the boundary are kept for the session so the crop can be undone. On save, the user chooses Keep or Discard. | Yes | Yes |
| Resample | Changes pixel dimensions with a chosen interpolation. | Yes | Yes, with a checkpoint |
| Resize canvas (anchor) | Expands or trims the boundary from a nine-point anchor. Padding is transparent or the background color. | Yes | Yes |

**Resampling methods:** Bicubic (default), Bilinear, Lanczos, Nearest-neighbor (use for pixel art).

**Before confirmation,** the resample dialog shows the new layer limit (§6.1). If the new limit is below the current layer count, the dialog warns and blocks Confirm until the user removes layers or chooses a smaller target.

**Warning:** before any canvas resize that discards or resamples pixels, the app warns once per operation type per session.

### 8.3 Canvas transform commands

| Command | Effect | Destructive | Undoable |
|---|---|---|---|
| Flip view horizontal / vertical | Mirrors the display only | No | Not applicable (view state) |
| Flip canvas horizontal / vertical | Mirrors every layer's pixels | Yes | Yes |
| Rotate canvas 90° clockwise / counter-clockwise, 180° | Rotates every layer and swaps dimensions as needed | Yes | Yes |

Flip canvas and Rotate canvas create a time-lapse keyframe (see [09-import-export-timelapse.md](09-import-export-timelapse.md) §5.1).

### 8.4 Checkpoints

Before a destructive canvas operation (crop, resample, resize, flatten, profile conversion), the app writes a checkpoint of the affected layers so the operation can be recovered even after the session ends. Checkpoints are discarded after a successful save, or after 7 days.

## 9. Color profile and bit depth

| Item | Requirement |
|---|---|
| Working RGB profiles | sRGB (default) and Display P3 where the platform supports it. The profile list is extensible. |
| CMYK | P2 (see [11-extensions.md](11-extensions.md) §6). |
| Bit depth | 8-bit per channel (P0). 16-bit per channel (P2) halves the layer limit. |
| Assign profile | Relabels the document. Pixel values are unchanged. Shows a preview and a checkpoint. |
| Convert to profile | Transforms pixel values with the perceptual rendering intent. Shows a preview and a checkpoint. |
| Display | Converts to the display profile for output. Never displays untagged RGB as wide-gamut. |

Assign and Convert are separate commands.

## 10. Document lifecycle

| Operation | Required behavior |
|---|---|
| Open | Loads the full document, active layer, metadata, and last viewport. Opens without waiting for all tiles; remaining tiles load progressively. |
| Close | Commits the open journal, updates the thumbnail when pixels changed, and returns to the gallery. |
| Autosave | Commits every stroke and structural change to the journal. The user never needs a manual save. See [12-data-and-engine.md](12-data-and-engine.md) §4. |
| Save | A manual **Save** command is not offered. The status line shows "Saved" with the time, or "Saving…" while a write is pending. |
| Recovery | On an interrupted session, the next open validates the package, replays the journal, and shows a recovery notice that names the restored state. |
| Rename | Updates metadata and gallery label only. |
| Duplicate | See §5.3. |
| Delete | See §4. |
| Export | See [09-import-export-timelapse.md](09-import-export-timelapse.md). |
