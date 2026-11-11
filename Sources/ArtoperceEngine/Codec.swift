import Compression
import Foundation

public enum CodecError: Error, Equatable {
    case compressionFailed
    case checksumMismatch
    case malformedTile
}

/// LZ4 block compression and CRC-32C checksums for tile files (spec 12 §3).
public enum TileCodec {
    /// Tile file layout: magic "ATL1" | codec (1 byte, 1 = LZ4) | uncompressed size
    /// (UInt32 LE) | CRC-32C of uncompressed bytes (UInt32 LE) | LZ4 payload.
    static let magic: [UInt8] = Array("ATL1".utf8)
    static let headerSize = 4 + 1 + 4 + 4

    public static func encode(_ tile: Tile) throws -> Data {
        let source = tile.pixels
        let capacity = source.count + 1024
        var destination = [UInt8](repeating: 0, count: capacity)
        let written = compression_encode_buffer(
            &destination, capacity, source, source.count, nil, COMPRESSION_LZ4
        )
        guard written > 0 else { throw CodecError.compressionFailed }

        var data = Data(magic)
        data.append(1)
        data.append(littleEndian32(UInt32(source.count)))
        data.append(littleEndian32(crc32c(source)))
        data.append(contentsOf: destination[0..<written])
        return data
    }

    public static func decode(_ data: Data) throws -> Tile {
        let bytes = [UInt8](data)
        guard bytes.count > headerSize, Array(bytes[0..<4]) == magic, bytes[4] == 1 else {
            throw CodecError.malformedTile
        }
        let size = Int(readUInt32(bytes, at: 5))
        let checksum = readUInt32(bytes, at: 9)
        guard size == Tile.byteCount else { throw CodecError.malformedTile }

        var output = [UInt8](repeating: 0, count: size)
        let payload = Array(bytes[headerSize...])
        let written = compression_decode_buffer(
            &output, size, payload, payload.count, nil, COMPRESSION_LZ4
        )
        guard written == size else { throw CodecError.malformedTile }
        guard crc32c(output) == checksum else { throw CodecError.checksumMismatch }
        return Tile(pixels: output)
    }

    // MARK: - CRC-32C (Castagnoli), table-driven

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var crc = UInt32(index)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0x82F6_3B78 : crc >> 1
        }
        return crc
    }

    public static func crc32c(_ bytes: [UInt8]) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in bytes {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static func littleEndian32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }
}
