import Foundation

public enum StoreError: Error, Equatable {
    case missingManifest
    case unsupportedFormat(Int)
    case journalReplayFailed(String)
    case corruptTile(String)
}

/// On-disk `.artoperce` package (spec 12 §1 and §4). Every commit is durable before it returns.
///
/// Commit order: journal record (with pre-images) → tile files → commit marker → manifest.
/// On open, records without a commit marker are rolled back from their pre-images.
public final class ArtStore {
    public static let packageExtension = "artoperce"
    static let formatVersion = 1

    public let url: URL
    private var lastCommittedSeq: UInt64

    private init(url: URL, lastCommittedSeq: UInt64) {
        self.url = url
        self.lastCommittedSeq = lastCommittedSeq
    }

    private var manifestURL: URL { url.appendingPathComponent("manifest.json") }
    private var historyURL: URL { url.appendingPathComponent("history", isDirectory: true) }
    private var journalURL: URL { historyURL.appendingPathComponent("journal.log") }

    private func tileURL(layer: UUID, key: TileKey) -> URL {
        url.appendingPathComponent("layers/\(layer.uuidString)/tiles/\(key.fileStem).tile")
    }

    private func preImageURL(seq: UInt64, layer: UUID, key: TileKey) -> URL {
        historyURL.appendingPathComponent("pre-\(seq)/\(layer.uuidString)_\(key.fileStem).tile")
    }

    // MARK: - Create and open

    /// Creates an empty package with one layer and returns the store and document.
    public static func create(at url: URL, width: Int, height: Int) throws -> (ArtStore, ArtDocument) {
        let fm = FileManager.default
        try fm.createDirectory(at: url, withIntermediateDirectories: true)
        let document = ArtDocument(width: width, height: height)
        let store = ArtStore(url: url, lastCommittedSeq: 0)
        try fm.createDirectory(at: store.historyURL, withIntermediateDirectories: true)
        try fm.createDirectory(at: url.appendingPathComponent("layers"), withIntermediateDirectories: true)
        try store.writeManifest(document: document, lastCommittedSeq: 0)
        try Data().write(to: store.journalURL, options: .atomic)
        return (store, document)
    }

    /// Opens a package, rolling back any uncommitted journal records first.
    /// Returns the document and whether recovery changed anything.
    public static func open(at url: URL) throws -> (ArtStore, ArtDocument, recovered: Bool) {
        let manifestURL = url.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { throw StoreError.missingManifest }
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.formatVersion == formatVersion else {
            throw StoreError.unsupportedFormat(manifest.formatVersion)
        }

        let store = ArtStore(url: url, lastCommittedSeq: manifest.lastCommittedSeq)
        let recovered = try store.recoverJournal(manifest: manifest)

        // Load after recovery so the document reflects the restored state.
        let finalManifest: Manifest
        if recovered.manifestWasStale, let fresh = recovered.manifest {
            finalManifest = fresh
            store.lastCommittedSeq = fresh.lastCommittedSeq
        } else {
            finalManifest = manifest
        }
        let document = ArtDocument(
            width: finalManifest.width,
            height: finalManifest.height,
            layers: try finalManifest.layers.map { entry in
                let layer = Layer(
                    id: UUID(uuidString: entry.id) ?? UUID(),
                    name: entry.name,
                    opacity: entry.opacity,
                    isVisible: entry.visible
                )
                layer.tiles = try store.loadTiles(layer: layer.id)
                return layer
            }
        )
        return (store, document, recovered.didRecover)
    }

    // MARK: - Commit

    /// Persists the given tile changes and the current layer list.
    /// Pass an empty set to persist only layer metadata.
    public func commit(_ document: ArtDocument, changes: Set<ChangeKey>) throws {
        let seq = lastCommittedSeq + 1
        let fm = FileManager.default

        // 1. Journal record, with pre-images of tiles that exist on disk now.
        let entries = changes.sorted { ($0.layerID.uuidString, $0.tile) < ($1.layerID.uuidString, $1.tile) }
        var journalTiles: [JournalTile] = []
        for change in entries {
            let existed = fm.fileExists(atPath: tileURL(layer: change.layerID, key: change.tile).path)
            journalTiles.append(JournalTile(layer: change.layerID.uuidString, x: change.tile.x, y: change.tile.y, existed: existed))
            if existed {
                let preURL = preImageURL(seq: seq, layer: change.layerID, key: change.tile)
                try fm.createDirectory(at: preURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: tileURL(layer: change.layerID, key: change.tile), to: preURL)
            }
        }
        let layers = document.layers.map(LayerEntry.init)
        let record = JournalRecord(seq: seq, layers: layers, tiles: journalTiles, width: document.width, height: document.height)
        try appendJournal(try JSONEncoder().encode(record))

        // 2. Tile files, written atomically one by one.
        for change in entries {
            let target = tileURL(layer: change.layerID, key: change.tile)
            let tile = document.layer(id: change.layerID)?.tiles[change.tile]
            if let tile, !tile.isEmpty {
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try TileCodec.encode(tile).write(to: target, options: .atomic)
            } else if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
        }

        // 3. Commit marker.
        try appendJournal(try JSONEncoder().encode(CommitMarker(commit: seq)))

        // 4. Manifest, atomically.
        try writeManifest(document: document, lastCommittedSeq: seq)
        lastCommittedSeq = seq

        // Nothing is pending now, so the journal can be cleared and pre-images dropped.
        try Data().write(to: journalURL, options: .atomic)
        try? fm.removeItem(at: historyURL.appendingPathComponent("pre-\(seq)"))
    }

    // MARK: - Manifest and journal helpers

    private func writeManifest(document: ArtDocument, lastCommittedSeq: UInt64) throws {
        let manifest = Manifest(
            formatVersion: ArtStore.formatVersion,
            width: document.width,
            height: document.height,
            lastCommittedSeq: lastCommittedSeq,
            layers: document.layers.map(LayerEntry.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private func appendJournal(_ line: Data) throws {
        var data = line
        data.append(0x0A)
        if !FileManager.default.fileExists(atPath: journalURL.path) {
            FileManager.default.createFile(atPath: journalURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: journalURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.synchronize()
    }

    /// Rolls back uncommitted records and finishes committed ones whose manifest was not written.
    private func recoverJournal(manifest: Manifest) throws -> (didRecover: Bool, manifestWasStale: Bool, manifest: Manifest?) {
        guard let raw = try? String(contentsOf: journalURL, encoding: .utf8), !raw.isEmpty else {
            return (false, false, nil)
        }
        let decoder = JSONDecoder()
        var records: [JournalRecord] = []
        var committed = Set<UInt64>()
        for line in raw.split(separator: "\n") {
            // A torn final line from a crash is ignored, not an error.
            let data = Data(line.utf8)
            if let marker = try? decoder.decode(CommitMarker.self, from: data) {
                committed.insert(marker.commit)
            } else if let record = try? decoder.decode(JournalRecord.self, from: data) {
                records.append(record)
            }
        }

        var didRecover = false
        var latest: Manifest?
        for record in records where record.seq > manifest.lastCommittedSeq {
            didRecover = true
            if committed.contains(record.seq) {
                // Tiles were written; only the manifest is stale. Adopt the record's layer list.
                latest = Manifest(
                    formatVersion: ArtStore.formatVersion,
                    width: record.width,
                    height: record.height,
                    lastCommittedSeq: record.seq,
                    layers: record.layers
                )
                try writeManifestRaw(latest!)
            } else {
                try rollBack(record)
            }
        }

        if didRecover {
            try Data().write(to: journalURL, options: .atomic)
        }
        return (didRecover, latest != nil, latest)
    }

    private func rollBack(_ record: JournalRecord) throws {
        let fm = FileManager.default
        for entry in record.tiles {
            guard let layer = UUID(uuidString: entry.layer) else { continue }
            let key = TileKey(x: entry.x, y: entry.y)
            let target = tileURL(layer: layer, key: key)
            if entry.existed {
                let preURL = preImageURL(seq: record.seq, layer: layer, key: key)
                guard fm.fileExists(atPath: preURL.path) else {
                    throw StoreError.journalReplayFailed("missing pre-image for \(key.fileStem)")
                }
                if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
                try fm.moveItem(at: preURL, to: target)
            } else if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
        }
        try? fm.removeItem(at: historyURL.appendingPathComponent("pre-\(record.seq)"))
    }

    private func writeManifestRaw(_ manifest: Manifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: manifestURL, options: .atomic)
    }

    private func loadTiles(layer: UUID) throws -> [TileKey: Tile] {
        let directory = url.appendingPathComponent("layers/\(layer.uuidString)/tiles", isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return [:]
        }
        var tiles: [TileKey: Tile] = [:]
        for name in names where name.hasSuffix(".tile") {
            let parts = name.dropLast(5).split(separator: "_")
            guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { continue }
            let data = try Data(contentsOf: directory.appendingPathComponent(name))
            do {
                tiles[TileKey(x: x, y: y)] = try TileCodec.decode(data)
            } catch {
                throw StoreError.corruptTile("layer \(layer.uuidString) tile \(name)")
            }
        }
        return tiles
    }

    // MARK: - Codable records

    struct Manifest: Codable {
        var formatVersion: Int
        var width: Int
        var height: Int
        var lastCommittedSeq: UInt64
        var layers: [LayerEntry]
    }

    struct LayerEntry: Codable {
        var id: String
        var name: String
        var opacity: Double
        var visible: Bool

        init(_ layer: Layer) {
            id = layer.id.uuidString
            name = layer.name
            opacity = layer.opacity
            visible = layer.isVisible
        }
    }

    struct JournalTile: Codable {
        var layer: String
        var x: Int
        var y: Int
        var existed: Bool
    }

    struct JournalRecord: Codable {
        var seq: UInt64
        var layers: [LayerEntry]
        var tiles: [JournalTile]
        var width: Int
        var height: Int
    }

    struct CommitMarker: Codable {
        var commit: UInt64
    }
}
