import Foundation

/// Built-in model rules shipped with the signed app (ADR-0017): which listed Gemini
/// and OpenAI models are offered and how their requests keep thinking low.
enum ProviderModelRules {
    struct OpenAISetting: Equatable, Sendable {
        /// `nil` means the request sends no `reasoning` object.
        let reasoningEffort: String?
        let sendsTemperature: Bool
    }

    static func isOffered(provider: ProviderID, modelID: String) -> Bool {
        switch provider {
        case .gemini:
            return isOfferedGeminiModel(modelID)
        case .openAI:
            return openAISetting(modelID: modelID) != nil
        case .deepSeek:
            // DeepSeek models are filtered by the modalities in their list (ADR-0011).
            return true
        }
    }

    static func geminiThinkingLevel(modelID: String) -> String? {
        guard isOfferedGeminiModel(modelID), !modelID.hasPrefix("gemini-2.") else {
            return nil
        }
        return "low"
    }

    /// The setting for an offered OpenAI model; a dated snapshot `<id>-YYYY-MM-DD`
    /// takes its alias's setting. `nil` for a model the app does not offer.
    static func openAISetting(modelID: String) -> OpenAISetting? {
        let alias = modelID.wholeMatch(of: /(.+)-[0-9]{4}-[0-9]{2}-[0-9]{2}/).map { String($0.1) }
        return openAISettings[alias ?? modelID]
    }

    private static let geminiLatestAliases: Set<String> = [
        "gemini-flash-latest",
        "gemini-flash-lite-latest",
        "gemini-pro-latest",
    ]

    private static let geminiNonTextMarkers = [
        "tts", "image", "transcribe", "customtools", "computer-use",
    ]

    private static func isOfferedGeminiModel(_ modelID: String) -> Bool {
        let isVersionedOrAlias = modelID.prefixMatch(of: /gemini-[0-9]+(\.[0-9]+)?-/) != nil
            || geminiLatestAliases.contains(modelID)
        return isVersionedOrAlias
            && !geminiNonTextMarkers.contains { modelID.contains($0) }
    }

    private static let openAISettings: [String: OpenAISetting] = {
        let effortNone = OpenAISetting(reasoningEffort: "none", sendsTemperature: true)
        let effortMinimal = OpenAISetting(reasoningEffort: "minimal", sendsTemperature: false)
        let effortLow = OpenAISetting(reasoningEffort: "low", sendsTemperature: false)
        let nonReasoning = OpenAISetting(reasoningEffort: nil, sendsTemperature: true)
        var settings: [String: OpenAISetting] = [:]
        for id in [
            "gpt-5.1", "gpt-5.2", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.5",
            "gpt-5.6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-6-luna", "gpt-6-sol", "gpt-6.1-terra",
        ] {
            settings[id] = effortNone
        }
        settings["gpt-5"] = effortMinimal
        for id in ["gpt-6-astra", "gpt-6.1-sol"] {
            settings[id] = effortLow
        }
        for id in ["gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini"] {
            settings[id] = nonReasoning
        }
        return settings
    }()
}
