import AppKit
import SwiftUI

/// The pictures the screenshots are set in: a plain wallpaper, invented app windows and the freeze overlay.
/// All of it is drawn here; nothing comes from the machine the tool runs on.

/// What every screenshot is made of, in points, and what it is written out as, in pixels (16:9 both). The views are
/// laid out at 951x535 points and drawn into 1840x1035 pixels, 1.935 pixels to the point: the app's windows, which
/// have a minimum width of 920pt, then fit the frame with their lists inside it, and every shot is at the same scale.
let canvasSize = CGSize(width: 951, height: 535)
let outputPixels = (width: 1840, height: 1035)

enum Ink {
    static let page = Color.white
    static let text = Color(red: 0.13, green: 0.14, blue: 0.17)
    static let secondary = Color(red: 0.42, green: 0.44, blue: 0.49)
    static let faint = Color(red: 0.88, green: 0.89, blue: 0.91)
    static let accentSoft = Color(red: 0.82, green: 0.88, blue: 0.98)
    static let accent = Color(red: 0.25, green: 0.47, blue: 0.86)
}

struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.86, green: 0.90, blue: 0.96),
                Color(red: 0.93, green: 0.92, blue: 0.97),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// An invented window: rounded, shadowed, with the three traffic lights and a centered title.
struct FauxWindow<Content: View>: View {
    let title: String
    let size: CGSize
    var titleBarHeight: CGFloat = 28
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color(red: 0.95, green: 0.95, blue: 0.96)
                HStack(spacing: 7) {
                    ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                        Circle().fill($0).frame(width: 11, height: 11)
                    }
                    Spacer()
                }
                .padding(.leading, 12)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.secondary)
            }
            .frame(height: titleBarHeight)
            Divider()
            content()
                .frame(width: size.width, height: size.height - titleBarHeight - 1, alignment: .topLeading)
                .background(Ink.page)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.black.opacity(0.14), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
    }
}

/// The text of one invented page, set the way a reading app would.
struct FauxArticle: View {
    let heading: String
    let paragraphs: [String]
    var bullets: [String] = []
    var closing: [String] = []
    var headingSize: CGFloat = 22
    var bodySize: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(.system(size: headingSize, weight: .bold))
                .foregroundStyle(Ink.text)
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: bodySize))
                    .lineSpacing(4)
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(bullets.enumerated()), id: \.offset) { _, bullet in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").font(.system(size: bodySize))
                    Text(bullet)
                        .font(.system(size: bodySize))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Ink.text)
            }
            ForEach(Array(closing.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.system(size: bodySize))
                    .lineSpacing(4)
                    .foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// A small bar chart, for a page that is not all text.
struct FauxChart: View {
    var values: [CGFloat] = [0.35, 0.5, 0.42, 0.68, 0.6, 0.84]
    var height: CGFloat = 90

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == values.count - 1 ? Ink.accent : Ink.accentSoft)
                    .frame(width: 34, height: height * value)
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

/// The freeze overlay: the screen dimmed except for the selection, with the selection's border and, once it is
/// confirmed, its eight handles. The constants are CaptureOverlayView's (0.48 black, 1pt accent border, 7pt
/// handles); that view is private to the app and needs a live display, so it is redrawn here.
struct FreezeOverlay: View {
    let selection: CGRect?
    var showsHandles = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: canvasSize))
                if let selection { path.addRect(selection) }
            }
            .fill(Color.black.opacity(0.48), style: FillStyle(eoFill: true))
            if let selection {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: 1)
                    .frame(width: selection.width, height: selection.height)
                    .offset(x: selection.minX, y: selection.minY)
                if showsHandles {
                    ForEach(Array(Self.handleCenters(of: selection).enumerated()), id: \.offset) { _, center in
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(Rectangle().strokeBorder(Color.accentColor, lineWidth: 1))
                            .frame(width: 7, height: 7)
                            .offset(x: center.x - 3.5, y: center.y - 3.5)
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private static func handleCenters(of rect: CGRect) -> [CGPoint] {
        let xs = [rect.minX, rect.midX, rect.maxX]
        let ys = [rect.minY, rect.midY, rect.maxY]
        return ys.flatMap { y in xs.compactMap { x in (x == rect.midX && y == rect.midY) ? nil : CGPoint(x: x, y: y) } }
    }
}

/// The pointer while a region is dragged out.
struct CrosshairCursor: View {
    var body: some View {
        ZStack {
            Rectangle().frame(width: 1.5, height: 19)
            Rectangle().frame(width: 19, height: 1.5)
        }
        .foregroundStyle(Color.white)
        .shadow(color: .black, radius: 0.6)
        .shadow(color: .black.opacity(0.7), radius: 0.6)
    }
}

/// The menu bar of the invented screen, with the app's status item.
struct FauxMenuBar: View {
    let statusItemX: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white.opacity(0.72)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.12))
                .frame(width: 26, height: 20)
                .offset(x: statusItemX - 13, y: 2)
            Image(systemName: "viewfinder")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Ink.text)
                .offset(x: statusItemX - 6, y: 5)
        }
        .frame(width: canvasSize.width, height: 24, alignment: .topLeading)
    }
}

/// The window's rows are tinted lines, for a window that only has to look busy.
struct FauxLines: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: 8) {
                    Circle().stroke(Ink.secondary.opacity(0.7), lineWidth: 1).frame(width: 11, height: 11)
                    Text(line).font(.system(size: 13)).foregroundStyle(Ink.text)
                }
            }
        }
    }
}
