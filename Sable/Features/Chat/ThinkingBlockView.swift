import SwiftUI

/// Collapsible block that displays a model's reasoning/thinking process.
/// Collapsed by default — shows a single-line summary. Expands to reveal full content.
struct ThinkingBlockView: View {
    let content: String
    @State private var isExpanded = false

    private var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    private var preview: String {
        let firstLine = content.prefix(while: { $0 != "\n" })
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 80 {
            return String(trimmed.prefix(80)) + "…"
        }
        return String(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — always visible, acts as toggle
            Button {
                withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))

                    Image(systemName: "brain")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(isExpanded ? "Thinking" : preview)
                        .font(SableTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                Text(content)
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 15)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                .fill(SableTheme.bgHover.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                .stroke(SableTheme.border.opacity(0.5))
        )
    }
}
