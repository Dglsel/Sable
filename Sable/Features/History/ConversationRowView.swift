import SwiftUI

struct ConversationRowView: View {
    @Environment(\.colorScheme) private var colorScheme

    let conversation: Conversation
    var isSelected: Bool = false
    var isHovered: Bool = false
    var onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title + timestamp / delete button
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(conversation.title)
                    .font(isSelected ? SableTypography.labelSmallMedium : SableTypography.labelSmall)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                // Timestamp fades out on hover; delete icon fades in — same slot, no overlap
                ZStack(alignment: .trailing) {
                    Text(relativeTimestamp)
                        .font(SableTypography.micro)
                        .foregroundStyle(tertiaryColor)
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                        .opacity(isHovered ? 0 : 1)

                    if isHovered, let onDelete {
                        Button {
                            onDelete()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(deleteIconColor)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .animation(SableAnimation.move(duration: SableAnimation.fast), value: isHovered)
            }

            // Preview of last message
            if !previewText.isEmpty {
                Text(previewText)
                    .font(SableTypography.micro)
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(width: SidebarLayoutMetrics.rowContentWidth, alignment: .leading)
    }

    // MARK: - Preview

    private var previewText: String {
        let text = conversation.previewText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(80))
    }

    // MARK: - Colors

    private var titleColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.92)
                : Color.black.opacity(0.85)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.72)
            : Color.black.opacity(0.65)
    }

    private var subtitleColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.38)
                : Color.black.opacity(0.35)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.28)
            : Color.black.opacity(0.25)
    }

    private var tertiaryColor: Color {
        if isSelected {
            return colorScheme == .dark
                ? Color.white.opacity(0.32)
                : Color.black.opacity(0.28)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.20)
            : Color.black.opacity(0.18)
    }

    private var deleteIconColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.45)
            : Color.black.opacity(0.35)
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: conversation.updatedAt, relativeTo: .now)
    }
}
