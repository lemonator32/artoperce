import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ExportError: Error {
    case flattenFailed
    case writeFailed
}

public enum Exporter {
    /// Writes the flattened document as a PNG with transparency. Guides are never exported (spec D16).
    public static func writePNG(of document: ArtDocument, to url: URL) throws {
        guard let image = document.flattenedImage() else { throw ExportError.flattenFailed }
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else { throw ExportError.writeFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ExportError.writeFailed }
    }
}
