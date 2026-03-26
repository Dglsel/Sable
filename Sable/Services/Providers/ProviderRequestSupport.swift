import Foundation

struct ProviderRequestMessage: Equatable {
    let role: MessageRole
    let content: String
}

enum ProviderRequestSupport {
    static func requestMessages(
        from context: Conversation,
        latestMessage: String
    ) -> [ProviderRequestMessage] {
        let sortedMessages = context.messages.sorted { $0.createdAt < $1.createdAt }
        var requestMessages: [ProviderRequestMessage] = sortedMessages.compactMap { message in
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else {
                return nil
            }

            return ProviderRequestMessage(role: message.role, content: content)
        }

        let trimmedLatestMessage = latestMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        if requestMessages.isEmpty {
            if !trimmedLatestMessage.isEmpty {
                requestMessages.append(ProviderRequestMessage(role: .user, content: trimmedLatestMessage))
            }
            return requestMessages
        }

        if requestMessages.last?.role != .user || requestMessages.last?.content != trimmedLatestMessage {
            if !trimmedLatestMessage.isEmpty {
                requestMessages.append(ProviderRequestMessage(role: .user, content: trimmedLatestMessage))
            }
        }

        return requestMessages
    }

    static func systemPrompt(from messages: [ProviderRequestMessage]) -> String? {
        let prompt = messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return prompt.isEmpty ? nil : prompt
    }

    static func validatedBaseURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host?.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.isEmpty else {
            return nil
        }

        return components.url
    }

    static func simulatedReply(providerName: String, latestMessage: String) -> String {
        """
        \(providerName) placeholder reply

        Prompt Preview: \(latestMessage)
        Status: Real API integration is not connected yet.
        """
    }
}
