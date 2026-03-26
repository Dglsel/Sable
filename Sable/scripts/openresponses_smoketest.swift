import Foundation
import os

@main
struct OpenResponsesSmokeTest {
    static func main() async throws {
        let service = await OpenResponsesService()
        let stream = try await service.sendMessage(
            "hello from OpenResponses smoke test",
            model: "moonshot/kimi-k2.5",
            conversationId: UUID().uuidString,
            stream: true
        )

        var sawEvent = false

        for await event in stream {
            sawEvent = true
            switch event {
            case .delta(let text):
                print("DELTA:", text)
            case .completed(let text, let usage):
                print("COMPLETED:", text)
                if let usage {
                    print("USAGE:", usage.inputTokens ?? -1, usage.outputTokens ?? -1)
                }
            case .error(let message):
                print("ERROR:", message)
            }
        }

        if !sawEvent {
            print("NO_EVENTS")
        }
    }
}
