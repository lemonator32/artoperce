import CoreGraphics
import Foundation

/// One raster layer. Tiles that are fully transparent are absent from `tiles`.
public final class Layer: Identifiable {
    public let id: UUID
    public var name: String
    public var opacity: Double
    public var isVisible: Bool
    public var tiles: [TileKey: Tile]

    public init(
        id: UUID = UUID(),
        name: String,
        opacity: Double = 1,
        isVisible: Bool = true,
        tiles: [TileKey: Tile] = [:]
    ) {
        self.id = id
        self.name = name
        self.opacity = opacity
        self.isVisible = isVisible
        self.tiles = tiles
    }
}

/// A (layer, tile) pair. Used to say exactly which storage tiles changed.
public struct ChangeKey: Hashable, Sendable {
    public let layerID: UUID
    public let tile: TileKey

    public init(layerID: UUID, tile: TileKey) {
        self.layerID = layerID
        self.tile = tile
    }
}

/// The before and after state of the tiles one undoable operation touched.
/// `nil` means the tile was absent (transparent).
public struct TileChange: Sendable {
    public var layerID: UUID
    public var before: [TileKey: Tile?]
    public var after: [TileKey: Tile?]

    public init(layerID: UUID, before: [TileKey: Tile?], after: [TileKey: Tile?]) {
        self.layerID = layerID
        self.before = before
        self.after = after
    }
}

/// The canvas model. Layers are ordered bottom to top.
public final class ArtDocument {
    public let width: Int
    public let height: Int
    public private(set) var layers: [Layer]

    public init(width: Int, height: Int, layers: [Layer]? = nil) {
        precondition(width > 0 && height > 0, "canvas must be non-empty")
        self.width = width
        self.height = height
        self.layers = layers ?? [Layer(name: "Layer 1")]
    }

    public func layer(id: UUID) -> Layer? {
        layers.first { $0.id == id }
    }

    /// Number of tile columns and rows that cover the canvas.
    public var tileColumns: Int { (width + tileSize - 1) / tileSize }
    public var tileRows: Int { (height + tileSize - 1) / tileSize }

    /// Adds a layer above `above` (or on top when nil) and returns it.
    @discardableResult
    public func addLayer(above: UUID? = nil) -> Layer {
        let layer = Layer(name: "Layer \(layers.count + 1)")
        if let above, let index = layers.firstIndex(where: { $0.id == above }) {
            layers.insert(layer, at: index + 1)
        } else {
            layers.append(layer)
        }
        return layer
    }

    /// Applies one side of a change. Returns the keys that changed.
    @discardableResult
    public func apply(_ change: TileChange, useAfter: Bool) -> Set<ChangeKey> {
        guard let layer = layer(id: change.layerID) else { return [] }
        let state = useAfter ? change.after : change.before
        for (key, tile) in state {
            layer.tiles[key] = tile
        }
        return Set(state.keys.map { ChangeKey(layerID: change.layerID, tile: $0) })
    }

    /// Every tile position that holds content on any layer.
    public var occupiedTileKeys: Set<TileKey> {
        Set(layers.flatMap { $0.tiles.keys })
    }

    /// Premultiplied "over" composite of all visible layers for one tile.
    /// `overlay` is an in-progress stroke buffer, drawn over `overlayLayerID`.
    public func composite(
        tile key: TileKey,
        overlay: (layerID: UUID, tile: Tile)? = nil
    ) -> Tile {
        let count = Tile.byteCount
        var acc = [Float](repeating: 0, count: count)

        for layer in layers where layer.isVisible && layer.opacity > 0 {
            var src = [Float](repeating: 0, count: count)
            let base = layer.tiles[key]
            let over = overlay?.layerID == layer.id ? overlay?.tile : nil
            if base == nil && over == nil { continue }

            for i in 0..<count {
                var value = Float(base?.pixels[i] ?? 0) / 255
                if let over {
                    let overPixel = Float(over.pixels[i]) / 255
                    // Premultiplied over: out = over + base * (1 - over.alpha)
                    let overAlpha = Float(over.pixels[i - i % 4 + 3]) / 255
                    value = overPixel + value * (1 - overAlpha)
                }
                src[i] = value
            }

            let opacity = Float(layer.opacity)
            for i in stride(from: 0, to: count, by: 4) {
                let alpha = src[i + 3] * opacity
                for c in 0..<3 {
                    acc[i + c] = src[i + c] * opacity + acc[i + c] * (1 - alpha)
                }
                acc[i + 3] = alpha + acc[i + 3] * (1 - alpha)
            }
        }

        var out = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            out[i] = UInt8(max(0, min(255, (acc[i] * 255).rounded())))
        }
        return Tile(pixels: out)
    }

    /// Flattens all visible layers into one image. Transparent where nothing is painted.
    public func flattenedImage() -> CGImage? {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else { return nil }
        for row in 0..<tileRows {
            for column in 0..<tileColumns {
                let key = TileKey(x: column, y: row)
                guard occupiedTileKeys.contains(key),
                      let image = composite(tile: key).makeImage() else { continue }
                // CoreGraphics origin is bottom-left; tile rows grow downward.
                let rect = CGRect(
                    x: column * tileSize,
                    y: height - (row + 1) * tileSize,
                    width: tileSize,
                    height: tileSize
                )
                context.draw(image, in: rect)
            }
        }
        return context.makeImage()
    }
}
