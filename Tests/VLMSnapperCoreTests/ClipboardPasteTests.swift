import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import VLMSnapperCore

@Suite("Clipboard paste content")
struct ClipboardPasteTests {
    @Test(
        "image data with no text or a single URL is pasted as the image",
        arguments: [
            nil,
            "",
            " \n",
            "https://example.com/images/cat.png",
            "  file:///Users/someone/Pictures/cat.png\n",
        ] as [String?]
    )
    func imageWithoutTextIsPasted(plainText: String?) throws {
        let snapshot = ClipboardSnapshot(
            images: [ClipboardImageRepresentation(
                typeIdentifier: UTType.png.identifier,
                data: encodedImage(width: 5, height: 3, type: .png)
            )],
            plainText: plainText
        )

        let png = try #require(ClipboardPaste.resolve(snapshot).pastedPNG)

        let decoded = try decodeFirstFrame(png)
        #expect(decoded.width == 5)
        #expect(decoded.height == 3)
    }

    @Test(
        "any other plain text makes a text clipboard carrying the text as read, with or without an image",
        arguments: [
            ("hello", true),
            ("https://a.example/x https://b.example/y", true),
            ("see https://example.com/cat.png", true),
            ("ratio:3", true),
            ("  第一行\nsecond line \n", true),
            ("hello", false),
            ("https://example.com/only-a-link", false),
            ("\t缩进的文字\n\n", false),
        ]
    )
    func otherTextIsATextClipboard(plainText: String, withImage: Bool) {
        let snapshot = ClipboardSnapshot(
            images: withImage
                ? [ClipboardImageRepresentation(
                    typeIdentifier: UTType.png.identifier,
                    data: encodedImage(width: 2, height: 2, type: .png)
                )]
                : [],
            plainText: plainText
        )

        #expect(ClipboardPaste.resolve(snapshot) == .text(plainText))
    }

    @Test(
        "a clipboard whose item carries a file reference is a file clipboard",
        arguments: [
            // Shaped like a real Finder copy: the file name as plain text and the file's icon as image data.
            ("report.pdf", [ClipboardImageRepresentation(
                typeIdentifier: "com.apple.icns",
                data: encodedImage(width: 16, height: 16, type: .png)
            )]),
            ("https://example.com/cat.png", [ClipboardImageRepresentation(
                typeIdentifier: UTType.png.identifier,
                data: encodedImage(width: 3, height: 3, type: .png)
            )]),
            (nil, []),
        ] as [(String?, [ClipboardImageRepresentation])]
    )
    func fileReferenceIsAFileClipboard(plainText: String?, images: [ClipboardImageRepresentation]) {
        let snapshot = ClipboardSnapshot(images: images, plainText: plainText, hasFileReference: true)

        #expect(ClipboardPaste.resolve(snapshot) == .file)
    }

    @Test(
        "a clipboard with neither image data nor text is empty",
        arguments: [nil, "", "  ", " \n\t\n"] as [String?]
    )
    func nothingUsableIsEmpty(plainText: String?) {
        #expect(ClipboardPaste.resolve(ClipboardSnapshot(images: [], plainText: plainText)) == .empty)
    }

    @Test("image data that does not decode as a bitmap is unreadable")
    func undecodableImageIsUnreadable() {
        let snapshot = ClipboardSnapshot(
            images: [ClipboardImageRepresentation(
                typeIdentifier: UTType.png.identifier,
                data: Data("not an image".utf8)
            )],
            plainText: nil
        )

        #expect(ClipboardPaste.resolve(snapshot) == .unreadable)
    }

    @Test("vector PDF as the only image is unreadable")
    func pdfOnlyIsUnreadable() {
        let snapshot = ClipboardSnapshot(
            images: [ClipboardImageRepresentation(
                typeIdentifier: UTType.pdf.identifier,
                data: onePagePDF()
            )],
            plainText: nil
        )

        #expect(ClipboardPaste.resolve(snapshot) == .unreadable)
    }

    @Test("a later representation is used when the first does not decode")
    func fallsBackToADecodableRepresentation() throws {
        let snapshot = ClipboardSnapshot(
            images: [
                ClipboardImageRepresentation(
                    typeIdentifier: UTType.png.identifier,
                    data: Data("broken".utf8)
                ),
                ClipboardImageRepresentation(
                    typeIdentifier: UTType.tiff.identifier,
                    data: encodedImage(width: 4, height: 7, type: .tiff)
                ),
            ],
            plainText: nil
        )

        let png = try #require(ClipboardPaste.resolve(snapshot).pastedPNG)

        let decoded = try decodeFirstFrame(png)
        #expect(decoded.width == 4)
        #expect(decoded.height == 7)
    }

    @Test("a 16-bit wide-gamut image becomes an 8-bit sRGB PNG with its size and transparency")
    func wideGamutImageIsConvertedKeepingAlpha() throws {
        let snapshot = ClipboardSnapshot(
            images: [ClipboardImageRepresentation(
                typeIdentifier: UTType.png.identifier,
                data: sixteenBitDisplayP3PNGWithTransparentHalf(width: 6, height: 4)
            )],
            plainText: nil
        )

        let png = try #require(ClipboardPaste.resolve(snapshot).pastedPNG)

        let decoded = try decodeFirstFrame(png)
        #expect(decoded.width == 6)
        #expect(decoded.height == 4)
        #expect(decoded.bitsPerComponent == 8)
        #expect(decoded.colorSpace?.name == CGColorSpace.sRGB)
        let pixels = rgba(decoded)
        // Row 0 of the bitmap is the top half, drawn transparent.
        #expect(pixels[3] == 0)
        #expect(pixels[(decoded.width * (decoded.height - 1)) * 4 + 3] == 255)
    }

    @Test("an animated image is pasted as its first frame")
    func animatedImageUsesFirstFrame() throws {
        let snapshot = ClipboardSnapshot(
            images: [ClipboardImageRepresentation(
                typeIdentifier: UTType.gif.identifier,
                data: twoFrameGIF()
            )],
            plainText: nil
        )

        let png = try #require(ClipboardPaste.resolve(snapshot).pastedPNG)

        let decoded = try decodeFirstFrame(png)
        #expect(decoded.width == 3)
        #expect(decoded.height == 2)
        let pixels = rgba(decoded)
        #expect(Array(pixels[0..<3]) == [255, 0, 0])
    }
}

extension ClipboardPasteContent {
    var pastedPNG: Data? {
        if case let .image(png) = self { return png }
        return nil
    }
}

func encodedImage(width: Int, height: Int, type: UTType) -> Data {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        output,
        type.identifier as CFString,
        1,
        nil
    )!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
    return output as Data
}

func decodeFirstFrame(_ data: Data) throws -> CGImage {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    #expect(CGImageSourceGetType(source) as String? == UTType.png.identifier)
    return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
}

private func onePagePDF() -> Data {
    let output = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 40, height: 40)
    let consumer = CGDataConsumer(data: output)!
    let context = CGContext(consumer: consumer, mediaBox: &box, nil)!
    context.beginPDFPage(nil)
    context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
    context.fill(CGRect(x: 5, y: 5, width: 30, height: 30))
    context.endPDFPage()
    context.closePDF()
    return output as Data
}

private func sixteenBitDisplayP3PNGWithTransparentHalf(width: Int, height: Int) -> Data {
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 16,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.displayP3)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder16Little.rawValue
    )!
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 0, green: 1, blue: 0, alpha: 1)
    // Core Graphics' origin is bottom-left: this fills the bottom half.
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    let image = context.makeImage()!
    #expect(image.bitsPerComponent == 16)
    return encode([image], type: .png)
}

private func twoFrameGIF() -> Data {
    func frame(red: CGFloat, blue: CGFloat) -> CGImage {
        let context = CGContext(
            data: nil,
            width: 3,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: red, green: 0, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        return context.makeImage()!
    }
    return encode([frame(red: 1, blue: 0), frame(red: 0, blue: 1)], type: .gif)
}

private func encode(_ images: [CGImage], type: UTType) -> Data {
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        output,
        type.identifier as CFString,
        images.count,
        nil
    )!
    for image in images {
        CGImageDestinationAddImage(destination, image, nil)
    }
    CGImageDestinationFinalize(destination)
    return output as Data
}

private func rgba(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}
