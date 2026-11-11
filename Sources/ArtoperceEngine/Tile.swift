import CoreGraphics
import Foundation

/// Edge length of a storage tile in document pixels (spec 12 §3).
public let tileSize = 256

/// Integer tile coordinate. Tile (x, y) covers document pixels
/// x*256 ..< x*256+256 and y*256 ..< y*256+256.
public struct TileKey: Hashable, Comparable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    public static func < (a: TileKey, b: TileKey) -> Bool {
        (a.y, a.x) < (b.y, b.x)
    }

    /// File-name form used inside the package, e.g. "3_2".
    public var fileStem: String { "\(x)_\(y)" }
}

/// 256 × 256 premultiplied RGBA8 pixels (spec 12 §3).
/// Value semantics make before-images cheap to keep: copy-on-write.
public struct Tile: Equatable, Sendable {
    public static let byteCount = tileSize * tileSize * 4

    public var pixels: [UInt8]

    public init() {
        pixels = [UInt8](repeating: 0, count: Tile.byteCount)
    }

    public init(pixels: [UInt8]) {
        precondition(pixels.count == Tile.byteCount, "tile must be \(Tile.byteCount) bytes")
        self.pixels = pixels
    }

    /// True when every pixel is fully transparent. Empty tiles are not stored (spec 12 §3).
    public var isEmpty: Bool {
        !pixels.contains { $0 != 0 }
    }

    /// Makes a CGImage of the tile for display. Premultiplied, so it composites correctly.
    public func makeImage() -> CGImage? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: tileSize,
            height: tileSize,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: tileSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
