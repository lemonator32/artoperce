# 12 — Data Format, Storage, Journal, Undo, and Engine Contracts

These contracts are normative for the native format and for the engine interfaces. Field names in this file are fixed. Internal class names may differ.

## 1. Native project package

### 1.1 Layout

A document is a package with the extension **`.artoperce`** (decision D1). On the device it is a directory. For export and sharing it is a ZIP archive with the same structure.

```
<title>.artoperce/
  manifest.json                 format version, document properties, layer tree, integrity hashes
  layers/
    <layerId>/
      tiles/<x>_<y>.tile        256 × 256 px tiles (see §3)
      mask/<x>_<y>.tile         optional 8-bit mask tiles
  selections/<id>.mask          saved selection masks (P1)
  brushes/<presetId>.brush      only presets used by this document
  resources/                    shape and grain images; reference image if kept
  guides/guides.json            guide definitions (never exported)
  history/journal.log           append-only operation journal (see §4)
  timelapse/                    event log and keyframes (see §10)
  thumbnail.png                 cached preview, reproducible from the document
```

- The directory form is used on device for fast incremental saves.
- The ZIP form is used for export and sharing. It is read-only until it is unpacked into the directory form.
- Readers ignore unknown files and unknown manifest keys, and preserve them when saving.

### 1.2 Path and archive safety

- On import or unpack, reject entries whose paths contain `..`, are absolute, or resolve outside the package directory.
- Cap total uncompressed size and file count (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §4.4).
- Never extract outside the package sandbox.

## 2. Manifest

### 2.1 Example

```json
{
  "format": "artoperce",
  "formatVersion": "1.0.0",
  "minReaderVersion": "1.0.0",
  "id": "b1c7e1d0-5d5a-4a0f-9f0c-2f1f7b8d9a10",
  "title": "Harbor study",
  "description": "",
  "createdAt": "2026-11-07T14:30:00Z",
  "modifiedAt": "2026-11-07T16:05:12Z",
  "canvas": {
    "width": 4096,
    "height": 3072,
    "dpi": 300,
    "bitDepth": 8,
    "colorProfile": "srgb",
    "background": { "visible": true, "color": "#FFFFFF" }
  },
  "layerTree": [
    { "id": "BG", "type": "background", "name": "Background", "visible": true,
      "opacity": 1.0, "blend": "normal", "locks": { "alpha": false, "all": false },
      "clip": false, "maskId": null, "assist": false, "reference": false },
    { "id": "L1", "type": "raster", "name": "Sketch", "visible": true,
      "opacity": 0.8, "blend": "multiply", "locks": { "alpha": false, "all": false },
      "clip": false, "maskId": null, "assist": false, "reference": false },
    { "id": "G1", "type": "group", "name": "Characters", "visible": true,
      "opacity": 1.0, "blend": "normal", "isolated": true, "children": [] }
  ],
  "viewport": { "zoom": 0.5, "rotation": 0, "panX": 0, "panY": 0 },
  "stats": { "strokeCount": 1842, "activeSeconds": 7260 },
  "exports": [ { "date": "2026-11-07T15:00:00Z", "format": "png" } ],
  "integrity": { "algorithm": "sha256", "files": { "layers/L1/tiles/0_0.tile": "..." } }
}
```

### 2.2 Field rules

| Field | Type | Rules |
|---|---|---|
| `format` | String | Always `artoperce`. |
| `formatVersion` | Semver string | See §7. |
| `minReaderVersion` | Semver string | Readers older than this refuse to open. |
| `id` | UUID | Stable for the document's life. Duplicates get a new ID. |
| `title` | String | 1–120 characters. |
| `description` | String | Up to 2000 characters. |
| `createdAt`, `modifiedAt` | ISO 8601 UTC | |
| `canvas.width`, `canvas.height` | Integer | 1–16,384, subject to the layer-capacity formula. |
| `canvas.dpi` | Number | 1–2400. |
| `canvas.bitDepth` | 8 (16 in P2) | |
| `canvas.colorProfile` | `srgb`, `displayp3` (P1), or other registered profile | Unknown profiles are preserved and flagged. |
| `canvas.background` | Object | Visibility and color. The color is kept while hidden. |
| `layerTree` | Array | Layer nodes in stacking order, bottom to top. |
| `layer.id` | String | Unique within the document. |
| `layer.type` | `background`, `raster`, `group`, `reference`, `text` (P1), `frame` (P1) | Unknown types are preserved and not rendered. |
| `layer.blend` | Blend mode identifier | See [07-layers-and-selection.md](07-layers-and-selection.md) §3.2. |
| `layer.opacity` | 0–1 | |
| `guides` | Object or referenced file | Stored in `guides/guides.json`. |
| `viewport` | Object | Last viewport. Restored on open. |
| `stats` | Object | Updated incrementally. |
| `exports` | Array | Last export date and format are shown in canvas information. |
| `integrity` | Object | Checksums for large payloads. |

### 2.3 Layer node fields

Every layer node has these fields: `id`, `type`, `name`, `visible`, `opacity`, `blend`, `locks`, `clip`, `maskId`, `assist`, `reference`. Groups add `isolated` and `children`. Text layers add the text model (P1). Frame nodes add `holdTicks` (P1).

## 3. Tile storage

- Tile size is **256 × 256 px**.
- Pixel format per tile: premultiplied RGBA, 8-bit per channel in 1.0 (16-bit in P2). Mask tiles are 8-bit single channel.
- Fully transparent tiles are not written. A missing tile means transparent.
- Tiles are compressed with a lossless codec (zstd or LZ4). Each tile has a header with: codec, uncompressed size, and a checksum (CRC-32C or SHA-256).
- A tile write is atomic: write to a temporary name, flush, then rename into place.
- Only tiles touched by an operation are rewritten.
- The manifest is rewritten with an atomic replace after tile writes succeed.

## 4. Operation journal and recovery

### 4.1 Journal

- The journal (`history/journal.log`) is an append-only sequence of records, one per committed operation.
- Each record is written **before** the tiles it describes are considered committed.
- Each record has a monotonically increasing `seq`.

Example stroke record:

```json
{ "seq": 4122, "t": "2026-11-07T16:05:12.431Z", "op": "stroke",
  "layerId": "L1", "brushId": "p-0042", "brushVersion": 3, "seed": 918273645,
  "color": "#2B4C7E", "blend": "normal",
  "samples": [ [x, y, pressure, tiltX, tiltY, tMs] ],
  "dirtyTiles": [ "3_2", "4_2" ], "committed": true }
```

### 4.2 Commit order

1. Write the journal record with `committed: false`.
2. Write the changed tiles to temporary names, flush, and rename.
3. Rewrite the journal record as `committed: true` (append a commit marker that references `seq`).
4. Rewrite the manifest atomically with the new `lastCommittedSeq`.

### 4.3 Recovery on start

- On start, if the journal holds records beyond the manifest's `lastCommittedSeq`:
  - Records with `committed: true` are replayed, or their tiles are restored from the pre-image checkpoint.
  - Records with `committed: false` are discarded.
- The user is offered recovery, with a notice that names the restored state (for example, "Restored to the last completed stroke").
- If recovery fails, the app opens the last valid state and reports `E_JOURNAL_REPLAY_FAILED` with the document name. The original package is kept.

### 4.4 Cleanup

- Autosave and recovery journals are removed after a successful save, or after 7 days.
- Checkpoints for destructive operations are removed after a successful save or after 7 days (see [03-gallery-and-documents.md](03-gallery-and-documents.md) §8.4).

### 4.5 Durability target

Killing the process at random points during stroke commits leaves the project loadable every time. At most the in-progress stroke is lost (see [13-quality-and-acceptance.md](13-quality-and-acceptance.md) §5.4).

## 5. Operations and the undo contract

### 5.1 Command interface

Every undoable operation implements:

| Member | Contract |
|---|---|
| `apply()` | Performs the operation. Idempotent for the same inputs. |
| `revert()` | Restores the exact prior state, including selection and active layer. |
| `memoryCost()` | Estimated bytes held. Used by the history budget. |
| `merge(next)` | Optionally merges with the next command (for example, consecutive slider changes). |
| `serialize()` | Stable form for the journal and the time-lapse log. |

### 5.2 Undo units

| Operation | Undo steps |
|---|---|
| Stroke (paint, erase, smudge) | 1 |
| Quick Fill drop | 1 |
| Shape Snap | 2: the snap reverts to the freehand stroke, then the stroke is removed |
| Adjustment Apply | 1 |
| Liquify commit | 1 |
| Transform commit | 1 |
| Layer add, delete, duplicate, reorder, merge, group | 1 each |
| Layer property change (opacity, blend, visibility, lock) | 1 each; consecutive slider changes merge |
| Mask add, apply, disable, invert, delete | 1 each |
| Selection change (create, refine, deselect) | 1 each |
| Canvas crop, resample, resize, flip, rotate, flatten | 1 each; checkpoint written first |
| Color profile assign or convert | 1 each; checkpoint written first |
| Frame add, delete, reorder, hold change (P1) | 1 each |
| Reference image load | Not undoable (not document content) |
| View changes (zoom, pan, rotate, flip view) | Not undoable |

### 5.3 Pixel commands and before-images

- Pixel-changing commands store the **before-image of only the dirty tiles**.
- A stroke's stored data is its samples, seed, and brush snapshot. The before-image is the dirty tiles before the stroke.

### 5.4 History budget

- The history stack has a memory budget of 25% of the canvas memory budget.
- The minimum depth on the reference device is 100 steps.
- When the budget is exceeded, the oldest steps are dropped. The user is told once that the history limit was reached.
- After a save and reload, undo history from the same session is retained for the document's latest 20 steps (P1).
- The history clears only when the document closes or when resource limits require it. It does not clear during ordinary panel navigation.

### 5.5 Undo and redo rules

- Undo and redo are immediate and exact. Property tests verify that undo then redo restores state exactly.
- Undo covers strokes, fills, adjustments, transforms, layer changes, selections, and canvas operations.
- View changes are not undoable.

## 6. Brush preset schema

### 6.1 Preset

A brush preset is a JSON object with the following top-level keys. Each key corresponds to a parameter group in [05-brushes.md](05-brushes.md). Parameter values are normalized to 0–1 unless the group says otherwise.

| Key | Group in [05-brushes.md](05-brushes.md) |
|---|---|
| `id` | Identity |
| `schema` | Schema version (integer, starts at 1) |
| `name`, `category`, `author`, `description` | About |
| `version` | Incremented on each Apply |
| `path` | Stroke path (§4.1) |
| `stabilization` | Stabilization (§4.2) |
| `taper` | Taper (§4.3) |
| `shape` | Shape (§5.1) |
| `grain` | Grain (§5.2). `null` when no grain is used. |
| `render` | Rendering (§6.1, §6.2) |
| `wetMix` | Wet Mix (§6.3) |
| `colorDynamics` | Color Dynamics (§7.1) |
| `dynamics` | Dynamics (§7.2) |
| `stylus` | Stylus (§7.3) |
| `properties` | Properties (§8.1) |
| `resetPoints` | Reset points (§8.4) |

### 6.2 Example (excerpt)

```json
{
  "id": "p-0042", "schema": 1, "name": "Studio Pen", "category": "Inking",
  "author": "Artoperce", "version": 3,
  "path": { "spacing": 0.08, "jitter": 0.0, "falloff": 0.0, "streamline": 0.35 },
  "stabilization": { "amount": 0.2, "motionFilter": 0.1, "expression": 0.0 },
  "taper": { "start": 0.1, "end": 0.25, "tipSize": 0.5 },
  "shape": { "source": "resources/round-hard.png", "rotation": 0, "scatter": 0, "count": 1,
             "filtering": "improved" },
  "grain": null,
  "render": { "mode": "uniform_glaze", "flow": 1.0 },
  "stylus": { "pressureSize": [[0, 0.2], [1, 1]], "pressureOpacity": [[0, 1], [1, 1]], "tiltSize": null },
  "properties": { "minSize": 0.01, "maxSize": 1.0, "minOpacity": 0, "maxOpacity": 1 }
}
```

### 6.3 Curves

- Curves are lists of `[input, output]` points in [0, 1], monotone-interpolated.
- Points are sorted by input.
- A loader rejects values outside documented ranges and clamps tolerated ones, reporting each change.

### 6.4 Resets

- `resetPoints` is an array of `{ "date": ISO 8601, "note": string, "snapshot": preset-without-resetPoints }`.
- Built-in brushes have an implicit first reset point: the built-in definition.

### 6.5 Limits

- Shape and grain sources are limited to 4096 × 4096 px, mipmapped.
- Unknown keys are preserved on load and written back.

## 7. Versioning and migration

- The manifest has `formatVersion` (semantic version) and `minReaderVersion`.
- A reader older than `minReaderVersion` refuses to open the document and tells the user to update. It never opens read-write.
- A **minor** version adds optional fields only.
- A **major** version may change structure. It ships a migration that runs on a copy. The original is kept until the migrated copy validates.
- Every shipped format version has a fixture document in the test suite that must open and round-trip.
- A project saved by version N opens in version N+1 and is migrated on a copy. An older reader refuses a newer major version without altering it.
- Brush presets use `schema`, with the same rules.

## 8. Compositing and rendering pipeline

### 8.1 Live stroke

1. **Input:** stylus or touch samples. Coalesced to the display refresh rate.
2. **Stabilizer:** exponential or streamline smoothing per the brush's stabilization values.
3. **Guide constraint:** if assistance is active (see [08-adjustments-guides-reference.md](08-adjustments-guides-reference.md) §3.4).
4. **Resampling:** walk the smoothed path at `spacing` × stamp width, interpolating pressure and tilt.
5. **Dynamics:** compute per-sample size, opacity, flow, rotation, and roundness. Apply taper at the first and last parts of the stroke.
6. **Stamping:** render the stamp texture at each sample with its transform. Apply grain.
7. **Rendering mode:** Glaze accumulates alpha and color with flow. Blending mixes with the color below.
8. **Edge effects:** wet and burnt edges as post-process on the stroke mask.
9. **Live preview:** draw the stroke buffer at display resolution. Prediction is applied only to this preview.
10. **Commit on pen-up:** composite the stroke buffer into the layer with the brush blend mode and opacity. Journal the stroke.

### 8.2 Display compositing

- Visible layers are composited in tree order using each layer's opacity, blend mode, mask, clipping, and group isolation.
- Composites are cached per tile. A change invalidates only the tiles it touches.
- Thumbnails are regenerated in the background after a save that changed pixels.

### 8.3 Performance

- Input capture never waits on rendering or disk.
- Rendering the in-progress stroke has priority over background work.

## 9. Error model

### 9.1 Typed errors

Operations that can fail return a typed error with:

- A stable **code**.
- A user-facing **message key** (localized).
- A **recovery hint**.
- A statement of whether the document is safe.

User-facing messages are localized. Raw codes are never shown alone.

### 9.2 Codes

| Code | Meaning | Recovery hint |
|---|---|---|
| `E_DISK_FULL` | Not enough free space to write. | Offer to free space. |
| `E_LAYER_LIMIT` | Layer capacity reached. | Offer to flatten selected layers, or reduce canvas size. |
| `E_UNSUPPORTED_FEATURE` | A feature cannot be represented in the target format. | List the dropped features. |
| `E_CORRUPT_TILE` | A tile fails its checksum. | Restore the tile from the journal or pre-image. |
| `E_IMPORT_TOO_LARGE` | File exceeds the size or dimension limit. | Show the limits. |
| `E_IMPORT_MALFORMED` | File cannot be parsed. | Reject the file and explain. |
| `E_VERSION_TOO_NEW` | Document's `minReaderVersion` is newer than this app. | Ask the user to update. Never open read-write. |
| `E_JOURNAL_REPLAY_FAILED` | Journal replay failed during recovery. | Open the last valid state and keep the package. |
| `E_EXPORT_FAILED` | Export could not complete. | Keep the source unchanged. Offer retry. |
| `E_PERMISSION_DENIED` | Photo, file, or camera permission refused. | Explain the reason and offer settings. |
| `E_PACKAGE_UNSAFE` | Archive contains path traversal or an oversize entry. | Reject the package. |
| `E_FONT_MISSING` | A project font is not installed. | Use a fallback and keep the original name. Warning only. |
| `E_LOCKED_LAYER` | Command blocked by a layer lock. | State the lock and how to unlock it. |

### 9.3 Safety statement

Every error message states whether the document is safe. For example: "Your artwork is saved. Free space and try again."

## 10. Time-lapse event log

### 10.1 Events

Events are stored as compact records in `timelapse/events.log`. Each event has `seq`, `t` (relative milliseconds), `op`, and the operation's serialized payload (the same serialization as §5.1).

Captured event types: stroke (with seed and brush snapshot), fill, transform commit, adjustment commit, layer change, selection change, canvas view change, undo, and redo. Canvas resample, crop, flip, rotate, and flatten add a keyframe.

### 10.2 Keyframes

- Written every 60 seconds or every 200 operations, whichever comes first.
- Keyframes hold a compressed snapshot of the document's visible state, so replay can start from any keyframe.
- Keyframes are stored in `timelapse/keyframes/`.

### 10.3 Overhead and limits

- Recording must cost under 3% of frame time on the reference device.
- A recording above 500 MB triggers a warning with the option to compact or stop.
- Data is never deleted without the user's consent.
