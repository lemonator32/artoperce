import Foundation

/// Undo and redo over tile changes. Each entry is one user-visible step (spec 12 §5.2).
/// Pushing a new change clears the redo stack.
public final class History {
    public let limit: Int
    public private(set) var undoStack: [TileChange] = []
    public private(set) var redoStack: [TileChange] = []

    public init(limit: Int = 100) {
        self.limit = limit
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func push(_ change: TileChange) {
        undoStack.append(change)
        redoStack.removeAll()
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
    }

    /// Reverts the most recent change. Returns the keys that changed, or nil if there is nothing to undo.
    @discardableResult
    public func undo(in document: ArtDocument) -> Set<ChangeKey>? {
        guard let change = undoStack.popLast() else { return nil }
        redoStack.append(change)
        return document.apply(change, useAfter: false)
    }

    @discardableResult
    public func redo(in document: ArtDocument) -> Set<ChangeKey>? {
        guard let change = redoStack.popLast() else { return nil }
        undoStack.append(change)
        return document.apply(change, useAfter: true)
    }
}
