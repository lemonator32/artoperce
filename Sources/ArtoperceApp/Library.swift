#if canImport(UIKit)
import ArtoperceEngine
import Foundation

/// A document in the gallery. The package is a folder in the app's Application Support directory.
public struct LibraryItem: Identifiable, Hashable {
    public let url: URL
    public let modified: Date

    public var id: URL { url }
    public var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Owns the document folder. Gallery operations go through here.
public enum Library {
    public static let presets: [(name: String, width: Int, height: Int)] = [
        ("Square 2048", 2048, 2048),
        ("Landscape 3072 × 2048", 3072, 2048),
        ("A4 at 300 dpi", 2480, 3508),
    ]

    public static var folder: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("Artoperce/Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    public static func items() -> [LibraryItem] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
        )) ?? []
        return urls
            .filter { $0.pathExtension == ArtStore.packageExtension }
            .map { url in
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                return LibraryItem(url: url, modified: date)
            }
            .sorted { $0.modified > $1.modified }
    }

    /// Creates a package with a unique "Untitled" name and returns its URL.
    public static func create(width: Int, height: Int) throws -> URL {
        var index = 1
        var url = folder.appendingPathComponent("Untitled.\(ArtStore.packageExtension)", isDirectory: true)
        while FileManager.default.fileExists(atPath: url.path) {
            index += 1
            url = folder.appendingPathComponent("Untitled \(index).\(ArtStore.packageExtension)", isDirectory: true)
        }
        _ = try ArtStore.create(at: url, width: width, height: height)
        return url
    }

    public static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
#endif
