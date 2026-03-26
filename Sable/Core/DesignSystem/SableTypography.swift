import SwiftUI

/// Centralized typography system for Sable.
/// All font usage across the app should reference these tokens — never hardcode
/// `.system(size: N)` directly in views.
///
/// Scale follows macOS semantic sizes, tuned for a dense-but-readable information
/// density appropriate for a professional tool (not a consumer app).
enum SableTypography {

    // MARK: - Body / Reading

    /// Primary reading text — assistant messages, editor content, descriptions.
    /// macOS default body is 13pt; we stay close to it.
    static let body: Font = .system(size: 13, weight: .regular)

    /// Slightly larger body for chat message paragraphs — improves readability
    /// at the center of the screen where users spend the most time.
    static let messageBody: Font = .system(size: 13.5, weight: .regular)

    /// Input field text — same as messageBody for visual continuity.
    static let input: Font = .system(size: 13.5, weight: .regular)

    // MARK: - UI Labels

    /// Standard UI label — buttons, form fields, list items.
    static let label: Font = .system(size: 13, weight: .regular)

    /// Slightly emphasized label — section titles, named items.
    static let labelMedium: Font = .system(size: 13, weight: .medium)

    /// Small UI label — secondary info, badges, helper text.
    static let labelSmall: Font = .system(size: 12, weight: .regular)

    /// Small emphasized — table headers, form group labels.
    static let labelSmallMedium: Font = .system(size: 12, weight: .medium)

    // MARK: - Headings

    /// Page/section title — agent names, view headings.
    static let title: Font = .system(size: 15, weight: .semibold)

    /// Sub-section heading — card titles, group names.
    static let subtitle: Font = .system(size: 13, weight: .semibold)

    /// Large display title — empty states, onboarding.
    static let displayTitle: Font = .system(size: 20, weight: .semibold)

    // MARK: - Supporting / Metadata

    /// Caption — timestamps, token counts, status metadata.
    static let caption: Font = .system(size: 11, weight: .regular)

    /// Caption emphasized — badge labels, status tags.
    static let captionMedium: Font = .system(size: 11, weight: .medium)

    /// Micro — the smallest readable size, used sparingly for dense UI.
    static let micro: Font = .system(size: 10, weight: .regular)

    /// Micro emphasized — tight badge labels, version numbers.
    static let microMedium: Font = .system(size: 10, weight: .medium)

    // MARK: - Code / Monospaced

    /// Inline code within prose — `backtick` spans.
    static let codeInline: Font = .system(size: 12.5, design: .monospaced)

    /// Code block content — fenced code blocks, CLI output.
    static let codeBlock: Font = .system(size: 12.5, design: .monospaced)

    /// Code block language label / header.
    static let codeLabel: Font = .system(size: 11, weight: .medium, design: .monospaced)

    /// Technical metadata — model IDs, session keys, version strings.
    static let mono: Font = .system(size: 11, design: .monospaced)

    /// Small monospaced — compact technical badges.
    static let monoSmall: Font = .system(size: 10, weight: .medium, design: .monospaced)

    // MARK: - Markdown Headings (within assistant messages)

    static func markdownHeading(level: Int) -> Font {
        switch level {
        case 1: return .system(size: 16, weight: .semibold)
        case 2: return .system(size: 15, weight: .semibold)
        case 3: return .system(size: 14, weight: .semibold)
        default: return .system(size: 13.5, weight: .medium)
        }
    }

    // MARK: - Toolbar / Chrome

    /// Toolbar model label.
    static let toolbarLabel: Font = .system(size: 12, weight: .regular)

    /// Toolbar icon buttons.
    static let toolbarIcon: Font = .system(size: 13, weight: .regular)
}
