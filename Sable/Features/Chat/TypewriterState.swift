import SwiftUI

/// Holds the typewriter display state for the currently streaming message.
/// As an @Observable class, SwiftUI views that read its properties will
/// automatically re-render when they change.
@MainActor
@Observable
final class TypewriterState {
    /// The text currently shown on screen (grows character by character).
    var displayedText: String = ""
    /// The ID of the message being animated. nil = no active streaming.
    var activeMessageID: UUID? = nil

    private var tickTask: Task<Void, Never>?
    private var fullText: String = ""
    private let charsPerTick = 3

    /// Called when a new streaming message begins.
    func start(messageID: UUID) {
        stop()
        activeMessageID = messageID
        displayedText = ""
        fullText = ""
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let full = self.fullText
                let shown = self.displayedText
                if shown.count < full.count {
                    let target = min(shown.count + self.charsPerTick, full.count)
                    let end = full.index(full.startIndex, offsetBy: target)
                    self.displayedText = String(full[..<end])
                }
                try? await Task.sleep(for: .seconds(1.0 / 60.0))
            }
        }
    }

    /// Called on every delta — updates the target text for the typewriter.
    func feed(_ text: String) {
        fullText = text
    }

    /// Called when streaming ends — flush remaining text and clean up.
    func finish(finalText: String) {
        fullText = finalText
        // Give the tick task a moment to flush, then force-complete
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else { return }
            self.displayedText = self.fullText
            self.stop()
            self.activeMessageID = nil
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }
}
