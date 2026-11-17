import Foundation

public struct ProviderHTTPResponse: Sendable {
    public let data: Data
    public let statusCode: Int

    public init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

public protocol ProviderHTTPDataLoading: Sendable {
    func data(for request: URLRequest) async throws -> ProviderHTTPResponse
}

public struct URLSessionProviderHTTPDataLoader: ProviderHTTPDataLoading {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> ProviderHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderModelListError.invalidResponse
        }
        return ProviderHTTPResponse(data: data, statusCode: httpResponse.statusCode)
    }
}

public enum ProviderModelListError: Error, Equatable {
    case authenticationRejected
    case requestRejected(statusCode: Int)
    case invalidResponse
    case paginationCycle
}

public struct OfficialProviderModelLister: ProviderModelListing {
    private let httpLoader: any ProviderHTTPDataLoading

    public init(httpLoader: any ProviderHTTPDataLoading = URLSessionProviderHTTPDataLoader()) {
        self.httpLoader = httpLoader
    }

    public func listModels(provider: ProviderID, apiKey: String) async throws -> [String] {
        if provider != .gemini {
            return try await listOpenAICompatibleModels(provider: provider, apiKey: apiKey)
        }
        var models: [GeminiModel] = []
        var pageToken: String?
        var followedTokens = Set<String>()
        repeat {
            if let pageToken, !followedTokens.insert(pageToken).inserted {
                throw ProviderModelListError.paginationCycle
            }
            var components = URLComponents(
                string: "https://generativelanguage.googleapis.com/v1beta/models"
            )
            var queryItems = [URLQueryItem(name: "pageSize", value: "1000")]
            if let pageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            components?.queryItems = queryItems
            guard let url = components?.url else {
                throw ProviderModelListError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let response = try await httpLoader.data(for: request)
            try Self.validateStatus(response.statusCode)
            let page: GeminiModelPage
            do {
                page = try JSONDecoder().decode(GeminiModelPage.self, from: response.data)
            } catch {
                throw ProviderModelListError.invalidResponse
            }
            guard page.models.allSatisfy({ !$0.id.isEmpty }) else {
                throw ProviderModelListError.invalidResponse
            }
            models.append(contentsOf: page.models)
            pageToken = page.nextPageToken
        } while pageToken != nil
        // v1-core::REQ-016/AC-02: the app streams with generateContent, which Live API
        // models, listing only bidiGenerateContent, do not serve.
        return models.filter { $0.supportedGenerationMethods?.contains("generateContent") == true }
            .map(\.id)
    }

    private func listOpenAICompatibleModels(
        provider: ProviderID,
        apiKey: String
    ) async throws -> [String] {
        let urlString: String
        switch provider {
        case .openAI:
            urlString = "https://api.openai.com/v1/models"
        case .deepSeek:
            urlString = "https://api.deepseek.com/models"
        case .gemini:
            throw ProviderModelListError.invalidResponse
        }
        guard let url = URL(string: urlString) else {
            throw ProviderModelListError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let response = try await httpLoader.data(for: request)
        try Self.validateStatus(response.statusCode)
        let page: OpenAICompatibleModelPage
        do {
            page = try JSONDecoder().decode(OpenAICompatibleModelPage.self, from: response.data)
        } catch {
            throw ProviderModelListError.invalidResponse
        }
        guard page.data.allSatisfy({ !$0.id.isEmpty }) else {
            throw ProviderModelListError.invalidResponse
        }
        guard provider == .deepSeek else {
            return page.data.map(\.id)
        }
        // v1-core::REQ-016/AC-01: DeepSeek offers only models that take images and return text.
        return page.data.filter { model in
            model.inputModalities?.contains("image") == true
                && model.outputModalities?.contains("text") == true
        }.map(\.id)
    }

    private static func validateStatus(_ statusCode: Int) throws {
        if statusCode == 401 || statusCode == 403 {
            throw ProviderModelListError.authenticationRejected
        }
        guard (200..<300).contains(statusCode) else {
            throw ProviderModelListError.requestRejected(statusCode: statusCode)
        }
    }
}

private struct GeminiModelPage: Decodable {
    let models: [GeminiModel]
    let nextPageToken: String?
}

private struct GeminiModel: Decodable {
    let name: String
    let supportedGenerationMethods: [String]?

    var id: String {
        name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name
    }
}

private struct OpenAICompatibleModelPage: Decodable {
    let data: [OpenAICompatibleModel]
}

private struct OpenAICompatibleModel: Decodable {
    let id: String
    let inputModalities: [String]?
    let outputModalities: [String]?

    private enum CodingKeys: String, CodingKey {
        case id
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
    }
}
