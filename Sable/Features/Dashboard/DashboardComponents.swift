import SwiftUI

// MARK: - Copy Button

/// Unified copy-to-clipboard button. `.inline` shows icon-only; `.labeled` shows icon + text.
struct CopyButton: View {
    let text: String
    var style: Style = .inline

    enum Style {
        case inline   // icon-only, for embedding in code blocks
        case labeled  // icon + "Copy"/"Copied!" text
    }

    @State private var copied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(style == .inline ? 1.5 : 2))
                copied = false
            }
        } label: {
            switch style {
            case .inline:
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(copied ? SableTheme.success : .secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            case .labeled:
                Label(
                    copied ? "Copied!" : "Copy",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dashboard Control Button

/// Hover-aware control button with consistent visual language.
/// Primary variant has a resting background; secondary is transparent until hovered.
struct DashboardControlButton: View {
    let label: String
    let icon: String
    var isLoading: Bool = false
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: icon)
                }
                Text(label)
            }
            .font(SableTypography.labelSmall)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var foregroundColor: Color {
        if !isEnabled { return Color.secondary.opacity(0.5) }
        if isPrimary { return isHovered ? .primary : Color.primary.opacity(0.85) }
        return isHovered ? .primary : .secondary
    }

    private var backgroundColor: Color {
        if isPrimary {
            return isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)
        }
        return isHovered ? Color.primary.opacity(0.06) : .clear
    }

    private var borderColor: Color {
        if isPrimary {
            return Color.primary.opacity(isHovered ? 0.12 : 0.08)
        }
        return isHovered ? Color.primary.opacity(0.08) : .clear
    }
}

// MARK: - Secondary Action Link

/// Text-only action link for secondary dashboard operations.
/// No chrome, no background — just text that highlights on hover.
struct SecondaryActionLink: View {
    let label: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text(label)
            }
            .font(SableTypography.labelSmall)
            .foregroundStyle(textColor)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var textColor: Color {
        if !isEnabled { return Color.secondary.opacity(0.4) }
        return isHovered ? Color.primary : Color.secondary
    }
}
