import SwiftUI

/// Subtle metadata line below assistant messages.
/// Shows response duration, model name, token count when available.
/// L3 information layer — tertiary visual weight.
struct MessageStatusView: View {
    let metadata: ResponseMetadata

    @State private var isVisible = false

    /// Only delay-animate for messages created in the last 3 seconds (fresh replies).
    /// Historical messages show metadata instantly.
    private var isFreshReply: Bool {
        metadata.durationMs != nil
    }

    var body: some View {
        HStack(spacing: 4) {
            if let model = metadata.modelName, !model.isEmpty {
                Text(model)
            }

            if let ms = metadata.durationMs {
                if metadata.modelName != nil {
                    Text("·")
                }
                Text(formatDuration(ms))
            }

            if let tokens = metadata.tokenCount {
                Text("·")
                Text("\(tokens) tokens")
            }
        }
        .font(SableTypography.micro)
        .foregroundStyle(.secondary.opacity(0.65))
        .padding(.leading, 34)
        .padding(.top, 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 4)
        .onAppear {
            if isFreshReply {
                // Delay so message content settles first, then metadata rises in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                        isVisible = true
                    }
                }
            } else {
                isVisible = true
            }
        }
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        }
        let seconds = Double(ms) / 1000.0
        return String(format: "%.1fs", seconds)
    }
}
