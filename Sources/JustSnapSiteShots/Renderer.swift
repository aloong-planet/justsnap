import AppKit
import SwiftUI

enum RenderError: Error, CustomStringConvertible {
    case noBitmap
    case noPNG

    var description: String {
        switch self {
        case .noBitmap: "could not allocate the bitmap"
        case .noPNG: "could not encode the PNG"
        }
    }
}

/// Renders a view offscreen into PNG data of `outputPixels`: the view sits in a hosting view whose window is never ordered
/// onto the screen, and the hosting view paints into a bitmap of our own. Nothing is captured from the display.
@MainActor
func renderPNG<V: View>(_ view: V, size: CGSize) throws -> Data {
    let root = view
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    let hosting = NSHostingView(rootView: root)
    hosting.frame = CGRect(origin: .zero, size: size)
    hosting.appearance = NSAppearance(named: .aqua)
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size),
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )
    window.appearance = NSAppearance(named: .aqua)
    window.contentView = hosting
    settle(hosting)

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: outputPixels.width,
        pixelsHigh: outputPixels.height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw RenderError.noBitmap }
    bitmap.size = size
    hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    // The bitmap is painted in the generic RGB space; the file is tagged sRGB, which is what browsers assume.
    guard let srgb = bitmap.converting(to: .sRGB, renderingIntent: .default),
          let png = srgb.representation(using: .png, properties: [:]) else { throw RenderError.noPNG }
    return png
}

/// Lets SwiftUI and the AppKit views inside it finish layout and first text before the picture is taken. The run
/// loop is turned a few times with no window on screen; only the hosting view's layout is being waited for.
@MainActor
private func settle(_ hosting: NSHostingView<some View>) {
    for _ in 0..<6 {
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
}
