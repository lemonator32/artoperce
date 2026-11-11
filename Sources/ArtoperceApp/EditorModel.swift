#if canImport(UIKit)
import ArtoperceEngine
import Foundation
import SwiftUI
import UIKit

/// State for one open document: the store, the document, undo history, the brush,
/// and the stroke in progress. Everything runs on the main actor in this version.
@MainActor
public final class EditorModel: ObservableObject, Hashable {
    public let url: URL
    public let store: ArtStore
    public let document: ArtDocument
    public let history = History()

    @Published public var activeLayerID: UUID
    @Published public var diameter: Double = 24
    @Published public var opacity: Double = 1
    @Published public var color: Color = .black
    @Published public var isEraser = false
    @Published public var fingerDrawingEnabled = true
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false
    @Published public private(set) var layers: [Layer] = []
    @Published public var notice: String?

    /// Set by the canvas. Called with tile positions that need redrawing.
    public var onTilesChanged: ((Set<TileKey>) -> Void)?

    private var session: StrokeSession?

    private init(url: URL, store: ArtStore, document: ArtDocument) {
        self.url = url
        self.store = store
        self.document = document
        self.activeLayerID = document.layers.first?.id ?? UUID()
        self.layers = document.layers
    }

    public nonisolated static func == (lhs: EditorModel, rhs: EditorModel) -> Bool { lhs === rhs }
    public nonisolated func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }

    /// Opens a package, rolling back any interrupted commit. Throws if the package cannot be read.
    public static func load(url: URL) throws -> EditorModel {
        let (store, document, recovered) = try ArtStore.open(at: url)
        let model = EditorModel(url: url, store: store, document: document)
        if recovered {
            model.notice = "Restored to the last completed stroke. The interrupted stroke was discarded."
        }
        return model
    }

    public var activeLayer: Layer? {
        document.layer(id: activeLayerID)
    }

    // MARK: - Strokes

    public func beginStroke() {
        guard let layer = activeLayer, layer.isVisible else { return }
        session?.cancel()
        session = StrokeSession(document: document, layerID: layer.id, settings: currentBrush())
    }

    /// Adds samples from the current stroke and redraws the affected tiles.
    public func continueStroke(_ samples: [StrokeSample]) {
        guard let session else { return }
        var dirty = Set<TileKey>()
        for sample in samples {
            dirty.formUnion(session.add(sample))
        }
        if !dirty.isEmpty { onTilesChanged?(dirty) }
    }

    /// Commits the stroke as one undo step, then saves it to disk.
    public func endStroke() {
        guard let session else { return }
        self.session = nil
        guard let change = session.finish() else { return }
        history.push(change)
        persist(keys: Set(change.after.keys.map { ChangeKey(layerID: change.layerID, tile: $0) }))
        onTilesChanged?(Set(change.after.keys))
        refreshHistoryState()
    }

    public func cancelStroke() {
        guard let session else { return }
        let dirty = session.touchedTiles
        session.cancel()
        self.session = nil
        if !dirty.isEmpty { onTilesChanged?(dirty) }
    }

    /// Composited pixels for one tile, including the stroke in progress.
    public func image(for key: TileKey) -> CGImage? {
        let overlay = session.flatMap { session -> (layerID: UUID, tile: Tile)? in
            session.buffer[key].map { (session.layerID, $0) }
        }
        let tile = document.composite(tile: key, overlay: overlay)
        return tile.isEmpty ? nil : tile.makeImage()
    }

    // MARK: - History

    public func undo() {
        cancelStroke()
        guard let keys = history.undo(in: document) else { return }
        persist(keys: keys)
        onTilesChanged?(Set(keys.map(\.tile)))
        refreshHistoryState()
    }

    public func redo() {
        cancelStroke()
        guard let keys = history.redo(in: document) else { return }
        persist(keys: keys)
        onTilesChanged?(Set(keys.map(\.tile)))
        refreshHistoryState()
    }

    private func refreshHistoryState() {
        canUndo = history.canUndo
        canRedo = history.canRedo
    }

    // MARK: - Layers

    public func addLayer() {
        let layer = document.addLayer(above: activeLayerID)
        activeLayerID = layer.id
        layersChanged(persistTiles: [])
    }

    public func selectLayer(_ layer: Layer) {
        activeLayerID = layer.id
    }

    public func setVisible(_ visible: Bool, for layer: Layer) {
        layer.isVisible = visible
        layersChanged(persistTiles: [])
    }

    public func setOpacity(_ value: Double, for layer: Layer) {
        layer.opacity = value
        layersChanged(persistTiles: [])
    }

    private func layersChanged(persistTiles: Set<ChangeKey>) {
        // Layer objects are classes, so the array can look unchanged to SwiftUI. Notify explicitly.
        objectWillChange.send()
        layers = document.layers
        persist(keys: persistTiles)
        onTilesChanged?(document.occupiedTileKeys)
    }

    // MARK: - Export

    /// Writes a PNG of the flattened artwork to a temporary file and returns its URL.
    public func exportPNG() throws -> URL {
        let name = url.deletingPathExtension().lastPathComponent
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).png")
        try? FileManager.default.removeItem(at: target)
        try Exporter.writePNG(of: document, to: target)
        return target
    }

    // MARK: - Helpers

    private func currentBrush() -> BrushSettings {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return BrushSettings(
            diameter: diameter,
            opacity: opacity,
            hardness: 0.8,
            spacing: 0.12,
            red: Double(r),
            green: Double(g),
            blue: Double(b),
            isEraser: isEraser
        )
    }

    private func persist(keys: Set<ChangeKey>) {
        do {
            try store.commit(document, changes: keys)
        } catch {
            notice = "Could not save: \(error.localizedDescription)"
        }
    }
}
#endif
