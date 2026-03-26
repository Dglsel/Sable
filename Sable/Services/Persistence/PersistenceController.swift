import Foundation
import SwiftData

struct PersistenceController {
    let modelContainer: ModelContainer

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)

        do {
            modelContainer = try ModelContainer(
                for: Conversation.self,
                Message.self,
                AppSettings.self,
                ProviderSettings.self,
                configurations: configuration
            )
        } catch {
            fatalError("Unable to create ModelContainer: \(error.localizedDescription)")
        }
    }
}
