import Foundation

struct ProviderRuntimeConfiguration: Sendable {
    let isEnabled: Bool
    let apiKey: String
    let baseURL: String
    let model: String

    static func disabled(baseURL: String, model: String) -> ProviderRuntimeConfiguration {
        ProviderRuntimeConfiguration(
            isEnabled: false,
            apiKey: "",
            baseURL: baseURL,
            model: model
        )
    }
}
