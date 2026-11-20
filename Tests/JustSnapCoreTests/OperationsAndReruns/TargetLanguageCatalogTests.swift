import Testing
@testable import JustSnapCore

@Suite("Target language catalog")
struct TargetLanguageCatalogTests {
    @Test("the catalog is exactly the 11 common languages in their fixed order")
    func catalogIsTheElevenCommonLanguages() {
        #expect(
            TargetLanguageCatalog.standard.codes == [
                "zh-Hans", "en", "ja", "ko", "es", "fr",
                "de", "pt", "it", "ru", "ar",
            ]
        )
    }

    @Test("an abbreviation is the upper-case primary language code")
    func abbreviationUsesPrimaryCode() {
        #expect(TargetLanguageCatalog.abbreviation(for: "zh-Hans") == "ZH")
        #expect(TargetLanguageCatalog.abbreviation(for: "en") == "EN")
        #expect(TargetLanguageCatalog.abbreviation(for: "aeb") == "AEB")
    }

    @Test("every language in the catalog has its own short abbreviation")
    func catalogAbbreviationsAreUniqueAndShort() {
        let codes = TargetLanguageCatalog.standard.codes
        let abbreviations = codes.map(TargetLanguageCatalog.abbreviation(for:))

        #expect(Set(abbreviations).count == codes.count)
        #expect(abbreviations.allSatisfy { (2...3).contains($0.count) && $0 == $0.uppercased() })
    }

    @Test("traditional Chinese, other languages and free-form values are unavailable")
    func excludesTraditionalChineseAndUnknownValues() {
        let catalog = TargetLanguageCatalog.standard

        #expect(catalog.contains("zh-Hans"))
        #expect(!catalog.contains("zh"))
        #expect(!catalog.contains("zh-Hant"))
        #expect(!catalog.contains("pl"))
        #expect(!catalog.contains("custom-language"))
    }
}
