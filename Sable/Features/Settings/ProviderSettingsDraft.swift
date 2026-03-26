import Foundation

struct ProviderSettingsDraft: Equatable {
    var isEnabled: Bool
    var apiKey: String
    var baseURL: String
    var defaultModel: String

    init(
        isEnabled: Bool,
        apiKey: String,
        baseURL: String,
        defaultModel: String
    ) {
        self.isEnabled = isEnabled
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.defaultModel = defaultModel
    }

    init(setting: ProviderSettings, apiKey: String) {
        self.init(
            isEnabled: setting.isEnabled,
            apiKey: apiKey,
            baseURL: setting.baseURL,
            defaultModel: setting.defaultModel
        )
    }

    var normalizedAPIKey: String {
        apiKey.removingWhitespaceAndNewlines
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDefaultModel: String {
        defaultModel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasUsableAPIKey: Bool {
        !normalizedAPIKey.isEmpty
    }

    var hasValidBaseURL: Bool {
        ProviderRequestSupport.validatedBaseURL(trimmedBaseURL) != nil
    }

    var isModelSelectionEnabled: Bool {
        isEnabled && hasUsableAPIKey && hasValidBaseURL
    }
}
