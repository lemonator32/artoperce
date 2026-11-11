import Foundation
import XCTest
@testable import ArtoperceEngine

final class TileCodecTests: XCTestCase {
    func testRoundTripPreservesPixels() throws {
        var tile = Tile()
        for i in stride(from: 0, to: Tile.byteCount, by: 7) {
            tile.pixels[i] = UInt8(i % 256)
        }
        let decoded = try TileCodec.decode(try TileCodec.encode(tile))
        XCTAssertEqual(decoded, tile)
    }

    func testCorruptPayloadIsRejected() throws {
        var tile = Tile()
        tile.pixels[100] = 255
        var data = try TileCodec.encode(tile)
        // Flip a bit in the stored checksum so the payload no longer matches.
        data[9] ^= 0xFF
        XCTAssertThrowsError(try TileCodec.decode(data))
    }

    func testCRC32CKnownVector() {
        // Standard CRC-32C check value for "123456789".
        XCTAssertEqual(TileCodec.crc32c(Array("123456789".utf8)), 0xE306_9283)
    }
}

final class StrokeAndHistoryTests: XCTestCase {
    private func makeDocument() -> ArtDocument {
        ArtDocument(width: 600, height: 400)
    }

    private func paintLine(_ document: ArtDocument, layer: UUID, settings: BrushSettings) -> TileChange? {
        let session = StrokeSession(document: document, layerID: layer, settings: settings)
        for i in 0...40 {
            session.add(StrokeSample(x: 20 + Double(i) * 12, y: 30 + Double(i) * 6, pressure: 0.5 + 0.5 * Double(i % 2)))
        }
        return session.finish()
    }

    func testPaintingCoversExpectedTiles() {
        let document = makeDocument()
        let layer = document.layers[0]
        let change = paintLine(document, layer: layer.id, settings: BrushSettings(diameter: 30, red: 1))
        XCTAssertNotNil(change)
        XCTAssertFalse(layer.tiles.isEmpty)
        // A stroke at (20...500, 30...270) must land in tiles (0,0) and (1,0), not (2,2).
        XCTAssertNotNil(layer.tiles[TileKey(x: 0, y: 0)])
        XCTAssertNil(layer.tiles[TileKey(x: 2, y: 2)])
    }

    func testUndoRedoRestoresPixelsExactly() {
        let document = makeDocument()
        let layer = document.layers[0]
        let history = History()

        let before = layer.tiles
        guard let change = paintLine(document, layer: layer.id, settings: BrushSettings(red: 0.2, green: 0.6, blue: 0.9)) else {
            return XCTFail("stroke produced no change")
        }
        let painted = layer.tiles
        history.push(change)

        history.undo(in: document)
        XCTAssertEqual(layer.tiles, before)

        history.redo(in: document)
        XCTAssertEqual(layer.tiles, painted)
    }

    func testEraserRemovesPaintAndUndoesIt() {
        let document = makeDocument()
        let layer = document.layers[0]
        let history = History()

        if let paint = paintLine(document, layer: layer.id, settings: BrushSettings(diameter: 40, red: 1)) {
            history.push(paint)
        }
        let painted = layer.tiles

        let session = StrokeSession(document: document, layerID: layer.id, settings: BrushSettings(diameter: 40, isEraser: true))
        for i in 0...40 {
            session.add(StrokeSample(x: 20 + Double(i) * 12, y: 30 + Double(i) * 6, pressure: 1))
        }
        if let erase = session.finish() {
            history.push(erase)
        }
        XCTAssertLessThan(layer.tiles.values.reduce(0) { $0 + $1.pixels.filter { $0 != 0 }.count },
                          painted.values.reduce(0) { $0 + $1.pixels.filter { $0 != 0 }.count })

        history.undo(in: document)
        XCTAssertEqual(layer.tiles, painted)
    }

    func testCancelRestoresTiles() {
        let document = makeDocument()
        let layer = document.layers[0]
        let session = StrokeSession(document: document, layerID: layer.id, settings: BrushSettings(red: 1))
        session.add(StrokeSample(x: 50, y: 50, pressure: 1))
        session.add(StrokeSample(x: 80, y: 50, pressure: 1))
        session.cancel()
        XCTAssertTrue(layer.tiles.isEmpty)
    }

    func testCompositeRespectsHiddenAndOpacity() {
        let document = makeDocument()
        let base = document.layers[0]
        let top = document.addLayer(above: base.id)
        var solid = Tile()
        for i in stride(from: 0, to: Tile.byteCount, by: 4) {
            solid.pixels[i + 3] = 255
            solid.pixels[i] = 255
        }
        base.tiles[TileKey(x: 0, y: 0)] = solid
        top.opacity = 0.5
        let blended = document.composite(tile: TileKey(x: 0, y: 0))
        XCTAssertEqual(blended.pixels[3], 255)
        top.isVisible = false
        let hidden = document.composite(tile: TileKey(x: 0, y: 0))
        XCTAssertEqual(hidden.pixels[0], 255)
    }
}

final class ArtStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("artoperce-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func packageURL() -> URL {
        directory.appendingPathComponent("Test.artoperce", isDirectory: true)
    }

    func testCommittedStrokeSurvivesReopen() throws {
        let (store, document) = try ArtStore.create(at: packageURL(), width: 600, height: 400)
        let layer = document.layers[0]
        let session = StrokeSession(document: document, layerID: layer.id, settings: BrushSettings(red: 0.9, green: 0.1, blue: 0.1))
        session.add(StrokeSample(x: 100, y: 100, pressure: 1))
        session.add(StrokeSample(x: 300, y: 200, pressure: 1))
        let change = try XCTUnwrap(session.finish())
        try store.commit(document, changes: Set(change.after.keys.map { ChangeKey(layerID: layer.id, tile: $0) }))

        let (_, reopened, recovered) = try ArtStore.open(at: packageURL())
        XCTAssertFalse(recovered)
        XCTAssertEqual(reopened.layers.first?.tiles, layer.tiles)
    }

    func testUncommittedJournalRecordIsRolledBackOnOpen() throws {
        let (store, document) = try ArtStore.create(at: packageURL(), width: 600, height: 400)
        let layer = document.layers[0]

        // Commit one stroke so there is a pre-existing tile on disk.
        let first = StrokeSession(document: document, layerID: layer.id, settings: BrushSettings(red: 1))
        first.add(StrokeSample(x: 100, y: 100, pressure: 1))
        let firstChange = try XCTUnwrap(first.finish())
        let keys = Set(firstChange.after.keys.map { ChangeKey(layerID: layer.id, tile: $0) })
        try store.commit(document, changes: keys)
        let committedTiles = layer.tiles

        // Simulate a crash mid-commit: write a journal record and overwrite a tile, then stop.
        let second = StrokeSession(document: document, layerID: layer.id, settings: BrushSettings(red: 0, green: 0, blue: 1))
        second.add(StrokeSample(x: 110, y: 105, pressure: 1))
        _ = second.finish()
        try simulateTornCommit(store: store, document: document, keys: keys, seq: 2)

        let (_, reopened, recovered) = try ArtStore.open(at: packageURL())
        XCTAssertTrue(recovered)
        XCTAssertEqual(reopened.layers.first?.tiles, committedTiles)
    }

    /// Writes what a commit would write before its commit marker, then returns without finishing.
    private func simulateTornCommit(store: ArtStore, document: ArtDocument, keys: Set<ChangeKey>, seq: UInt64) throws {
        let fm = FileManager.default
        let journal = packageURL().appendingPathComponent("history/journal.log")
        let tiles = keys.map { key -> [String: Any] in
            ["layer": key.layerID.uuidString, "x": key.tile.x, "y": key.tile.y, "existed": true]
        }
        let layers = document.layers.map { ["id": $0.id.uuidString, "name": $0.name, "opacity": $0.opacity, "visible": $0.isVisible] as [String: Any] }
        let record: [String: Any] = ["seq": seq, "layers": layers, "tiles": tiles, "width": document.width, "height": document.height]
        var line = try JSONSerialization.data(withJSONObject: record)
        line.append(0x0A)
        try line.write(to: journal)

        for key in keys {
            let preURL = packageURL().appendingPathComponent("history/pre-\(seq)/\(key.layerID.uuidString)_\(key.tile.fileStem).tile")
            try fm.createDirectory(at: preURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: packageURL().appendingPathComponent("layers/\(key.layerID.uuidString)/tiles/\(key.tile.fileStem).tile"), to: preURL)
            // The new tile content lands on disk but the commit marker never does.
            let garbage = try TileCodec.encode(Tile(pixels: [UInt8](repeating: 77, count: Tile.byteCount)))
            try garbage.write(to: packageURL().appendingPathComponent("layers/\(key.layerID.uuidString)/tiles/\(key.tile.fileStem).tile"))
        }
    }
}
