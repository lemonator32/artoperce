# 05 — Brush System

A brush is a named, versioned, JSON-serializable preset. It converts an input path and its dynamics into a deterministic sequence of stamps. The brush library lets users choose and organize brushes. The Brush Editor lets users change every parameter with a live Drawing Pad.

Priority values in this file: P0 required for 1.0 unless marked.

## 1. Brush library

### 1.1 Structure

- A **brush set** is a named, ordered collection of brushes. The library shows one set at a time.
- The built-in set is named **Artoperce Core**. It holds the default library (§11). It is read-only except for brush-level reset.
- Users create their own sets. A set holds up to 500 brushes.
- Each brush belongs to one set and one category. Categories are shown within a set.

### 1.2 Operations

| Operation | Rule | Priority |
|---|---|---|
| Select brush for Paint | Sets the paint tool's brush. Updates the rail size and opacity to the brush's last values. | P0 |
| Select brush for Smudge or Erase | Each tool keeps its own brush selection, unless "Use same brush for all tools" is on (§13). | P0 |
| Create brush | Opens the Brush Editor on a new preset based on the Default preset. | P0 |
| Duplicate brush | Copies the preset with the name suffixed " copy". Never overwrites the source. | P0 |
| Rename brush | Inline edit. Names are 1–60 characters and unique within a set. | P0 |
| Reorder brushes | Drag a row. | P0 |
| Create, rename, or delete set | Deleting a user set deletes its brushes after confirmation. Artoperce Core cannot be renamed or deleted. | P0 |
| Delete brush | User brushes only. Requires confirmation. | P0 |
| Reset built-in brush | Restores the built-in definition (§8.3). | P0 |
| Import / export brush and set | `.brush` and `.brushset` (§12). | P0 |
| Search | Filters by name within the open set. | P1 |
| Favorites and recents | A Recent row shows the last 10 brushes used. A star toggle per brush. | P1 |

### 1.3 Brush row

- Name above a horizontal stroke sample rendered with the brush at the sample size.
- The stroke sample is generated from the brush's preview. Brushes with no preview use the default sample.
- Selected row: solid accent background with white text and a checkmark.
- Long-press menu: Edit, Duplicate, Rename, Export, Reset to default (built-in only), Delete (user only).

### 1.4 Empty state

An empty user set shows "No brushes yet" with a one-line explanation and **New brush** and **Import brush** buttons.

## 2. Brush Editor

The Brush Editor is a full-screen editor. It is the only place to change brush parameters.

### 2.1 Layout

Three columns in landscape. Portrait collapses the attribute list into a segmented top bar, and collapses the Drawing Pad into a tab. Controls never shrink below 44 pt for touch.

| Column | Contents |
|---|---|
| Left: Attribute list | 14 groups in the order given in §2.2. Selected group has an accent pill background. |
| Middle: Settings | Section headers in bold. Each setting is a label, a value pill at the right, and a slider or toggle beneath. |
| Right: Drawing Pad | A live test canvas. Top-left pill "Drawing Pad" with a stroke icon. Top-right: Cancel and Apply. A brush preview strip at the top of the attribute list shows the current brush's stroke sample. |

### 2.2 Attribute groups

The 14 groups, in order:

1. Stroke path
2. Stabilization
3. Taper
4. Shape
5. Grain
6. Rendering
7. Wet Mix
8. Color Dynamics
9. Dynamics
10. Stylus
11. Properties
12. Materials
13. Preview
14. About

Each group is defined in §4–§8 and §10. The grouping is fixed; users cannot hide groups in 1.0.

### 2.3 Drawing Pad

- Accepts the same input as the canvas, including pressure, tilt, and barrel roll when available.
- Live: every setting change updates the pad immediately. The stroke already on the pad re-renders with the new value.
- **Clear pad:** removes all test strokes. Never affects the artwork.
- **Sample strokes:** the pad starts with a stroke sample, a stamp sample, and a pressure and tilt test path. Each can be shown or hidden from the Preview group.
- **Backgrounds:** neutral and contrasting. Switchable from the Preview group. Used to reveal opacity and grain.
- Changes to the pad never modify the artwork or the canvas history.

### 2.4 Editing transaction

- Opening the editor creates a **working copy** of the preset. All edits go to the working copy.
- **Cancel** discards the working copy. The original preset is unchanged. Confirmation is required when there are unsaved changes.
- **Apply** commits the working copy. The saved brush uses the new settings for new strokes. Existing strokes are not changed (they replay with their stored brush snapshot; see [12-data-and-engine.md](12-data-and-engine.md) §5).
- The rail and tool state update on Apply, not during edits.
- Apply is disabled when the name is empty or duplicated in the set.

### 2.5 Keyboard and accessibility

- Every slider has a numeric field (long-press the value pill to type).
- Every toggle is a labeled switch.
- Dimmed controls show a one-line reason when focused. For example, "Enable Alpha Threshold to set the amount."

## 3. Brush data model

- A preset has an `id`, `name`, `category`, `schema` (integer, starts at 1), `version` (integer, incremented on each Apply), and `author`.
- Every parameter has a fixed key, a range, and a default (§4–§10). Keys are defined in [12-data-and-engine.md](12-data-and-engine.md) §6.
- Values outside the documented range are rejected on save and clamped with a notice on load.
- The full preset is stored in the `.brush` file (§12) and in each document's `brushes/` folder for brushes used by that document.

## 4. Stroke engine

### 4.1 Stroke path

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Spacing | 1–500% of stamp width | 10% | Below about 5%, the stroke looks continuous. Set 100%+ to see separated stamps. |
| Spacing jitter (xy) | 0–100% | 0% | Random offset perpendicular and along the path. |
| Falloff | 0–100% | 0% | Fades stamp opacity with distance along the stroke. Dynamic: pressure. |
| Streamline | 0–100% | 0% | Light smoothing of the drawn line after the stroke ends. Affects the committed geometry only. |

Spacing is measured in stamp widths. The spacing remainder is carried across input samples so that stamp density is uniform along the path.

### 4.2 Stabilization

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Stabilization | 0–100% | 0% | Averages recent samples. Adds visible lag by design. |
| Motion filtering | 0–100% | 0% | Removes small-radius jitter. Improves slow, curved lines. |
| Expression | 0–100% | 0% | Preserves fast, deliberate strokes through the filter. |

- A live comparison toggle in the Preview group shows the stroke with and without stabilization.
- Stabilization is applied to the input path before stamp generation (see §4.4 step 2).
- At Stabilization 50%, the added lag must not exceed 60 ms on the reference device (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §2).

### 4.3 Taper

Taper is controlled independently for **Pressure** input and **Touch** input (finger or mouse). Each has the same controls.

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Start taper length | 0–100% of stroke | 0% | Range handle on the left of the taper track. |
| End taper length | 0–100% of stroke | 0% | Range handle on the right of the taper track. |
| Tip size | 0–100% | 50% | Size at the tapered end. |
| Opacity | 0–100% | 100% | Opacity at the tapered end. |
| Pressure influence | 0–100% | 0% | How strongly pressure drives the taper. |
| Sharpness (tip) | 0–100% | 60% | Shape of the tapered end. |
| Link tip sizes | On / off | On | When on, start and end tips use the same size. |
| Tip animation | On / off | On | Animates the taper while the stroke is drawn. |

- The taper track shows a tapered wedge background and two blue handles.
- Touch taper defaults to the same controls with Link tip sizes off and a Size slider at Max.

### 4.4 Stamp pipeline

For each interpolated stamp position the engine performs these steps in fixed order. This keeps output deterministic.

1. **Interpolate** between input samples at the configured spacing. Carry the spacing remainder across samples.
2. **Stabilize and streamline**, then apply guide constraints ([08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §3). Guide constraints do not change dynamics.
3. **Compute stamp transform:** size, rotation, scatter, and jitter, using the stroke's random seed.
4. **Evaluate responses:** pressure, tilt, speed, and taper curves produce final size, opacity, and flow.
5. **Sample the shape texture**, multiply by grain (§5.2), and apply color dynamics (§7.1).
6. **Composite** into the stroke buffer using the rendering mode (§6.1). On pen-up, composite the stroke buffer into the layer with the brush blend mode.

The random seed is stored with each stroke, so replay, time-lapse, and symmetry mirroring reproduce the same marks.

## 5. Shape and grain

### 5.1 Shape

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Stamp source | Image | Round (bundled) | See §5.3. |
| Rotation | 0–360° | 0° | Fixed angle, or follow stroke direction. Dynamic: tilt azimuth. |
| Rotation dial | 0–360° | 0° | Circular control, 0° at top. A blue handle sets the default orientation. A green dot shows the current stroke direction. |
| Scatter | 0–100% | 0% | Random displacement of each stamp. |
| Count | 1–16 | 1 | Stamps per position. |
| Count jitter | 0–100% | 0% | Random variation of the count. |
| Randomized | On / off | Off | Random rotation and mirror per stamp. |
| Flip X | On / off | Off | Mirrors the stamp horizontally. |
| Flip Y | On / off | Off | Mirrors the stamp vertically. |
| Pressure roundness | 0–100% | 0% | Reduces the stamp's roundness under pressure. |
| Tilt roundness | 0–100% | 0% | Reduces the stamp's roundness as tilt increases. |
| Roundness vertical jitter | 0–100% | 0% | Random squash on the vertical axis. |
| Roundness horizontal jitter | 0–100% | 0% | Random squash on the horizontal axis. |
| Shape filtering | No filtering, Classic filtering, Improved filtering | Improved filtering | Sampling quality of the stamp. |

Shape filtering values: **No filtering** samples nearest-neighbor; **Classic** samples bilinear; **Improved** samples with mipmapped trilinear filtering.

### 5.2 Grain

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Grain source | Image | Paper (bundled) | See §5.3. |
| Mode | Moving, Texturized | Moving | **Moving** keeps the texture attached to the stamp. **Texturized** keeps it fixed to the canvas, so overlapping strokes share paper tooth. |
| Scale | 1–500% | 100% | Grain tile size relative to the canvas (Texturized) or the stamp (Moving). |
| Depth / contrast / brightness | 0–100% | 50% | Strength of the grain's effect on opacity. |
| Blend | Multiply, Subtract, Overlay, Darken, Lighten | Multiply | How grain combines with the stamp. |
| Relative to stroke | On / off | Off | Grain is measured from the stroke's start instead of the canvas. |
| Offset x / y | −100 to 100% of the grain tile | 0 | Shifts the grain. |
| Rotation | 0–360° | 0° | Rotates the grain. |

Grain is sampled and applied per stamp, after the stamp's shape is sampled (§4.4 step 5).

### 5.3 Shape and grain sources

- **Sources:** the bundled library, an imported image (with a grayscale conversion option), a photo, or a file import.
- **Transforms:** a source may be inverted, flipped, rotated, and cropped in the source editor.
- **Preview:** each source shows how it looks as a stamp, as a repeated texture, and in a sample stroke.
- **Limits:** shape and grain sources are limited to 4096 × 4096 px (P0). They are mipmapped.
- **Warnings:** the editor warns when a source is not square (for stamps) or has an unsupported bit depth, and offers to fix it.
- **Draw your own (P2):** a small drawing pad creates a source in-app.

## 6. Rendering and wet media

### 6.1 Rendering modes

The Rendering group's Mode list is single-select. The default is **Uniform Glaze**.

| Mode | Family | Accumulation behavior |
|---|---|---|
| Light Glaze | Glaze | Weakest accumulation. Underlying color shows through. |
| Uniform Glaze | Glaze | Default. Even accumulation across the stroke. |
| Intense Glaze | Glaze | Stronger accumulation. |
| Heavy Glaze | Glaze | Strongest accumulation. Builds color quickly. |
| Uniform Blending | Blending | Each stamp mixes the stroke with the color beneath it at a uniform weight. |
| Intense Blending | Blending | Each stamp mixes with a stronger weight. |

**Glaze** modes accumulate transparency. Each stamp multiplies alpha and adds its color in proportion to its flow. Overlapping passes of different colors mix, so red over blue shows a purple tint.

**Blending** modes mix each stamp with what is already under it, without building up opacity.

Accumulation multipliers (starting values, tuned during testing): Light Glaze 0.25, Uniform Glaze 0.5, Intense Glaze 0.75, Heavy Glaze 1.0. Blending weight equals flow for Uniform Blending and `min(1, 2 × flow)` for Intense Blending.

### 6.2 Rendering controls

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Flow | 0–100% | 100% | Per-stamp deposit rate. |
| Wet edges | 0–100% | 0% | Edge pooling. Darkens and intensifies the stroke boundary (alpha edge detection with pooling). |
| Burnt edges | 0–100% | 0% | Edge darkening. |
| Burnt edges mode | Multiply, Darken | Multiply | How burnt edges combine. |
| Blend mode | Full list in [07-layers-and-selection.md](07-layers-and-selection.md) §3 | Normal | Brush-level blend mode applied when compositing the stroke onto the layer. |
| Luminance blending | On / off | Off | Blend weight follows the luminance of the stroke. |
| Alpha threshold | On / off | Off | Cuts alpha at the threshold amount. |
| Threshold amount | 0–100% | 0% | Enabled only when Alpha threshold is on; otherwise dimmed. |
| Classic normal combine | On / off | Off | Enabled only for Glaze modes; dimmed for Blending modes. |

Edge effects (wet and burnt) are applied as a post-process on the stroke mask before compositing. They never alter the layer outside the stroke.

### 6.3 Wet Mix

Wet Mix controls how paint picks up and mixes with the canvas. It applies to Paint strokes whose brush has any non-zero Wet Mix value, and to Smudge strokes.

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Dilution | 0–100% | 0% | Thins the paint and increases transparency. |
| Charge | 0–100% | 0% | Amount of paint load carried by the stroke. Higher charge resists pickup. |
| Attack | 0–100% | 0% | How quickly the canvas color under a stamp is picked up into the stroke's carried color. |
| Pull | 0–100% | 0% | How far the picked-up color streaks along the stroke. |
| Blur / wetness jitter | 0–100% | 0% | Softens and randomizes the wet effect. |

Per stamp, the carried color is updated as `carried = mix(carried, canvas_color_under_stamp, attack × (1 − charge))`. The pull parameter offsets the sampling point along the stroke direction by `pull × stamp_size`.

## 7. Color, dynamics, and stylus

### 7.1 Color Dynamics

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Hue jitter | ±180° | 0 | Per stamp or per stroke. |
| Saturation jitter | ±100% | 0 | Per stamp or per stroke. |
| Brightness jitter | ±100% | 0 | Per stamp or per stroke. |
| Jitter scope | Per stamp, Per stroke | Per stamp | Selects how jitter is sampled. |
| Two-color dynamics | On / off | Off | When on, the primary and secondary colors are the extremes of the jitter range. |

Color Dynamics does not change the stored color; it changes the stamp's rendered color.

### 7.2 Dynamics

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Speed → size | −100% to 100% | 0% | Positive makes faster strokes larger; negative makes them thinner. |
| Speed → opacity | −100% to 100% | 0% | Positive makes faster strokes more opaque; negative makes them lighter. |
| Jitter → size | 0–100% | 0% | Random size variation per stamp. |
| Jitter → opacity | 0–100% | 0% | Random opacity variation per stamp. |

Speed is measured in document pixels per second, normalized against the brush's default size.

### 7.3 Stylus

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Pressure → size, opacity, flow, bleed | Curve | Linear from 0.2 to 1.0 for size; constant 1.0 for opacity | Curve editor (§7.4). Falls back to a constant for finger and mouse input. |
| Tilt → size, opacity, grain depth | Curve, angle 0–90° | Off | Used only with hardware that reports tilt. |
| Barrel roll → rotation | On / off | Off | Stylus rotation changes the stamp rotation. |
| Barrel roll size | 0–100% | 0% | Size change from barrel roll. |
| Barrel roll opacity | 0–100% | 0% | Opacity change from barrel roll. |
| Bleed | 0–100% | 0% | Spreads paint from pressure and roll. |
| Cursor outline | None, Contrast, Active color | None | Outline style of the brush cursor when hovering. |
| Hover estimated pressure | 0–100% | 76% | Pressure assumed for the hover cursor preview. Hover never creates a mark. |
| Hover fill | None, Active color | None | Fill of the hover cursor. |
| Size compression | On / off | Off | Compresses size changes at high pressure. |

### 7.4 Curve editors

- Every curve has at least three editable points, a reset, and a live pressure test path on the Drawing Pad.
- Curves map [0, 1] input to [0, 1] output.
- Points are monotone-interpolated. Points are stored as `[input, output]` pairs.
- Dragging a point above or below its neighbors is clamped to keep the curve a function of input.
- Curve presets: Soft, Normal, Firm (also used for the global stylus pressure curve; see [10-settings-accessibility-help.md](10-settings-accessibility-help.md) §1).

## 8. Properties, Materials, Preview, and About

### 8.1 Properties

| Parameter | Range | Default | Notes |
|---|---|---|---|
| Minimum size | 0.1–100% of maximum size | 0.1% | Lower bound of the workspace size slider. |
| Maximum size | 1–8000 px | 100 px | Upper bound. |
| Default size | Between min and max | 20 px | Size applied when the brush is selected. |
| Minimum opacity | 0–100% | 0% | Lower bound of the workspace opacity slider. |
| Maximum opacity | 0–100% | 100% | Upper bound. |
| Default opacity | Between min and max | 100% | Opacity applied when the brush is selected. |
| Smudge strength | 0–100% | 50% | Default strength when the brush is used for Smudge (§13). |
| Preview size | Small, Medium, Large | Medium | Size of the stroke sample in the brush library. |

### 8.2 Materials (P2)

- The Materials group is visible in 1.0 with a single option **None**.
- P2: a surface material (a bundled texture set) modulates grain and wet-edge response. The group is specified fully when the feature is scheduled.

### 8.3 Preview

- Background: neutral or contrasting (§2.3).
- Sample: stroke sample, stamp sample, pressure and tilt test path. Each toggles on or off.
- Hover preview on or off.
- Live comparison of stabilization on and off (§4.2).
- Drawing Pad clear.

### 8.4 About

| Item | Behavior |
|---|---|
| Name | Editable, 1–60 characters, unique within the set. |
| Author | Default: the user's name from settings (if set), otherwise blank. Built-in brushes show "Artoperce". |
| Description | Optional, up to 280 characters. |
| Version | Read-only. Incremented on each Apply. |
| Preview image | Regenerated on Apply. |
| Create new reset point | Stores the current preset as a named restore point, with the timestamp. |
| Reset brush | Restores the most recent reset point, or the built-in definition for built-in brushes. Confirmation required. |
| Last reset point | Shows the timestamp of the most recent reset point. |

### 8.5 Reset rules

- For a **built-in** brush, Apply saves the edited values in place and keeps the built-in definition as the implicit first reset point. **Reset to default** restores the built-in definition.
- For a **user** brush, reset points are explicit. Reset brush restores the most recent point.
- Reset never changes strokes already on the canvas.

## 9. Brush cursor and feedback

- **Outline:** drawn at the true brush footprint in view space (§1.4 in [04-canvas-and-input.md](04-canvas-and-input.md)).
- **Center dot:** a small dot at the center, available with the "Outline with center dot" option.
- **Hardness:** a soft inner circle that shows the brush's edge softness. Shown only when the outline is visible.
- **Tilt direction:** a line from the center in the direction of tilt, shown when the brush is tilt-aware and tilt is reported.
- **Crosshair:** optional, off by default.
- **Hide while drawing:** the cursor hides while the stylus is in contact, if the user has chosen that option.
- **Slider feedback:** dragging the size or opacity slider shows a live stamp preview at the chosen value.
- **Setting:** the Brush cursor setting has three options (Outline with center dot, Outline only, Off). Default Off (decision D7). Tilt direction is a separate toggle.

## 10. Parameter ranges at a glance

| Group | Count of parameters | Notes |
|---|---|---|
| Stroke path | 4 | §4.1 |
| Stabilization | 3 | §4.2 |
| Taper | 8 per input type, two types | §4.3 |
| Shape | 13 | §5.1 |
| Grain | 8 | §5.2 |
| Rendering | 9 plus mode | §6.2 |
| Wet Mix | 5 | §6.3 |
| Color Dynamics | 5 | §7.1 |
| Dynamics | 4 | §7.2 |
| Stylus | 10 | §7.3 |
| Properties | 8 | §8.1 |

All percentage parameters are stored as 0–1 values.

## 11. Default brush library (P0)

Ship at least eleven categories with representative, originally designed brushes. Names are Artoperce's own. Do not copy third-party brush artwork, names, or settings.

| Category | Intended feel | Minimum count | Example names |
|---|---|---|---|
| Sketching | Pencil and graphite, hard and soft | 6 | Soft Pencil, Hard Graphite, Sketch 2B, Sketch HB, Light Lead, Dark Lead |
| Inking | Technical pen, brush pen, fine liner, studio pen | 6 | Studio Pen, Fine Liner, Brush Pen, Technical Pen, Ink Round, Ink Flat |
| Drawing | Fine marker, chalk, crayon | 5 | Fine Marker, Chalk Dust, Wax Crayon, Broad Marker, Soft Chalk |
| Painting | Round, flat, oil, gouache, watercolor | 8 | Round Brush, Flat Brush, Oil Flat, Gouache Body, Wash Soft, Dry Bristle, Plaster Dab, Glaze Round |
| Artistic | Textured paint tips and dabbing | 5 | Dab Texture, Stipple, Splatter, Rough Paint, Dry Dab |
| Calligraphy | Nib, flat tip, brush | 4 | Broad Nib, Flat Tip, Pointed Nib, Script Brush |
| Airbrushing | Soft, hard, medium, spray | 4 | Soft Airbrush, Hard Airbrush, Medium Spray, Fine Mist |
| Textures | Paper, grunge, halftone, noise | 6 | Paper Tooth, Grunge, Halftone Dots, Noise Fill, Rough Edge, Speckle |
| Charcoal and pastel | Stick, vine, soft pastel | 4 | Charcoal Stick, Vine Charcoal, Soft Pastel, Pastel Edge |
| Elements | Clouds, water, fire, stars | 4 | Cloud Puff, Water Splash, Ember, Star Scatter |
| Touch-up | Blenders, smudgers, erasers | 4 | Soft Blender, Smudge Finger, Hard Eraser, Soft Eraser |

**Default preset** (used when creating a new brush): Uniform Glaze, spacing 10%, pressure size from 0.2 to 1.0, taper start 0%, end 0%, Improved filtering, grain Paper with Moving mode and depth 50%, Normal blend, all other values at their defaults.

**Quality rule:** each built-in brush must render its preview and its sample stroke without any missing resources. Shape and grain assets are bundled with the app.

## 12. Brush and brush set files

### 12.1 `.brush` (brush preset)

- A ZIP package with: a JSON parameter file (`brush.json`), a preview image (`preview.png`), and shape and grain images under `resources/`.
- The JSON is versioned with `schema`. Unknown keys are preserved on load and written back on save.
- Files are data only. No executable code, scripts, or network references are permitted (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.4).
- Export produces a `.brush` file for a single preset.

### 12.2 `.brushset` (brush set)

- A ZIP package with set metadata (`set.json`), the ordered presets, and their resources.
- Import of a set creates a user set with the same name, suffixed if the name exists.

### 12.3 Import conflicts

- Importing a preset whose ID already exists opens a choice: **Replace**, **Keep both**, or **Cancel**.
- Import never silently overwrites.
- Keep both gives the imported brush a new ID and a name suffixed " (2)".

### 12.4 Legacy brushes (P2)

Legacy third-party brush files may be imported as an approximation. Unsupported features are listed in a report after import. Not part of 1.0.

## 13. Eraser, Smudge, and tool rules

| Tool | Brush selection | Rule |
|---|---|---|
| Paint | Any brush in the library | Uses the active color (see [06-color.md](06-color.md)). |
| Smudge | Any brush, with its own saved selection | Smudge strength comes from the brush's Smudge strength property (§8.1). Pulls pixels from the active layer only, unless "Sample all layers" is on. |
| Erase | Any brush, with its own saved selection | Removes alpha. On an alpha-locked layer, erases to transparent only after the user confirms the exception. Otherwise blocked with a one-line explanation. |
| Fill | Quick Fill or Fill layer. Does not use a brush. | See [04-canvas-and-input.md](04-canvas-and-input.md) §7. |

- **Use same brush for all tools:** off by default. When on, Paint, Smudge, and Erase share the paint brush selection.
- Smudge and Erase never change the active color.
- Sample all layers for Smudge is off by default.
