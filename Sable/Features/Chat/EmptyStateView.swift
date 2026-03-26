import SwiftUI

struct EmptyStateView: View {
    let onCreateConversation: () -> Void

    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(SableTheme.bgActive)
                        .frame(width: 52, height: 52)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(SableTheme.interactive)
                }
                .scaleEffect(appeared ? 1.0 : 0.7)
                .opacity(appeared ? 1.0 : 0)

                // Title + subtitle
                VStack(spacing: 8) {
                    Text(L10n.string("chat.empty.title", default: "Start a conversation"))
                        .font(SableTypography.displayTitle)
                        .foregroundStyle(.primary)

                    Text(L10n.string("chat.empty.subtitle", default: "Choose a recent conversation or start a new one."))
                        .font(SableTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                        .lineSpacing(3)
                }
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 6)

                // New Chat button — understated, not prominently styled
                Button(action: onCreateConversation) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .medium))
                        Text(L10n.string("sidebar.newConversation", default: "New Chat"))
                            .font(SableTypography.labelMedium)
                    }
                    .foregroundStyle(.primary.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                            .fill(SableTheme.bgHover)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                            .strokeBorder(SableTheme.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SableTheme.chatBackground)
        .onAppear {
            withAnimation(SableAnimation.springGentle.delay(0.05)) {
                appeared = true
            }
        }
    }
}
