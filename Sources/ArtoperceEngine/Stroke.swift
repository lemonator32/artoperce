import Foundation

/// Brush parameters for the stamp engine. Lengths are document pixels.
public struct BrushSettings: Equatable, Sendable {
    public var diameter: Double
    public var opacity: Double
    public var hardness: Double
    /// Distance between stamps as a fraction of the diameter.
    public var spacing: Double
    /// Non-premultiplied RGB, 0...1.
    public var red: Double
    public var green: Double
    public var blue: Double
    public var isEraser: Bool

    public init(
        diameter: Double = 24,
        opacity: Double = 1,
        hardness: Double = 0.8,
        spacing: Double = 0.12,
        red: Double = 0,
        green: Double = 0,
        blue: Double = 0,
        isEraser: Bool = false
    ) {
        self.diameter = diameter
        self.opacity = opacity
        self.hardness = hardness
        self.spacing = spacing
        self.red = red
        self.green = green
        self.blue = blue
        self.isEraser = isEraser
    }
}

/// One input sample in document pixels. Pressure is 0...1.
public struct StrokeSample: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var pressure: Double

    public init(x: Double, y: Double, pressure: Double) {
        self.x = x
        self.y = y
        self.pressure = pressure
    }
}

/// Records one stroke on one layer. Paint accumulates in a stroke buffer and is
/// merged on `finish()`. Erase modifies the layer directly so the result is visible
/// while drawing. Either way `finish()` yields a single undoable `TileChange`.
public final class StrokeSession {
    public let layerID: UUID
    public let settings: BrushSettings

    private weak var document: ArtDocument?
    /// Premultiplied buffer of paint, where alpha is the strongest stamp coverage.
    public private(set) var buffer: [TileKey: Tile] = [:]
    /// Original state of every tile this stroke touched, captured on first touch.
    private var before: [TileKey: Tile?] = [:]
    private var previous: StrokeSample?
    /// Distance from the last sample to the next stamp, in pixels.
    private var distanceToNextStamp: Double = 0

    public init(document: ArtDocument, layerID: UUID, settings: BrushSettings) {
        self.document = document
        self.layerID = layerID
        self.settings = settings
    }

    /// Adds a sample and stamps along the path from the previous one.
    /// Returns the tiles whose pixels changed (for redraw).
    @discardableResult
    public func add(_ sample: StrokeSample) -> Set<TileKey> {
        guard let document, let layer = document.layer(id: layerID) else { return [] }
        var dirty = Set<TileKey>()
        let spacing = max(1, settings.diameter * settings.spacing)

        guard let start = previous else {
            previous = sample
            distanceToNextStamp = 0
            dirty.formUnion(stamp(at: sample, on: layer, document: document))
            return dirty
        }

        let dx = sample.x - start.x
        let dy = sample.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        if length > 0 {
            var along = distanceToNextStamp
            while along <= length {
                let t = along / length
                let point = StrokeSample(
                    x: start.x + dx * t,
                    y: start.y + dy * t,
                    pressure: start.pressure + (sample.pressure - start.pressure) * t
                )
                dirty.formUnion(stamp(at: point, on: layer, document: document))
                along += spacing
            }
            distanceToNextStamp = along - length
        }
        previous = sample
        return dirty
    }

    /// Merges the stroke into the layer and returns its undo record.
    public func finish() -> TileChange? {
        guard let document, let layer = document.layer(id: layerID) else { return nil }
        if !settings.isEraser {
            for (key, overlay) in buffer {
                let base = layer.tiles[key] ?? Tile()
                layer.tiles[key] = Self.over(overlay, onto: base)
            }
        }
        for key in before.keys where layer.tiles[key]?.isEmpty == true {
            layer.tiles[key] = nil
        }
        guard !before.isEmpty else { return nil }
        let after = before.keys.reduce(into: [TileKey: Tile?]()) { result, key in
            result[key] = layer.tiles[key]
        }
        return TileChange(layerID: layerID, before: before, after: after)
    }

    /// Every tile this stroke has written to so far.
    public var touchedTiles: Set<TileKey> {
        Set(before.keys)
    }

    /// Discards the stroke and restores every touched tile.
    public func cancel() {
        guard let document, let layer = document.layer(id: layerID) else { return }
        for (key, original) in before {
            layer.tiles[key] = original
        }
        buffer.removeAll()
        before.removeAll()
    }

    // MARK: - Stamping

    private func stamp(at point: StrokeSample, on layer: Layer, document: ArtDocument) -> Set<TileKey> {
        let radius = max(0.5, settings.diameter / 2 * max(0.05, point.pressure))
        let hardness = min(max(settings.hardness, 0), 0.999)
        let opacity = min(max(settings.opacity, 0), 1)

        let minX = max(0, Int((point.x - radius).rounded(.down)))
        let maxX = min(document.width - 1, Int((point.x + radius).rounded(.up)))
        let minY = max(0, Int((point.y - radius).rounded(.down)))
        let maxY = min(document.height - 1, Int((point.y + radius).rounded(.up)))
        guard minX <= maxX, minY <= maxY else { return [] }

        var dirty = Set<TileKey>()
        for py in minY...maxY {
            for px in minX...maxX {
                let dx = Double(px) + 0.5 - point.x
                let dy = Double(py) + 0.5 - point.y
                let normalized = (dx * dx + dy * dy).squareRoot() / radius
                guard normalized < 1 else { continue }
                // Full coverage inside the hard core, linear falloff to the edge.
                let coverage = normalized <= hardness
                    ? 1
                    : (1 - normalized) / (1 - hardness)
                let alpha = coverage * opacity
                let key = TileKey(x: px / tileSize, y: py / tileSize)
                let index = ((py % tileSize) * tileSize + (px % tileSize)) * 4

                if settings.isEraser {
                    guard var tile = tileForWrite(key, on: layer) else { continue }
                    let keep = Float(1 - alpha)
                    for c in 0..<4 {
                        tile.pixels[index + c] = UInt8((Float(tile.pixels[index + c]) * keep).rounded())
                    }
                    layer.tiles[key] = tile
                } else {
                    captureBefore(key, on: layer)
                    var overlay = buffer[key] ?? Tile()
                    let current = Double(overlay.pixels[index + 3]) / 255
                    guard alpha > current else { continue }
                    overlay.pixels[index + 3] = UInt8((alpha * 255).rounded())
                    overlay.pixels[index + 0] = UInt8((settings.red * alpha * 255).rounded())
                    overlay.pixels[index + 1] = UInt8((settings.green * alpha * 255).rounded())
                    overlay.pixels[index + 2] = UInt8((settings.blue * alpha * 255).rounded())
                    buffer[key] = overlay
                }
                dirty.insert(key)
            }
        }
        return dirty
    }

    /// Captures the tile's original state the first time a stroke touches it.
    private func captureBefore(_ key: TileKey, on layer: Layer) {
        if before[key] == nil {
            before[key] = .some(layer.tiles[key])
        }
    }

    private func tileForWrite(_ key: TileKey, on layer: Layer) -> Tile? {
        captureBefore(key, on: layer)
        return layer.tiles[key]
    }

    /// Premultiplied over: `top` drawn on `bottom`.
    static func over(_ top: Tile, onto bottom: Tile) -> Tile {
        var out = [UInt8](repeating: 0, count: Tile.byteCount)
        for i in stride(from: 0, to: Tile.byteCount, by: 4) {
            let topAlpha = Float(top.pixels[i + 3]) / 255
            for c in 0..<4 {
                let value = Float(top.pixels[i + c]) + Float(bottom.pixels[i + c]) * (1 - topAlpha)
                out[i + c] = UInt8(min(255, value.rounded()))
            }
        }
        return Tile(pixels: out)
    }
}
