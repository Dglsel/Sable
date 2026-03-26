import SwiftUI

/// Renders a structured error with human-readable summary,
/// optional suggested action, collapsible technical detail, and retry button.
struct ErrorBlockView: View {
    let block: ErrorBlock
    var onRetry: (() -> Void)?

    @State private var isDetailExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // L1: Human-readable summary
            Text(block.summary)
                .font(SableTypography.labelSmallMedium)
                .foregroundStyle(.primary.opacity(0.75))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // L2: Technical detail (progressive disclosure)
            if let detail = block.technicalDetail, !detail.isEmpty {
                Button {
                    withAnimation(SableAnimation.move()) {
                        isDetailExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isDetailExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Technical Detail")
                            .font(SableTypography.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                if isDetailExpanded {
                    Text(detail)
                        .font(SableTypography.mono)
                        .foregroundStyle(.tertiary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // L4: Retry action
            if block.isRetryable, let onRetry {
                Button {
                    onRetry()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Retry")
                            .font(SableTypography.labelSmallMedium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                            .fill(SableTheme.bgHover)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
