import SwiftUI

/// Color tokens — DESIGN.md § Color.
/// Monochrome + semantic-only. Zero accent color.
enum SableTheme {

    // MARK: - Interactive Opacity Scale

    /// Adaptive text/interactive colors that resolve per color scheme.

    /// Headings, body text, primary content — dark: white 92%, light: black 88%
    static let textPrimary = Color(light: .black.opacity(0.88), dark: .white.opacity(0.92))
    /// Buttons, send icon, active elements — dark: white 85%, light: black 80%
    static let interactive = Color(light: .black.opacity(0.80), dark: .white.opacity(0.85))
    /// Hover state for interactive elements — dark: white 100%, light: black 95%
    static let interactiveHover = Color(light: .black.opacity(0.95), dark: .white.opacity(1.0))
    /// Secondary text, descriptions — dark: white 56%, light: black 50%
    static let textSecondary = Color(light: .black.opacity(0.50), dark: .white.opacity(0.56))
    /// Disabled interactive, subtle indicators — dark: white 50%, light: black 42%
    static let interactiveMuted = Color(light: .black.opacity(0.42), dark: .white.opacity(0.50))
    /// Captions, hints, timestamps — dark: white 32%, light: black 28%
    static let textTertiary = Color(light: .black.opacity(0.28), dark: .white.opacity(0.32))
    /// Placeholder text, dividers — dark: white 18%, light: black 14%
    static let textGhost = Color(light: .black.opacity(0.14), dark: .white.opacity(0.18))

    // MARK: - Surface Colors

    /// Main window background — dark: #1A1A1C, light: #FFFFFF
    static let bgPrimary = Color(light: .white, dark: Color(hex: 0x1A1A1C))
    /// Sidebar background — dark: #1F1F22, light: #EAEAEB
    static let bgSidebar = Color(light: Color(hex: 0xEAEAEB), dark: Color(hex: 0x1F1F22))
    /// Cards, elevated surfaces — dark: #26262A, light: #EFEFEF
    static let bgTertiary = Color(light: Color(hex: 0xEFEFEF), dark: Color(hex: 0x26262A))
    /// Hover menus, popovers — dark: #2C2C32, light: #FFFFFF
    static let bgElevated = Color(light: .white, dark: Color(hex: 0x2C2C32))
    /// User chat bubbles — dark: #2A2A2E, light: #F0F0F2
    static let bgBubbleUser = Color(light: Color(hex: 0xF0F0F2), dark: Color(hex: 0x2A2A2E))
    /// Assistant chat bubbles — dark: #222226, light: #FFFFFF
    static let bgBubbleAssistant = Color(light: .white, dark: Color(hex: 0x222226))
    /// Input fields — dark: #222226, light: #FFFFFF
    static let bgInput = Color(light: .white, dark: Color(hex: 0x222226))

    /// Hover overlay — dark: white 5%, light: black 4%
    static let bgHover = Color(light: .black.opacity(0.04), dark: .white.opacity(0.05))
    /// Active/selected overlay — dark: white 8%, light: black 7%
    static let bgActive = Color(light: .black.opacity(0.07), dark: .white.opacity(0.08))

    // MARK: - Border Colors

    /// Default borders — dark: white 7%, light: black 7%
    static let border = Color(light: .black.opacity(0.07), dark: .white.opacity(0.07))
    /// Emphasized borders — dark: white 13%, light: black 14%
    static let borderStrong = Color(light: .black.opacity(0.14), dark: .white.opacity(0.13))
    /// Focus rings — dark: white 28%, light: black 32%
    static let borderFocus = Color(light: .black.opacity(0.32), dark: .white.opacity(0.28))

    // MARK: - Neutral Scale

    static let gray50  = Color(hex: 0xF5F5F6)
    static let gray100 = Color(hex: 0xE7E7E8)
    static let gray200 = Color(hex: 0xD4D4D6)
    static let gray300 = Color(hex: 0xB0B0B4)
    static let gray400 = Color(hex: 0x8A8A90)
    static let gray500 = Color(hex: 0x6A6A72)
    static let gray600 = Color(hex: 0x4A4A52)
    static let gray700 = Color(hex: 0x34343A)
    static let gray800 = Color(hex: 0x28282E)
    static let gray850 = Color(hex: 0x232328)
    static let gray900 = Color(hex: 0x1F1F22)
    static let gray950 = Color(hex: 0x141416)

    // MARK: - Semantic Colors (the only color in the app)

    /// Gateway running, health check pass, positive states
    static let success = Color(hex: 0x6B9B7C)
    /// High usage, approaching limits, caution states
    static let warning = Color(hex: 0xB0923E)
    /// Connection failed, gateway down, critical states
    static let error = Color(hex: 0xB05A52)
    /// Informational notices, updates available
    static let info = Color(hex: 0x7C909C)

    /// Semantic background — 8% opacity overlay
    static func semanticBackground(_ color: Color) -> Color {
        color.opacity(0.08)
    }

    /// Semantic border — 18% opacity overlay
    static func semanticBorder(_ color: Color) -> Color {
        color.opacity(0.18)
    }

    // MARK: - Code Syntax (Dimmed)

    /// Keywords — dark: #9B8AA4, light: #7A6B84
    static let codeKeyword = Color(light: Color(hex: 0x7A6B84), dark: Color(hex: 0x9B8AA4))
    /// Function names — dark: #8A9BA4, light: #5A7080
    static let codeFunction = Color(light: Color(hex: 0x5A7080), dark: Color(hex: 0x8A9BA4))
    /// String literals — dark: #8A9B8C, light: #5A7A60
    static let codeString = Color(light: Color(hex: 0x5A7A60), dark: Color(hex: 0x8A9B8C))
    /// Comments — uses text-tertiary (dark: white 32%, light: black 28%)
    static var codeComment: Color { textTertiary }
    /// Numeric literals — dark: #A49B8A, light: #847A62
    static let codeNumber = Color(light: Color(hex: 0x847A62), dark: Color(hex: 0xA49B8A))
    /// Type names — dark: #8AA4A4, light: #5A8080
    static let codeType = Color(light: Color(hex: 0x5A8080), dark: Color(hex: 0x8AA4A4))
    /// Operators — uses text-secondary (dark: white 56%, light: black 50%)
    static var codeOperator: Color { textSecondary }

    // MARK: - Legacy Compatibility (remove after full migration)

    /// Use bgPrimary instead.
    static let chatBackground = Color(nsColor: .windowBackgroundColor)

    static func sidebarBackground(_ colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .light: return Color(hex: 0xEAEAEB)
        case .dark:  return Color(hex: 0x1F1F22)
        @unknown default: return Color(nsColor: .underPageBackgroundColor)
        }
    }
}

// MARK: - Color Helpers

extension Color {
    /// Create a Color from a hex integer, e.g. `Color(hex: 0x1A1A1C)`.
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Adaptive color that resolves differently per color scheme.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
