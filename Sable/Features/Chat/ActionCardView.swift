import SwiftUI

/// Renders a tool/skill invocation as a compact card.
/// Default: collapsed (tool name + status + input summary).
/// Expanded: full output with progressive disclosure.
struct ActionCardView: View {
    let block: ToolCallBlock

    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: tool name + status + duration
            headerRow

            // Input summary
            if let input = block.input, !input.isEmpty {
                Text(input)
                    .font(SableTypography.codeBlock)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: isExpanded)
                    .padding(.top, 4)
                    .padding(.horizontal, 10)
            }

            // Expandable output
            if let output = block.output, !output.isEmpty {
                if isExpanded {
                    outputSection(output)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    expandButton(lineCount: output.components(separatedBy: "\n").count)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 6) {
            statusIcon
                .font(.system(size: 11, weight: .semibold))

            Text(block.toolName)
                .font(SableTypography.labelSmallMedium)
                .foregroundStyle(.primary.opacity(0.7))

            Spacer(minLength: 0)

            if let ms = block.durationMs {
                Text(formatDuration(ms))
                    .font(SableTypography.mono)
                    .foregroundStyle(.tertiary)
            }

            statusBadge
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusIcon: some View {
        switch block.status {
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .success:
            Image(systemName: "checkmark")
                .foregroundStyle(SableTheme.success.opacity(0.7))
        case .failed:
            Image(systemName: "xmark")
                .foregroundStyle(SableTheme.error.opacity(0.7))
        case .pendingApproval:
            Image(systemName: "hand.raised")
                .foregroundStyle(SableTheme.warning.opacity(0.7))
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch block.status {
        case .running:
            Text("Running")
                .font(SableTypography.microMedium)
                .foregroundStyle(SableTheme.info)
        case .success:
            EmptyView()
        case .failed:
            Text("Failed")
                .font(SableTypography.microMedium)
                .foregroundStyle(SableTheme.error.opacity(0.7))
        case .pendingApproval:
            Text("Approval")
                .font(SableTypography.microMedium)
                .foregroundStyle(SableTheme.warning.opacity(0.7))
        }
    }

    // MARK: - Output

    private func expandButton(lineCount: Int) -> some View {
        Button {
            withAnimation(SableAnimation.move()) {
                isExpanded = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text("Show output (\(lineCount) lines)")
                    .font(SableTypography.caption)
            }
            .foregroundStyle(.tertiary)
            .padding(.top, 6)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }

    private func outputSection(_ output: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(SableAnimation.move()) {
                    isExpanded = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Hide output")
                        .font(SableTypography.caption)
                }
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)

            Text(output)
                .font(SableTypography.mono)
                .foregroundStyle(.secondary.opacity(0.8))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
            .fill(SableTheme.bgHover)
    }

    private var borderColor: Color {
        SableTheme.border
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms < 1000 {
            return "\(ms)ms"
        }
        let seconds = Double(ms) / 1000.0
        return String(format: "%.1fs", seconds)
    }
}
