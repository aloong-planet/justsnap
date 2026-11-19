import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// One image representation read from the clipboard, in the clipboard's own type order.
public struct ClipboardImageRepresentation: Equatable, Sendable {
    public let typeIdentifier: String
    public let data: Data

    public init(typeIdentifier: String, data: Data) {
        self.typeIdentifier = typeIdentifier
        self.data = data
    }
}

/// What a paste read from the clipboard: its image data, its plain text, and whether any item carries a
/// file reference (clipboard-paste::REQ-003/AC-01).
public struct ClipboardSnapshot: Equatable, Sendable {
    public let images: [ClipboardImageRepresentation]
    public let plainText: String?
    public let hasFileReference: Bool

    public init(images: [ClipboardImageRepresentation], plainText: String?, hasFileReference: Bool = false) {
        self.images = images
        self.plainText = plainText
        self.hasFileReference = hasFileReference
    }
}

/// How a paste treats what the clipboard holds (clipboard-paste::REQ-003).
public enum ClipboardPasteContent: Equatable, Sendable {
    /// The Pasted Image as an 8-bit sRGB PNG (clipboard-paste::REQ-004/AC-01).
    case image(png: Data)
    /// The Pasted Text exactly as read (clipboard-paste::REQ-007/AC-01).
    case text(String)
    /// Copied files: not processed (clipboard-paste::REQ-003/AC-08).
    case file
    case empty
    case unreadable
}

public enum ClipboardPaste {
    /// Applies the clipboard decision order of clipboard-paste's Implementation Decisions.
    /// Decoding and conversion can be slow for a large image; callers keep it off the main actor.
    public static func resolve(_ snapshot: ClipboardSnapshot) -> ClipboardPasteContent {
        if snapshot.hasFileReference {
            return .file
        }
        let text = snapshot.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !text.isEmpty, let plainText = snapshot.plainText, snapshot.images.isEmpty || !isSingleURL(text) {
            return .text(plainText)
        }
        if snapshot.images.isEmpty {
            return .empty
        }
        for representation in snapshot.images {
            if let png = convertedPNG(representation) {
                return .image(png: png)
            }
        }
        return .unreadable
    }

    static func isSingleURL(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace),
              let components = URLComponents(string: text),
              let scheme = components.scheme,
              !scheme.isEmpty
        else {
            return false
        }
        return text.dropFirst(scheme.count).hasPrefix("://")
    }

    private static func convertedPNG(_ representation: ClipboardImageRepresentation) -> Data? {
        guard let source = CGImageSourceCreateWithData(representation.data as CFData, nil),
              let sourceType = CGImageSourceGetType(source).flatMap({ UTType($0 as String) }),
              // Vector content is not a bitmap (clipboard-paste::REQ-003/AC-05).
              !sourceType.conforms(to: .pdf),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        return try? encodeSRGBPNG(image)
    }
}
