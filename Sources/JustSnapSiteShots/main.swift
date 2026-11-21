// Renders the landing page's screenshots (site/public/shots/<name>-<locale>.png) from the app's real SwiftUI
// views over invented content, offscreen. It shows no window, activates nothing, captures no screen and reads
// no history, settings, Keychain or screenshots: a view is laid out in a hosting view that is never ordered onto
// the display and painted into a bitmap. See site/README.md for the command.
//
// Usage: JustSnapSiteShots <output-directory> [--scene <name>] [--locale zh|en]
//
// One process renders one language: the app reads the region (date and number formats) once, so a process that
// is started with a language's region renders that language only. Without --locale, this process starts one
// child per language, each with its own region and the UTC time zone, so the output does not depend on the
// settings of the Mac it runs on.
import AppKit
import Foundation
import JustSnapUI

let arguments = Array(CommandLine.arguments.dropFirst())
var outputPath: String?
var onlyScene: ShotScene?
var onlyLocale: ShotLocale?
var index = 0
while index < arguments.count {
    switch arguments[index] {
    case "--scene":
        index += 1
        guard index < arguments.count, let scene = ShotScene(rawValue: arguments[index]) else {
            FileHandle.standardError.write(Data("unknown scene\n".utf8))
            exit(2)
        }
        onlyScene = scene
    case "--locale":
        index += 1
        guard index < arguments.count, let locale = ShotLocale(rawValue: arguments[index]) else {
            FileHandle.standardError.write(Data("unknown locale\n".utf8))
            exit(2)
        }
        onlyLocale = locale
    case "-AppleLocale", "-AppleLanguages":
        // Region settings for this process, read by the system itself from the launch arguments
        index += 1
    default:
        outputPath = arguments[index]
    }
    index += 1
}
guard let outputPath else {
    FileHandle.standardError.write(Data("usage: JustSnapSiteShots <output-directory> [--scene <name>] [--locale zh|en]\n".utf8))
    exit(2)
}

guard let locale = onlyLocale else {
    // The parent: one child per language, each started with that language's region.
    guard let executable = Bundle.main.executableURL else { exit(1) }
    for locale in ShotLocale.allCases {
        let child = Process()
        child.executableURL = executable
        child.arguments = [outputPath, "--locale", locale.rawValue]
            + (onlyScene.map { ["--scene", $0.rawValue] } ?? [])
            + ["-AppleLocale", locale.regionIdentifier, "-AppleLanguages", "(\(locale.effectiveLanguage.rawValue))"]
        child.environment = ProcessInfo.processInfo.environment.merging(["TZ": "UTC"]) { _, new in new }
        do { try child.run() } catch {
            FileHandle.standardError.write(Data("could not start the renderer: \(error)\n".utf8))
            exit(1)
        }
        child.waitUntilExit()
        if child.terminationStatus != 0 { exit(child.terminationStatus) }
    }
    exit(0)
}

let outputDirectory = URL(fileURLWithPath: outputPath, isDirectory: true)

// No activation, no Dock icon, no window: an application object only so the views have a place to be laid out.
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
application.appearance = NSAppearance(named: .aqua)

do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    JustSnapLocalization.configure(effectiveLanguage: locale.effectiveLanguage)
    for scene in ShotScene.allCases where onlyScene == nil || onlyScene == scene {
        let png = try renderPNG(scene.view(locale), size: canvasSize)
        let file = outputDirectory.appendingPathComponent("\(scene.rawValue)-\(locale.rawValue).png")
        try png.write(to: file, options: .atomic)
        print("wrote \(file.path)")
    }
} catch {
    FileHandle.standardError.write(Data("failed: \(error)\n".utf8))
    exit(1)
}
