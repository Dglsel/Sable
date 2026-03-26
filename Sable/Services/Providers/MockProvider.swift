import Foundation

@MainActor
final class MockProvider: ChatProvider {
    nonisolated static let defaultID = "mock-provider"

    let id: String
    let displayName: String

    private var currentTask: Task<String, Error>?
    private var currentRequestID: UUID?

    init(id: String = MockProvider.defaultID, displayName: String = "Mock Provider") {
        self.id = id
        self.displayName = displayName
    }

    func sendMessage(_ message: String, context: Conversation) async throws -> String {
        currentTask?.cancel()

        let conversationTitle = context.title
        let previousMessageCount = context.messages.count
        let requestID = UUID()

        let task = Task<String, Error> {
            try await Task.sleep(for: .milliseconds(180))
            try Task.checkCancellation()

            return """
            \(displayName) mock reply

            Conversation: \(conversationTitle)
            Messages So Far: \(previousMessageCount)
            Prompt Preview: \(message)
            """
        }

        currentTask = task
        currentRequestID = requestID

        defer {
            if currentRequestID == requestID {
                currentTask = nil
                currentRequestID = nil
            }
        }

        return try await task.value
    }

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
}
