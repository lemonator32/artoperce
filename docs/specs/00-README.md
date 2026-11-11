# Artoperce — Product and Engineering Specification

Artoperce is a touch-first, stylus-first raster drawing and painting application for tablets, with optional desktop support. It is built around a canvas-centered workspace, a configurable stamp-based brush engine with a live brush editor, layered compositing, reversible editing tools, and a crash-safe native project format.

This specification set is complete enough to build the full application. A developer should not need any other document. Where a behavior is not stated, the default is the most conservative option consistent with the principles in [01-overview.md](01-overview.md).

## Reading order

| File | Contents |
|---|---|
| [00-README.md](00-README.md) | This index, conventions, glossary, and resolved decisions |
| [01-overview.md](01-overview.md) | Product purpose, principles, platform targets, system architecture, delivery phases |
| [02-workspace.md](02-workspace.md) | Screens, navigation, canvas top bar, left rail, panels, tool state, visual design tokens |
| [03-gallery-and-documents.md](03-gallery-and-documents.md) | Gallery, selection mode, stacks, trash, new-canvas flow, canvas setup, canvas transforms, canvas information |
| [04-canvas-and-input.md](04-canvas-and-input.md) | Viewport, input sources, gesture arbitration, gesture map, stylus, keyboard, quick menu, Shape Snap, Quick Fill, eyedropper |
| [05-brushes.md](05-brushes.md) | Brush library, Brush Editor (all attribute groups), parameter reference, stamp pipeline, default library, brush files, brush cursor |
| [06-color.md](06-color.md) | Color panel modes, value entry, harmony rules, palettes, recent colors, color management |
| [07-layers-and-selection.md](07-layers-and-selection.md) | Layer model, layer panel and menu, compositing and blend catalog, masks, alpha lock, clipping, recolor, selection, transform |
| [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) | Adjustment framework, effect catalog, Liquify, Clone, Drawing Guides, assisted drawing, snapping, reference window |
| [09-import-export-timelapse.md](09-import-export-timelapse.md) | Format matrix, import rules by entry point, export options and workflow, system integration, time-lapse recording and replay, sharing |
| [10-settings-accessibility-help.md](10-settings-accessibility-help.md) | Settings catalog and defaults, assistive alternatives, accessibility, localization, help and onboarding |
| [11-extensions.md](11-extensions.md) | Post-1.0 and optional features: frame animation, text, shapes, gradients, 3D painting, CMYK, 16-bit |
| [12-data-and-engine.md](12-data-and-engine.md) | Native project package, manifest, tile storage, operation journal, recovery, undo contract, file schemas, versioning, error model, rendering pipeline |
| [13-quality-and-acceptance.md](13-quality-and-acceptance.md) | Performance budgets, reliability, security, privacy, test strategy, phased delivery plan, acceptance criteria |

## Conventions

- **Requirement keywords.** "Must" is mandatory. "Should" is expected unless there is a documented reason not to. "May" is optional.
- **Priority.** Every feature is tagged:
  - **P0** — required for the 1.0 release.
  - **P1** — ships in 1.0 if schedule allows; otherwise the first post-1.0 release.
  - **P2** — later release.
- **Numbers.** Ranges and defaults are starting values to be tuned during testing. Where a value is stated as a default, implement that default.
- **Percentages.** Normalized parameters are stored as 0–1 in files and displayed as 0–100% in the UI. "None" means 0 and "Max" means 1 unless stated.
- **Coordinates.** Document pixels are the source of truth. Screen points are converted to document pixels before anything is stored. "pt" means density-independent points; "px" means document pixels.
- **Names.** The product is named **Artoperce** everywhere, including file names, metadata, and UI. Feature names in this set are Artoperce's own and are intended to be used verbatim in the UI.
- **Terminology.** "Stylus" means a pressure-sensitive pen. "Finger" means direct touch. "Pointer" means any input source.

## Glossary

| Term | Definition |
|---|---|
| Artwork / document | A project containing a canvas, a layer tree, guides, and history. Stored as an `.artoperce` package. |
| Canvas | The document's pixel surface, with fixed width, height, DPI, color profile, and background. |
| Viewport | The on-screen view of the canvas, including pan, zoom, and rotation. |
| Layer | An independently editable raster surface, group, text layer, or reference layer in the layer tree. |
| Stamp | One application of a brush shape at one point along a stroke path. |
| Stroke | A sequence of pointer samples committed as one undoable paint operation. |
| Brush preset | A named, versioned set of brush parameters stored in a `.brush` file. |
| Brush Editor | The full-screen editor for brush parameters, with a live Drawing Pad. |
| Drawing Pad | The live test surface inside the Brush Editor. It never touches the artwork. |
| Glaze | A rendering mode in which overlapping stamps accumulate transparency and underlying color shows through. |
| Blending | A rendering mode in which a stroke mixes with the color beneath it. |
| Assisted drawing | Constraining strokes to a Drawing Guide's geometry. |
| Shape Snap | Replacing a freehand stroke with the best-fitting geometric primitive after a hold. |
| Quick Fill | A bucket-style fill of the region under a drop point. |
| Selection | An 8-bit mask over the canvas that limits where edits apply. |
| Time-lapse | A replayable event log of the creation process, stored inside the document. |

## Resolved decisions

Where the source material disagreed, the following decisions are binding. Precedence: reference behavior first, then numeric defaults, then prose.

| # | Topic | Decision |
|---|---|---|
| D1 | Native project extension | `.artoperce` (a directory or ZIP package). Replaces the earlier `.drawing` and `.dapp` names. |
| D2 | Rapid undo delay default | 0.65 s (reference behavior). Range 0.1–1.0 s. |
| D3 | Selection mask visibility default | 25% (reference behavior). Range 0–100%. |
| D4 | Glaze/blend rendering modes | Six modes: Light Glaze, Uniform Glaze, Intense Glaze, Heavy Glaze, Uniform Blending, Intense Blending. Default is Uniform Glaze. |
| D5 | Three-finger swipe down | Opens the Cut / Copy / Paste menu (P1). Three-finger swipe is not used for copy or paste directly. |
| D6 | Halftone styles | Full Color, Screen Print, Newspaper. Dot size is a percentage (default 22%). |
| D7 | Brush cursor default | Off. Options: Outline with center dot, Outline only, Off. |
| D8 | Interface theme default | Dark. Options: Follow system, Dark, Light. |
| D9 | Brush and palette files | `.brush`, `.brushset`, `.swatches`. |
| D10 | Brush library categories | The eleven categories in [05-brushes.md](05-brushes.md) §11. All brush, palette, and category names are Artoperce's own. |
| D11 | Brush Editor name | "Brush Editor" everywhere in the UI and documentation. |
| D12 | Preferences location | Preferences are reached from the Actions panel's Preferences tab and are the same settings catalog defined in [10-settings-accessibility-help.md](10-settings-accessibility-help.md). |
| D13 | Brush scaling default | Canvas (brush size scales with canvas zoom). Options: Canvas, Screen. |
| D14 | Native document layout | Directory package with `manifest.json`, `layers/`, `history/journal.log`, and `thumbnail.png`. See [12-data-and-engine.md](12-data-and-engine.md). |
| D15 | Time-lapse in shared projects | Sharing a native project asks "Include time-lapse", default off, each time. The Supplemental spec's open question recommends explicit choice; the earlier text said sharing includes it. See [09-import-export-timelapse.md](09-import-export-timelapse.md) §6.2. |
| D16 | Drawing guides in exports | Never exported. Guides are project data only. |

## Scope summary

**In 1.0 (P0):** gallery and document lifecycle; new canvas with presets; stylus and touch painting with pressure and tilt; brush library and Brush Editor with the full parameter set; color panel with the Disc, Classic, Value, and Palettes modes; layers with blend modes, alpha lock, clipping, masks, and groups; selection and transform; Adjustments with Color Balance, Hue/Saturation/Brightness, Curves, Halftone, Gaussian Blur, Sharpen, and Noise; Drawing Guides with 2D Grid, Isometric, Perspective, and Symmetry; reference window; undo and redo; autosave and recovery; PNG, JPEG, TIFF, and native export; image import; time-lapse recording and replay; settings; accessibility basics.

**After 1.0 or optional (P1/P2):** harmony mode, palette capture, Shape Snap, Quick Fill, text, shapes, gradients, frame animation, PSD and PDF, 3D painting, CMYK and 16-bit, tiled canvas preview, rulers, the full adjustment catalog beyond the P0 set. Each is tagged where it is defined.
