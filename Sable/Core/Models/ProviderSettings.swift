import Foundation
import SwiftData

@Model
final class ProviderSettings {
    @Attribute(.unique) var id: UUID
    var providerRawValue: String
    var isEnabled: Bool
    var apiKeyReference: String
    var baseURL: String
    var defaultModel: String

    init(
        id: UUID = UUID(),
        provider: ProviderKind,
        isEnabled: Bool = false,
        apiKeyReference: String = "",
        baseURL: String = "",
        defaultModel: String = ""
    ) {
        self.id = id
        self.providerRawValue = provider.rawValue
        self.isEnabled = isEnabled
        self.apiKeyReference = apiKeyReference
        self.baseURL = baseURL
        self.defaultModel = defaultModel
    }

    var provider: ProviderKind {
        get { ProviderKind(rawValue: providerRawValue) ?? .openAI }
        set { providerRawValue = newValue.rawValue }
    }
}
