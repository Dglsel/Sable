import SwiftUI

enum ChatSurfaceTone: Equatable {
    case light
    case dark
}

enum ChatTextTone: Equatable {
    case darkPrimary
    case darkSecondary
    case lightPrimary
    case lightSecondary
}

struct ChatBubblePalette: Equatable {
    let surfaceTone: ChatSurfaceTone
    let primaryTextTone: ChatTextTone
    let secondaryTextTone: ChatTextTone
}

struct ChatInputPalette: Equatable {
    let surfaceTone: ChatSurfaceTone
    let textTone: ChatTextTone
}

enum ChatSurfacePalette {
    static func bubblePalette(for role: MessageRole, colorScheme: ColorScheme) -> ChatBubblePalette {
        switch colorScheme {
        case .light:
            return ChatBubblePalette(
                surfaceTone: .light,
                primaryTextTone: .darkPrimary,
                secondaryTextTone: .darkSecondary
            )
        case .dark:
            return ChatBubblePalette(
                surfaceTone: .dark,
                primaryTextTone: .lightPrimary,
                secondaryTextTone: .lightSecondary
            )
        @unknown default:
            return bubblePalette(for: role, colorScheme: .light)
        }
    }

    static func inputPalette(for colorScheme: ColorScheme) -> ChatInputPalette {
        switch colorScheme {
        case .light:
            return ChatInputPalette(surfaceTone: .light, textTone: .darkPrimary)
        case .dark:
            return ChatInputPalette(surfaceTone: .dark, textTone: .lightPrimary)
        @unknown default:
            return inputPalette(for: .light)
        }
    }

    static func bubbleBackground(for role: MessageRole, colorScheme: ColorScheme) -> Color {
        role == .assistant ? SableTheme.bgBubbleAssistant : SableTheme.bgBubbleUser
    }

    static func inputBackground(for colorScheme: ColorScheme) -> Color {
        SableTheme.bgInput
    }

    static func textColor(for tone: ChatTextTone) -> Color {
        switch tone {
        case .darkPrimary:
            return SableTheme.textPrimary
        case .darkSecondary:
            return SableTheme.textSecondary
        case .lightPrimary:
            return SableTheme.textPrimary
        case .lightSecondary:
            return SableTheme.textSecondary
        }
    }

    static func borderColor(for colorScheme: ColorScheme) -> Color {
        SableTheme.border
    }
}
