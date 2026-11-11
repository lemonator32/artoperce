# 09 — Import, Export, Sharing, and Time-Lapse

## 1. Format matrix

| Format | Import | Export | Limits and rules |
|---|---|---|---|
| Native project (`.artoperce`) | Yes (P0) | Yes (P0) | Full fidelity, versioned. See [12-data-and-engine.md](12-data-and-engine.md) §1. |
| PNG | Yes (P0) | Yes (P0) | 8 or 16 bit. Alpha. Embeds color profile. Transparent background optional. |
| JPEG | Yes (P0) | Yes (P0) | Quality 1–100, default 90. No alpha; flattened over the background. Profile embedded. |
| TIFF | Yes (P0) | Yes (P0) | 8 or 16 bit. LZW or none. Alpha preserved. Profile embedded. |
| HEIC / WebP | Yes (P1) | Yes (P1) | Quality setting. Alpha where the format allows. |
| PSD | Yes (P1) | Yes (P1) | Layers, names, order, visibility, opacity, masks, and blend modes that map. Text becomes raster. Unsupported features listed in a report. |
| PDF | Yes (P1) | Yes (P1) | Export: single page at canvas size, profile embedded. Import: each page rasterized at a chosen DPI, as pages or as layers. |
| GIF / APNG / MP4 | No | Yes (P1, animation only) | See [11-extensions.md](11-extensions.md) §1.6. |
| Brush `.brush`, `.brushset` | Yes (P0) | Yes (P0) | See [05-brushes.md](05-brushes.md) §12. |
| Palette `.swatches`, hex list | Yes (P0) | Yes (P0, `.swatches` only) | See [06-color.md](06-color.md) §4.4. |
| SVG | No | No | Out of scope for 1.0. |

**Import size and dimension limits:** default 500 MB file size and 16,384 px on either side. Both limits are configurable in Advanced settings. Files over a limit are rejected with a plain explanation of the limit and the file's actual size or dimension.

**Robustness:** importers must reject malformed input without crashing or hanging (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.4).

## 2. Import

### 2.1 Behavior by entry point

| Entry point | Result |
|---|---|
| Gallery → Import | Image becomes a new canvas at the image's pixel size. A native project is added to the gallery. A PSD becomes a new canvas with layers (P1). |
| Gallery → Photo | New canvas from a library photo at its original resolution. Requires photo library permission at the moment of use. |
| Canvas → Actions → Add → Insert file or Insert photo | The image becomes a new layer, centered, scaled to fit the canvas, with a transform session open. |
| Paste (Ctrl/Cmd + V or Actions → Paste) | New layer from image data. Text data creates a text layer (P1). |
| Drag and drop onto the canvas | Inserts as a new layer, with a transform session open. |
| Drag and drop onto the gallery | Imports as a new canvas. |
| Drag and drop onto the reference window | Loads as the reference image. |
| Multiple files | Imported in order. Progress shown. A failure on one file does not stop the rest, and the failures are listed afterward. |

### 2.2 Image processing on import

- Images with an embedded color profile are converted into the document profile at import. Images with no profile are treated as sRGB.
- Orientation metadata is applied so the picture appears upright.
- Imported pixels are stored at the image's own bit depth, converted to the document's 8-bit storage on import.

### 2.3 Layered import (P1)

- PSD import preserves layer names, order, visibility, opacity, and compatible blend modes.
- Layers that cannot be preserved are rasterized or discarded, and the import report lists each one.
- Import never silently converts a feature in a way that changes the result.

### 2.4 Imported native projects

- Opening a `.artoperce` file from outside the app copies it into the app's storage. It does not modify the original file.
- A project whose minimum reader version is newer than the app is refused with an explanation (see [12-data-and-engine.md](12-data-and-engine.md) §7).

## 3. Export options

Export is available from Actions → Share, from the gallery's Share action, and from time-lapse export.

| Option | Values | Default |
|---|---|---|
| Format | Native, PNG, JPEG, TIFF; P1 HEIC, WebP, PSD, PDF | PNG (from the Files setting) |
| Quality (JPEG, HEIC, WebP) | 1–100 | 90 |
| Dimensions | Original size; percentage; width or height with locked aspect | Original |
| Scope | Whole artwork; visible layers only; selection only (P2); each layer as a separate file with transparency (P1) | Whole artwork |
| Transparency | On / off, for formats that support it | Follows background visibility |
| Metadata | Author name and copyright (optional). Stripped by default. | Stripped |
| Naming | Project title plus date. A number is added on collision. Never overwrites. | Title plus date |
| Estimated size | Shown before export, updated when options change | — |

## 4. Export workflow

### 4.1 Steps

1. Choose Share or Export.
2. Select the format and options (§3).
3. Review the estimated output size. The app checks that the format can preserve the requested content, and lists anything it cannot.
4. Render from a stable snapshot. If a stroke is in progress, the export waits for pen-up and uses the state after that stroke.
5. Show progress for exports that take longer than about one second. Long exports can be canceled.
6. Confirm success and offer the platform share or save destination.
7. On failure, leave the source project unchanged and show an actionable message.

### 4.2 Transparency and background

- PNG and TIFF preserve transparency only when the background is hidden. Otherwise the background is included.
- JPEG never has transparency. The background is flattened in.
- If a requested transparency cannot be represented, the background is flattened and a notice explains it.

### 4.3 Metadata

- Metadata is stripped by default. Stripped data includes author, location, and device information.
- The user may add an author name and copyright in the export sheet.
- Exports do not include time-lapse data, reference images, or guides, unless the user explicitly exports the native project with time-lapse included (§6.2).

### 4.4 Color

- Exported files embed the document's color profile.
- The export converts the document to the output profile when the target format requires it.
- Round-trip rule: the flattened export matches the visible canvas within the tolerance in [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §5.3.

### 4.5 Export report

- Each export produces a report when features are dropped or changed. Examples: a blend mode the format does not support, text rasterized, a layer clipped to an unsupported target.
- The report is shown before export when the user has selected a format that drops features, and it lists each item.
- Unsupported effects are never silently converted.

### 4.6 Layer export (P1)

- Export each layer as a separate file with transparency.
- File names include the layer name, sanitized for the file system, and an index.

### 4.7 Export failure

- Disk full: offer to free space (`E_DISK_FULL`, see [12-data-and-engine.md](12-data-and-engine.md) §9).
- Unsupported feature: list what is dropped (`E_UNSUPPORTED_FEATURE`).
- Export failed or canceled: the source project and time-lapse data are untouched.

### 4.8 Export history

- The last export date and format are recorded in the manifest and shown in canvas information (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §7).

## 5. Time-lapse

### 5.1 Recording

| Aspect | Requirement | Default |
|---|---|---|
| Enable | Per-document toggle in the Video tab. Global default in Preferences. | On for new documents |
| Captured events | Strokes (with seed and brush snapshot), fills, transforms, adjustment commits, layer changes, selections, canvas view changes, undo and redo | — |
| Storage | Compact event log plus keyframe snapshots every 60 seconds or every 200 operations, whichever is first. Stored in the project package. | — |
| Keyframes for destructive edits | Canvas resample, crop, flip, rotate, and flatten each produce a keyframe so replay stays correct. | — |
| Overhead | Under 3% of frame time on the reference device. Recording runs at lower priority than stroke rendering. | — |
| Size cap | Warn at 500 MB. Offer to compact or stop recording. Never delete without consent. | — |
| Privacy | Stays on the device. Removed from exported flattened images. | — |

- Time-lapse keeps working in animation mode and records frame switches (see [11-extensions.md](11-extensions.md) §1).
- Turning recording off stops new capture. Existing recorded data stays until cleared.

### 5.2 Replay

- A replay view in the Video tab renders the artwork from the log.
- Controls: scrub, pause and play, and speed from 0.5× to 64×.
- The replay runs on a copy. It never changes the document.
- A progress bar shows position in the time-lapse.

### 5.3 Export

| Option | Values | Default |
|---|---|---|
| Length | Full length (all recorded time, idle time removed); Short (compressed to 15, 30, or 60 seconds) | Full length |
| Resolution | Document size, capped at 4096 px on the long edge; or a social preset (1080 × 1080, 1080 × 1920, 1920 × 1080). The canvas is framed or letterboxed. | Document size |
| Format | MP4 (H.264). HEVC and GIF preview are P1. | MP4 (H.264) |
| End hold | 0–5 seconds on the finished artwork | 0 seconds (off) |
| Watermark | Text or image, off by default | Off |

- Cancellation is available during export.
- A failed export leaves the project and recording untouched.
- Export of a 30-second version completes without changing the project (acceptance).

### 5.4 Clear

- **Clear time-lapse** is an explicit command in the Video tab.
- It removes all recorded data for the document after confirmation.
- The confirmation shows the space that will be reclaimed. The result shows the space reclaimed.

## 6. Sharing

### 6.1 Single document

- Sharing opens the export sheet with the estimated size, **Save to library**, and **Share**.
- Success or an actionable failure is reported.
- The platform share sheet is used for sharing.

### 6.2 Native project

- Sharing a native project offers "Include time-lapse". The default is off (decision D15). When on, the time-lapse data is included in the file.
- Including time-lapse is an explicit choice each time.

### 6.3 Multiple documents

- Gallery multi-select can share several artworks.
- Before sharing, the user chooses flattened images or project files.
- Flattened images use the export options in §3, applied to each document.

## 7. System integration

| Feature | Requirement |
|---|---|
| Share sheet and save dialog | Used for all exports. Save into any folder the platform permits. |
| Open in | The app registers for `.artoperce`, `.brush`, `.brushset`, and `.swatches`. |
| Photo library | Save to the library, and import from it. Permission requested only at the moment of use, with a plain-language reason. |
| Drag and drop | Between the app and other apps, including multi-window on platforms that support it. |
| Cloud storage folders | Appear as ordinary locations. The app never assumes network reachability and handles files that are still downloading (shows a waiting state and retries). |
| External display (P2) | Present mode mirrors only the canvas to a connected display, with the interface hidden. |
| Files and clipboard | Clipboard content is validated for type and size before use. Paste creates a layer and does nothing else automatically. |

## 8. Export and import acceptance

- A PNG export with transparency enabled matches the visible canvas and keeps transparency when the background is hidden.
- A layered PSD round trip (P1) keeps layer order, alpha, visibility, blend mode, and masks for every supported feature.
- Export canceled or failed leaves the source project intact.
- A corpus of malformed and oversized files is rejected within the documented limits.
