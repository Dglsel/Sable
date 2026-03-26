import Foundation
import SwiftData

enum ProviderSettingsSaveIssue: Equatable {
    case missingAPIKey
    case invalidBaseURL
    case missingDefaultModel
    case saveFailed

    var message: String {
        switch self {
        case .missingAPIKey:
            L10n.string("settings.providers.error.apiKeyMissing", default: "API Key is missing.")
        case .invalidBaseURL:
            L10n.string("settings.providers.error.baseURLInvalid", default: "Base URL is invalid.")
        case .missingDefaultModel:
            L10n.string("settings.providers.error.modelMissing", default: "Default model is missing.")
        case .saveFailed:
            L10n.string("settings.providers.error.saveFailed", default: "Settings could not be saved.")
        }
    }
}

enum ProviderSettingsSaveStatus: Equatable {
    case idle
    case saved
    case failure(ProviderSettingsSaveIssue)

    var isSuccess: Bool {
        if case .saved = self {
            return true
        }

        return false
    }

    var message: String? {
        switch self {
        case .idle:
            nil
        case .saved:
            L10n.string("settings.providers.saved", default: "Saved")
        case .failure(let issue):
            issue.message
        }
    }
}

@MainActor
struct ProviderSettingsSaver {
    typealias APIKeyWriter = (_ value: String, _ account: String) -> Void

    private let saveAPIKey: APIKeyWriter

    init(saveAPIKey: @escaping APIKeyWriter) {
        self.saveAPIKey = saveAPIKey
    }

    func save(
        draft: ProviderSettingsDraft,
        for setting: ProviderSettings,
        modelContext: ModelContext
    ) -> ProviderSettingsSaveStatus {
        if draft.isEnabled {
            if draft.normalizedAPIKey.isEmpty {
                return .failure(.missingAPIKey)
            }

            if draft.trimmedDefaultModel.isEmpty {
                return .failure(.missingDefaultModel)
            }

            let baseURL = draft.trimmedBaseURL
            if !Self.isValidBaseURL(baseURL) {
                return .failure(.invalidBaseURL)
            }
        }

        setting.isEnabled = draft.isEnabled
        setting.baseURL = draft.trimmedBaseURL
        setting.defaultModel = draft.trimmedDefaultModel
        saveAPIKey(draft.normalizedAPIKey, setting.apiKeyReference)

        do {
            try modelContext.save()
            return .saved
        } catch {
            return .failure(.saveFailed)
        }
    }

    /// Persists credentials (API key, base URL, toggle) without requiring a model selection.
    /// Used for auto-save to enable model discovery before the user picks a model.
    func persistCredentials(
        draft: ProviderSettingsDraft,
        for setting: ProviderSettings,
        modelContext: ModelContext
    ) -> Bool {
        setting.isEnabled = draft.isEnabled
        setting.baseURL = draft.trimmedBaseURL
        if !draft.trimmedDefaultModel.isEmpty {
            setting.defaultModel = draft.trimmedDefaultModel
        }
        saveAPIKey(draft.normalizedAPIKey, setting.apiKeyReference)

        do {
            try modelContext.save()
            return true
        } catch {
            return false
        }
    }

    private nonisolated static func isValidBaseURL(_ value: String) -> Bool {
        guard !value.isEmpty,
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return false
        }

        return true
    }
}
