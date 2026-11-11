# 11 — Extensions: Animation, Text, Shapes, Gradients, 3D, and Other Deferred Features

Everything in this file is **P1** (first post-1.0 release) or **P2** (later), unless a subsection says otherwise. None of it is required for 1.0. Each feature must be designed so that it does not change the behavior of non-animated, non-text documents.

## 1. Frame animation (P1)

Animation is a mode of a normal document. It is the baseline model for a frame-by-frame, layer-based animation with onion skinning and looping playback.

### 1.1 Frame model

- Turning animation mode on makes every top-level layer or group a **frame**. Frame order is the stacking order, bottom to top.
- A **background frame** (the lowest layer, flagged) persists across all frames.
- A **foreground layer** may be flagged to persist across all frames above the animated frames.
- Frames are ordinary layers. Painting, selection, adjustment, and blend-mode features all work. A frame may contain sublayers through a group.
- Each frame has a **hold duration** in whole frame ticks (1–90). A drawing can stay on screen for several ticks without duplicating its pixels.
- Frames can be duplicated, deleted, reordered, and copied between documents.
- The layer limit counts every frame (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1).

### 1.2 Timeline UI

- A horizontal strip pinned to the bottom of the workspace shows a thumbnail per frame.
- The current frame is highlighted. Its hold duration is shown as a stretch handle.
- Tap selects a frame. Drag reorders. Long-press opens frame options: Duplicate, Delete, Hold, Set as background, Set as foreground. An add-frame button sits at the end.
- At the left: a Play button, a frame counter, and a settings button.

### 1.3 Settings

| Setting | Range or options | Default |
|---|---|---|
| Frames per second | 1–60 | 12 |
| Playback mode | Loop, Ping-pong, One shot | Loop |
| Onion skin frames before / after | 0–8 each | 2 before, 1 after |
| Onion skin opacity | 5–100% | 50% |
| Onion skin tint | Off, or a before color and an after color | Before red, after green |
| Onion skin fill mode | Outline, Filled | Filled |
| Show UI while playing | On, Off | On |

### 1.4 Playback and rendering

- Playback renders cached frame composites. The first loop may render lazily, with a small progress indicator.
- The playhead cannot start a stroke during playback. Touching the canvas pauses playback.
- Onion-skin renders draw beneath the active frame at reduced opacity. They are never part of the exported frame.
- Frame composites are invalidated per frame when a layer in that frame changes.
- Frame timing is accurate to within one display refresh interval over a 30-second loop.

### 1.5 Interaction with other features

- Undo covers frame add, delete, reorder, and hold changes.
- Time-lapse keeps recording in animation mode and records frame switches.
- Layer opacity and blend modes apply within each frame.

### 1.6 Animation export

| Format | Notes |
|---|---|
| Animated GIF | 256 colors per frame. Dithering option. Loop count. Frame delay rounded to 10 ms. |
| Animated PNG (APNG) | Lossless, with transparency. |
| MP4 (H.264) | Resolution up to the canvas size. Background required: transparency is flattened onto the document background. |
| Image sequence | PNG or JPEG per frame, numbered with a zero-padded index. |
| Sprite sheet (P2) | All frames packed in one PNG with a JSON atlas. |

- Export shows an estimated file size.
- Warn when a GIF's dimensions exceed 1000 px on either side.
- Exported frame order and timing match playback, with holds expanded.

## 2. Text (P1)

Text is a special layer type. It stays editable until rasterized.

### 2.1 Creation and editing

| Aspect | Requirement |
|---|---|
| Creation | Tap the text tool, then tap the canvas to place a point-text box. Or drag to define a fixed area for area text. |
| Layer type | Text layer with a "T" badge in the layer panel. Paint tools are blocked on a text layer until it is rasterized, with a clear prompt. |
| Editing | Double-tap to edit. Text selection handles appear. The platform keyboard is used, with copy and paste. |
| Character | Font family and style; size 1–2000 pt; tracking −100 to 500; leading 50–300%; baseline shift; all caps; small caps; underline; strikethrough. |
| Paragraph | Left, center, right, or justify. First-line indent. Space before and after. Line wrap on or off in area text. |
| Fill | Solid color in 1.0. Gradient and texture fill are P2. |
| Transform | Move, rotate, scale. Scaling an area text box reflows the text. Scaling a point-text box scales the font. |
| Rasterize | Converts to a pixel layer at the document resolution. Undoable. |
| Export | Text layers are flattened with the composite. Layered export converts them to raster unless the format supports editable text. |

### 2.2 Fonts

- System fonts are available. Users can import fonts (TTF, OTF, TTC, and variable fonts) through the file picker. Imported fonts are stored in the app and listed under **Imported**.
- A project records the fonts it uses by PostScript name.
- A missing font on open falls back to a default, shows a notice listing the missing fonts, and keeps the original name so that the text returns to the original font when it becomes available.
- Font licensing is the user's responsibility. The app never embeds an imported font in an export unless the user chooses to.
- Emoji and complex scripts (Arabic, Devanagari, Thai) are shaped correctly. Right-to-left layout is supported. Text that cannot be shaped never crashes the layout engine.

## 3. Vector-style shape tools (P2)

The product is raster-first. Shapes are drawn as raster content but remain editable until committed.

- **Primitives:** line, rectangle, rounded rectangle, ellipse, polygon (3–20 sides), star, and arrow.
- **Parameters during editing:** stroke weight, stroke color, fill color or none, corner radius, side count.
- **After commit:** the shape is a normal raster layer. An **Edit shape** chip remains until the next action.
- **Rendering:** antialiased at the document resolution with 4× supersampling.

## 4. Gradients (P1)

| Parameter | Behavior |
|---|---|
| Types | Linear, radial, angular, and reflected. |
| Editing | Drag to set start and end points. Handles for each color stop. Up to 16 stops, each with a position and opacity. |
| Colors | From the palette or any color. Stops interpolate in document RGB (default). Perceptual interpolation is P2. |
| Target | Active layer, within the selection if one exists. Uses the fill's blend mode and opacity. |
| Commit | Explicit Apply or Cancel, with live preview. One undo step on Apply. |

## 5. 3D model painting (P2, optional)

A separate module for painting texture directly on 3D objects. It is not required by the core specification and must not affect 2D documents.

| Aspect | Requirement |
|---|---|
| Model formats | OBJ and USDZ import with UV maps. A model without UVs is rejected with an explanation. |
| Texture maps | Color (albedo), roughness, metalness, opacity, and normal (optional). Each is editable as a layer set. |
| Painting | Strokes are projected onto the surface from the current view, using the active brush. Seams are padded by dilation. |
| Camera | Orbit, pan, and zoom with touch gestures. A lock prevents accidental movement while painting. |
| Lighting | An environment image plus a directional light with intensity and angle. |
| Export | Textured model as USDZ or OBJ plus texture images. Flat texture maps as PNG. |
| Resolution | Texture size 512–4096 px per side. The layer limit follows [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1. |

## 6. CMYK and 16-bit documents (P2)

### 6.1 CMYK

- A CMYK profile option for print-oriented documents, with a soft-proof preview.
- Conversion happens at export, not while painting.
- The document keeps its working RGB during painting. The soft-proof is a view only.

### 6.2 16-bit per channel

- Doubles the bytes per pixel. The layer limit is halved (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1).
- Tile storage supports 16-bit premultiplied RGBA (see [12-data-and-engine.md](12-data-and-engine.md) §3).
- Export supports 16-bit PNG and TIFF.

## 7. Tiled canvas preview (P2)

- A tiling preview shows the artwork repeated on a 3 × 3 grid, with edge wrap, so strokes crossing an edge continue on the opposite side.
- Wrapped strokes are written to the layer once, in document coordinates.
- Tiling is a view mode. It never changes pixels.

## 8. Adjustment layers (P2)

- A non-destructive adjustment as a layer. Its parameters can be changed after creation.
- Adjustment layers follow the same effect catalog as in [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §2.

## 9. Sprite sheets and atlases (P2)

- Animation frames packed in one PNG, with a JSON atlas describing each frame's position, size, and timing.

## 10. Presentation mode (P2)

- Mirrors the canvas (no interface) to a connected external display, optionally with the interface hidden.

## 11. Pinned color panel (P2)

- The color panel can be pinned as a floating panel on larger screens.

## 12. Legacy brush import (P2)

- Third-party brush files (`.abr`) can be imported as an approximation.
- Unsupported features are listed in an import report. See [05-brushes.md](05-brushes.md) §12.4.

## 13. Color-vision simulation (P2)

- A non-destructive view overlay that simulates protanopia, deuteranopia, and tritanopia.
- See [06-color.md](06-color.md) §9.

## 14. Cloud sync, co-editing, and marketplace (not planned)

- Cloud sync and backup depend on a product decision about privacy terms (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §6).
- Real-time co-editing, collaboration, and a brush marketplace are out of scope.
- Any future network feature must be opt-in and encrypted in transit (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.3).

## 15. Deferred feature index

| Feature | Priority | Defined in |
|---|---|---|
| Frame animation | P1 | §1 |
| Text layers | P1 | §2 |
| Shape tools | P2 | §3 |
| Gradients | P1 | §4 |
| 3D painting | P2 | §5 |
| CMYK | P2 | §6.1 |
| 16-bit | P2 | §6.2 |
| Tiled preview | P2 | §7 |
| Adjustment layers | P2 | §8 |
| Sprite sheet | P2 | §9 |
| Presentation mode | P2 | §10 |
| Pinned color panel | P2 | §11 |
| Legacy brush import | P2 | §12 |
| Color-vision simulation | P2 | §13 |
| PSD and PDF interchange | P1 | [09-import-export-timelapse.md](09-import-export-timelapse.md) §1 |
| Harmony mode | P1 | [06-color.md](06-color.md) §3 |
| Palette capture | P1 | [06-color.md](06-color.md) §4.3 |
| Shape Snap | P1 | [04-canvas-and-input.md](04-canvas-and-input.md) §6 |
| Quick Fill | P1 | [04-canvas-and-input.md](04-canvas-and-input.md) §7 |
| Materials group in Brush Editor | P2 | [05-brushes.md](05-brushes.md) §8.2 |
