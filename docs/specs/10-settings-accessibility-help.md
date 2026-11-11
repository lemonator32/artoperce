# 10 — Settings, Assistive Alternatives, Accessibility, Localization, and Help

## 1. Settings catalog

Settings are stored per device and apply immediately, without a restart. The catalog is shown in the Preferences tab of the Actions panel and in the gallery's Settings screen. Options are listed with the default first.

Settings that depend on missing hardware (hover, barrel roll, tilt, squeeze) are hidden, or disabled with a note. They are never silently ignored.

### 1.1 Interface

| Setting | Options (default first) | Notes |
|---|---|---|
| Theme | Dark, Follow system, Light | Decision D8. |
| Left-handed layout | Off, On | On mirrors the side rail and the top bar's right group. |
| Side rail position | Left, Right | Follows Left-handed layout by default. |
| Show size and opacity sliders | On, Off | Hides the sliders in the rail. Their actions remain in the Quick menu. |
| Interface scale | 100%, 80%, 120%, 150% | Scales controls and text. |
| Brush cursor | Off, Outline with center dot, Outline only | Decision D7. Tilt direction is a separate toggle. |
| Advanced cursor settings | Enabled when Brush cursor is not Off | Center dot, hardness, tilt direction, crosshair. |
| Selection mask visibility | 25%, 0–100% | Decision D3. Also sets the overlay color (default accent). |
| Reduce motion | Follow system, Off, On | See [02-workspace.md](02-workspace.md) §8.7. |

### 1.2 Gestures

| Setting | Options (default first) | Notes |
|---|---|---|
| Draw with finger | On, Off | When Off, a single finger on the canvas navigates or triggers gestures only. |
| Touch gestures | Each gesture in [04-canvas-and-input.md](04-canvas-and-input.md) §4 individually enabled | All on by default. |
| Rapid undo delay | 0.65 s, range 0.1–1.0 s | Decision D2. |
| Eyedropper delay | 0.4 s, range 0.1–1.5 s | |
| Shape Snap delay | 0.5 s, range 0.2–1.5 s | |
| Palm rejection window | 150 ms, range 0–500 ms | |
| Quick menu content | Per tool, up to 6 actions | Defaults in [04-canvas-and-input.md](04-canvas-and-input.md) §9. |
| Gesture and shortcut configuration | Link to the mapping screen | See §2. |

### 1.3 Stylus

| Setting | Options (default first) | Notes |
|---|---|---|
| Barrel tap | Toggle eraser; Eyedropper; Quick menu; Swap colors; Previous tool; None | Hidden without hardware support. |
| Barrel squeeze | Toggle eraser; Eyedropper; Quick menu; Swap colors; Previous tool; None | Hidden without hardware support. |
| Barrel double tap | Previous brush; Toggle eraser; Quick menu; None | Hidden without hardware support. |
| Pressure curve | Normal, Soft, Firm, Custom | Custom opens the curve editor with the test pad. |
| Smoothing | 0%, range 0–100% | Applied before brush stabilization. |
| Prediction | On, Off | Affects the preview only. |
| Calibration | Link | Opens the calibration screen (see [04-canvas-and-input.md](04-canvas-and-input.md) §5.3). |

### 1.4 Canvas

| Setting | Options (default first) | Notes |
|---|---|---|
| Pinch to rotate | On, Off | |
| Snap rotation to 0° | On, Off | See [04-canvas-and-input.md](04-canvas-and-input.md) §1.2. |
| Canvas edge shadow | On, Off | Shows the artwork's boundary shadow. |
| Brush scaling | Canvas, Screen | Decision D13. See [04-canvas-and-input.md](04-canvas-and-input.md) §1.5. |
| Default guide appearance | Light cyan, 1 pt, 50% | Color, thickness, and opacity for new guides. See [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §3.2. |
| Project canvas to external display | Off, On | P2. |

### 1.5 Drawing

| Setting | Options (default first) | Notes |
|---|---|---|
| Time-lapse recording default | On, Off | New documents only. See [09-import-export-timelapse.md](09-import-export-timelapse.md) §5.1. |
| Auto-fill on Shape Snap | Off, On | See [04-canvas-and-input.md](04-canvas-and-input.md) §6.5. |
| Brush size and opacity link | Independent, Linked | See [02-workspace.md](02-workspace.md) §2.3. |

### 1.6 Files and gallery

| Setting | Options (default first) | Notes |
|---|---|---|
| Default export format and quality | PNG, JPEG 90 | See [09-import-export-timelapse.md](09-import-export-timelapse.md) §3. |
| Strip metadata on export | On, Off | Privacy default. |
| Gallery sorting | Last modified, Name, Creation date, Custom | See [03-gallery-and-documents.md](03-gallery-and-documents.md) §1.3. |
| Trash retention | 30 days; 7, 14, 90 days; or never | See [03-gallery-and-documents.md](03-gallery-and-documents.md) §4. |
| Store brush sets in the user's cloud account | Off, On | P2. Hidden in 1.0. |

### 1.7 Advanced

| Setting | Options (default first) | Notes |
|---|---|---|
| Hardware acceleration | On, Off | Off is for troubleshooting. |
| Memory budget | Automatic, Conservative | Conservative uses 25% of available RAM with a 3 GB cap. See [03-gallery-and-documents.md](03-gallery-and-documents.md) §6.1. |
| Import size limit | 500 MB | Configurable. See [09-import-export-timelapse.md](09-import-export-timelapse.md) §1. |
| Import dimension limit | 16,384 px | Configurable. |
| Reset gestures and shortcuts | Command | Confirmation required. |
| Reset all settings | Command | Confirmation required. |

### 1.8 Privacy and diagnostics

| Setting | Options (default first) | Notes |
|---|---|---|
| Crash reports | Ask, Always send, Never send | Sends only with the user's consent. Contains no artwork, titles, or file paths (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.5). |
| Usage analytics | Off, On | Off by default. Aggregate only. No artwork content. Always disable-able. |

## 2. Gesture and shortcut configuration

- Every touch gesture in [04-canvas-and-input.md](04-canvas-and-input.md) §4 can be enabled, disabled, or remapped to another command in the command catalog.
- Every keyboard shortcut in [04-canvas-and-input.md](04-canvas-and-input.md) §8 can be remapped.
- Stylus actions (§1.3) and quick-menu contents (§1.2) are assigned on the same screen.
- **Conflicts:** an assignment that duplicates another action is refused. The message names the conflicting action and offers to reassign it.
- **Search:** the mapping screen has a search field. A cheat sheet view lists every shortcut and gesture.
- **Reset:** Reset gestures and shortcuts restores defaults. It does not change other settings.
- Every multi-finger gesture has an assistive alternative, which cannot be disabled (see §3).

## 3. Assistive alternatives

Every multi-finger gesture has a single-pointer path.

| Gesture | Alternative |
|---|---|
| Two-finger tap (undo) | Undo button in the rail; keyboard shortcut; switch control |
| Three-finger tap (redo) | Redo button in the rail; keyboard shortcut; switch control |
| Pinch and rotate | Zoom and rotate controls in the View menu; numeric zoom entry; rotate in 15° steps |
| Touch and hold (eyedropper) | Eyedropper button that arms for the next tap |
| Quick Fill drag | Fill command in the layer menu, using the primary color |
| Pinch merge (layer rows) | Merge down command |
| Shape Snap hold | Snap shape button that converts the last stroke |
| Three-finger swipe down (Cut / Copy / Paste menu) | Edit group in the Actions panel |
| Four-finger tap (hide interface) | Hide interface command and Tab key |
| Draw with finger off | Stylus or Pointer mode; no finger dependency |

**Additional assistive features:**

- **Dwell:** hold the pointer still for N ms to act in place of a tap. N is configurable from 300 to 2000 ms; default off.
- **Sticky modifier:** a modifier key acts for the next gesture only.
- **One-handed mode:** moves the side rail to a reachable edge and enlarges the rail controls.
- **Switch control:** all controls reachable with switch scanning, in logical order.
- **Accessible tool selection:** tool buttons announce their state.

## 4. Accessibility requirements

### 4.1 Screen readers

- All non-canvas controls have labels, values, and roles.
- Screen-reader users can navigate the gallery, layer panel, settings, and menus.
- Screen-reader users can open, rename, duplicate, and export documents entirely with assistive technology.
- The canvas exposes an accessible description of the current tool, active layer, zoom level, and selection, and announces changes.
- Sliders announce their current numeric value and adjustment increment.
- Icon-only controls have text labels for the accessibility tree.

### 4.2 Visual

- **Contrast:** text meets WCAG 2.2 level AA (4.5:1 for body text, 3:1 for UI components and icons) in both themes.
- **Not color alone:** active tools, selected rows, selected swatches, and dimmed states also use icon, shape, text, or position.
- **Text scaling:** the interface remains usable at 150% text size. Layouts reflow instead of clipping.
- **Bold text and high contrast:** respected when the system requests them.
- **Color filters:** respected. Canvas colors are not altered by the app's filters.

### 4.3 Motion and timing

- **Reduce motion:** respected by default. See [02-workspace.md](02-workspace.md) §8.7.
- **Timing thresholds:** every timing-based gesture has an adjustable threshold (§1.2).
- **Duration limit:** no function requires a gesture or hold lasting longer than 3 seconds.

### 4.4 Targets and input

- Touch targets are at least 44 × 44 pt.
- Every gesture has an alternative (§3).
- Keyboard focus is visible with the focus ring token.

### 4.5 Scope

- WCAG 2.2 AA applies to all non-canvas interface elements.
- The canvas itself is described through §4.1 rather than by visual conformance.
- Accessibility audit runs for every release candidate (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §3).

## 5. Help and onboarding

### 5.1 First launch

- A skippable tour of the workspace with at most six steps.
- The tour can be replayed from the Help tab.

### 5.2 Help tab

The Help tab in the Actions panel and on the gallery provides:

- A gesture guide: an illustrated list of every gesture and its alternative.
- A searchable keyboard cheat sheet.
- Short how-to articles for common tasks: creating a canvas, painting, creating a brush, using layers, exporting.
- A feedback form.
- A diagnostic report export. The report contains no artwork, titles, or file paths.

### 5.3 Empty states

Empty states in the gallery, brush library, palettes, and layers show a primary action and a one-line explanation.

### 5.4 Destructive commands

Every destructive command states what is affected and how to undo it. For example: "Deletes 3 layers. You can undo this with Undo."

## 6. Localization and internationalization

- All user-facing strings are externalized. Strings support plural rules and gender where the language needs them.
- Layouts tolerate text expansion of up to 40%.
- **Right-to-left languages:** the interface mirrors. The canvas, brush direction, and curve graphs do not mirror.
- Dates, numbers, and units (inches, millimeters, centimeters, pixels) follow the user's locale.
- **Initial languages (P1):** English, Spanish, French, German, Portuguese, Japanese, Korean, Simplified Chinese, and Traditional Chinese. English is required for 1.0. Others follow the product team's process.
- Text layers and text fields accept input methods for all supported languages.

## 7. Settings behavior

- A search field finds any setting by name.
- Each changed setting shows a Reset affordance that returns it to its default.
- Settings that change drawing feel (pressure curve, smoothing, palm rejection) include a built-in test pad. Users can try the change before leaving the screen.
- Settings are per device and apply immediately.
- Settings that depend on missing hardware are hidden or disabled with a note (§1).
- Settings export and import as one file is P2.
