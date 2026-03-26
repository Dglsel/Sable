import Foundation

@MainActor
protocol ChatProvider: AnyObject {
    var id: String { get }
    var displayName: String { get }

    func sendMessage(_ message: String, context: Conversation) async throws -> String
    func cancelCurrentRequest()
}
