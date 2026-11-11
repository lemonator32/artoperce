# 06 — Color System

## 1. Color panel

Opened from the color swatch in the top bar. The panel never changes the active brush, tool, layer, or viewport.

### 1.1 Layout

- **Drag handle** at the top. Drag down to dismiss.
- **Header:** the label "Colors", a primary color swatch, and a secondary color swatch at the right.
  - Tap the primary swatch to make it active for editing. Tap the secondary swatch to edit the secondary color.
  - A swap control between the two swatches exchanges them (also key X on desktop).
- **Body:** the content for the selected mode.
- **Mode selector** at the bottom with five modes: **Disc**, **Classic**, **Harmony**, **Value**, **Palettes**. Each mode has an icon and a label.
- The panel remembers its last mode across sessions.

### 1.2 Modes

| Mode | Priority | Contents |
|---|---|---|
| Disc | P0 | Outer hue ring. Inner saturation and brightness field. Active swatch and previous color shown at the center. |
| Classic | P0 | Rectangular saturation and brightness square with a separate horizontal hue slider. Hue, saturation, and brightness sliders below. |
| Harmony | P1 | A wheel showing the base color and linked colors defined by the selected harmony rule (§3). |
| Value | P0 | Numeric sliders and fields for HSB, RGB, and hexadecimal entry. Alpha slider when alpha is enabled (§2.3). |
| Palettes | P0 | Named palette sets with swatch grids (§4). |

### 1.3 Disc and Classic behavior

- Dragging inside the ring or field changes the color live. The primary swatch and the rail color indicator update live.
- Changing the color affects only subsequent strokes, fills, shapes, and text. It does not change pixels already painted (see §8).
- The field shows a crosshair at the current position. The hue ring shows a marker at the current hue.
- The color commits to the recent colors list only when a stroke or fill completes (§5), not while dragging.

## 2. Value mode

### 2.1 Controls

| Control | Range | Notes |
|---|---|---|
| H | 0–360° | Rainbow track. |
| S | 0–100% | Saturation. |
| B | 0–100% | Brightness (HSB value). |
| R, G, B | 0–255 | Each a slider and numeric field. |
| Hex | 6 digits, 3 digits, 8 digits with alpha | Copyable. Input is case-insensitive. A leading "#" is optional. |
| A | 0–100% | Alpha slider. Shown only when alpha is enabled (§2.3). |
| History | Recent colors (§5) | A row of swatches with a Clear button. |
| Presets | A grid of bundled preset swatches | Three rows of ten swatches. Tapping sets the color. |

### 2.2 Synchronization

- HSB and RGB are kept in sync. Changing either updates the other immediately.
- Hex stays in sync with RGB. Invalid hex input shows an inline message and does not change the color until valid.
- Test vector: `#18FFE2` = R 24, G 255, B 226 = H 172°, S 90%, B 100%.

### 2.3 Alpha

- Alpha is shown in Value mode as an A slider and an 8-digit hex field.
- A color's alpha multiplies with the brush's flow and opacity when painting. Alpha is part of the stored color for palette swatches.

### 2.4 Rounding

- RGB values are integers. HSB values keep one decimal place internally. A color round-trips through HSB and RGB without drift of more than 1 unit in any RGB channel.

## 3. Harmony (P1)

Given a base hue H on a 360° wheel, Harmony mode offers the following relationships. Dragging the base color moves all linked colors together. Each linked color may be adjusted independently.

| Rule | Hues |
|---|---|
| Complementary | H, H + 180° |
| Split complementary | H, H + 150°, H + 210° |
| Analogous | H − 30°, H, H + 30° |
| Triadic | H, H + 120°, H + 240° |
| Tetradic (square) | H, H + 90°, H + 180°, H + 270° |
| Monochromatic | H with varied saturation and brightness |

- The harmony set may be saved as a palette in one tap.
- Hue wraps modulo 360°.
- Each linked color has its own saturation and brightness. Changing the base hue only changes the hues of the linked colors. Changing base saturation or brightness applies the same delta to linked colors unless that color has been adjusted independently.

## 4. Palettes

### 4.1 Structure

- A **palette** has a name, an ordered list of swatches, and creation and modification dates.
- A palette holds up to 30 swatches in a grid. P1: a scrolling grid for more.
- A palette set is a named group of palettes. The Palettes mode shows the set's palettes as tabs or a list.
- One palette may be set as the default. The default palette opens first.

### 4.2 Operations

| Operation | Behavior |
|---|---|
| Add current color | Adds the primary color at the end of the palette. |
| Set current color | Tap a swatch to make it the primary color. |
| Rename a swatch | Long-press a swatch to rename it. |
| Replace a swatch | Long-press a swatch and choose Replace to set it to the primary color. |
| Delete a swatch | Long-press a swatch and choose Delete. |
| Reorder | Drag a swatch. Insertion feedback is shown. |
| Rename palette | From the palette's options. |
| Duplicate palette | Creates a copy with the name suffixed " copy". |
| Delete palette | Requires confirmation. The bundled default palettes can be reset but not deleted. |

Selected swatches show a 2 pt border and a checkmark (not color alone).

### 4.3 Capture from image (P1)

- The user picks a photo or file, or the current canvas.
- The app extracts 5–30 dominant colors by clustering, for example k-means in a perceptual color space.
- A preview shows the proposed palette. The user confirms or edits before saving.

### 4.4 Import and export

- **Native palette:** `.swatches`, a ZIP with a JSON color list. Export produces this format.
- **Plain hex list:** one hex value per line. Import accepts this format (P0).
- **Legacy palette files:** P2, where feasible.
- Imported palettes whose name exists offer Replace, Keep both, or Cancel. Import never silently overwrites.

### 4.5 Bundled palettes

- A default palette set ships with the app. Palette names and colors are Artoperce's own. Do not copy third-party palette artwork or names.

## 5. Recent colors

- Stores the most recent distinct colors used by a committed stroke or fill, most recent first.
- Holds 10 colors in 1.0. Duplicates move to the front instead of repeating.
- A color is added only when committed. Dragging the color picker does not add entries.
- Shown as a row in Value mode and as a strip at the bottom of Disc and Classic modes.
- A **Clear** command removes all entries. Clearing requires no confirmation.
- Recent colors are stored per device, not per document.

## 6. Color management

- Each document stores colors in its document color space. The profile is in the manifest (see [12-data-and-engine.md](12-data-and-engine.md) §2).
- Profiles in 1.0: sRGB (default) and Display P3 where the platform supports it.
- Colors are converted explicitly at import and export. Display RGB values are never treated as universal color values.
- The color picker displays colors in the document profile. Hex values are sRGB unless the document is in Display P3, in which case the hex field shows the sRGB approximation with a notice.
- The eyedropper samples in the document profile (see [04-canvas-and-input.md](04-canvas-and-input.md) §10.4).

## 7. Primary and secondary colors

- The **primary** color is used by Paint, Fill, Quick Fill, text, and shapes.
- The **secondary** color is used only for two-color dynamics in brushes (see [05-brushes.md](05-brushes.md) §7.1).
- Swap exchanges primary and secondary. Key X on desktop. Available as a button in the panel header and as a stylus action.
- Smudge and Erase never change the primary color.

## 8. Color and tools

- A color change affects only subsequent strokes, fills, shapes, and text. It never repaints existing pixels.
- The active color is shown on the top bar swatch. It is optionally shown in the brush cursor (see [05-brushes.md](05-brushes.md) §9).
- Opening the color panel never changes the active brush or tool.

## 9. Accessibility aids

- Numeric and hex entry is always available as an alternative to the rings and fields.
- Selected swatches show a border and a checkmark, not color alone.
- The primary and secondary swatches have accessible names that state the color's hex value.
- P2: a color-vision simulation preview (protanopia, deuteranopia, tritanopia) as a non-destructive view overlay. It never changes the document.
