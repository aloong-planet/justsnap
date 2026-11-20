import Foundation

public struct TargetLanguageCatalog: Equatable, Sendable {
    public static let priorityCodes = [
        "zh-Hans", "en", "ja", "ko", "es", "fr",
        "de", "pt", "it", "ru", "ar",
    ]

    /// The only languages a user can translate into (v1-core §5).
    public static let standard = TargetLanguageCatalog(codes: priorityCodes)

    public let codes: [String]

    public init(codes: [String]) {
        self.codes = codes
    }

    public func contains(_ code: String) -> Bool {
        codes.contains(code)
    }

    /// What the capture toolbar shows for a language: its primary language code in upper case, such as
    /// `ZH` for `zh-Hans` (v1-core::REQ-013/AC-03). Codes stay the runtime and stored values.
    public static func abbreviation(for code: String) -> String {
        String(code.prefix { $0 != "-" }).uppercased()
    }
}
