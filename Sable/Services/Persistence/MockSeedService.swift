import Foundation
import SwiftData

enum MockSeedService {
    static func seedIfNeeded(in context: ModelContext) {
        let settingsCount = (try? context.fetchCount(FetchDescriptor<AppSettings>())) ?? 0
        let conversationCount = (try? context.fetchCount(FetchDescriptor<Conversation>())) ?? 0
        let providerCount = (try? context.fetchCount(FetchDescriptor<ProviderSettings>())) ?? 0

        if settingsCount == 0 {
            context.insert(AppSettings())
        }

        if providerCount == 0 {
            for definition in ProviderRegistry.all {
                context.insert(
                    ProviderSettings(
                        provider: definition.kind,
                        isEnabled: definition.kind == .openAI || definition.kind == .anthropic || definition.kind == .gemini,
                        apiKeyReference: "provider.\(definition.kind.rawValue).apiKey",
                        baseURL: definition.defaultBaseURL,
                        defaultModel: definition.defaultModel
                    )
                )
            }
        }

        if conversationCount == 0 {
            let welcomeConversation = Conversation(title: "Welcome to Sable")
            let welcomeMessages = [
                Message(
                    role: .assistant,
                    content: "Sable is ready with a clean macOS shell, bilingual UI, and mock providers.",
                    replyLanguage: .english,
                    conversation: welcomeConversation
                ),
                Message(
                    role: .user,
                    content: "Show me a calm, native chat layout first.",
                    replyLanguage: .english,
                    conversation: welcomeConversation
                ),
                Message(
                    role: .assistant,
                    content: "The first pass keeps the interface quiet: sidebar, toolbar, conversation stream, input bar, and a restrained menu bar panel.",
                    replyLanguage: .english,
                    conversation: welcomeConversation
                )
            ]
            welcomeConversation.messages = welcomeMessages
            welcomeConversation.updatedAt = Date().addingTimeInterval(-120)

            let bilingualConversation = Conversation(title: "中英切换示例")
            let bilingualMessages = [
                Message(
                    role: .user,
                    content: "界面中文，回复英文也要支持。",
                    replyLanguage: .english,
                    conversation: bilingualConversation
                ),
                Message(
                    role: .assistant,
                    content: "已作为首版默认能力保留，界面语言和回复语言完全分离。",
                    replyLanguage: .english,
                    conversation: bilingualConversation
                )
            ]
            bilingualConversation.messages = bilingualMessages
            bilingualConversation.updatedAt = Date().addingTimeInterval(-600)

            [welcomeConversation, bilingualConversation].forEach(context.insert)
            welcomeMessages.forEach(context.insert)
            bilingualMessages.forEach(context.insert)
        }

        try? context.save()
    }
}
