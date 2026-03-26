import SwiftUI

/// Renders a text content block, styled by message role.
/// Assistant text is parsed into semantic blocks (paragraphs, headings,
/// blockquotes, horizontal rules, and fenced code blocks) and rendered
/// with distinct typography.
struct TextBlockView: View {
    let text: String
    let role: MessageRole
    let isError: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if isError {
            errorStyle
        } else if role == .user {
            userStyle
        } else {
            assistantBlockLayout
        }
    }

    // MARK: - Assistant (block-aware layout)

    private var assistantBlockLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(Self.parseBlocks(text).enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: AppLayoutMetrics.messageBubbleMaxWidth, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let content):
            inlineText(content)
                .font(SableTypography.messageBody)
                .foregroundStyle(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

        case .heading(let level, let content):
            inlineText(content)
                .font(SableTypography.markdownHeading(level: level))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

        case .blockquote(let content):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(SableTheme.textSecondary)
                    .frame(width: 2.5)
                inlineText(content)
                    .font(SableTypography.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)

        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\u{2022}")
                            .font(SableTypography.labelSmall)
                            .foregroundStyle(Color.secondary)
                            .frame(width: 8, alignment: .center)
                        inlineText(item)
                            .font(SableTypography.messageBody)
                            .foregroundStyle(.primary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)

        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(index + 1).")
                            .font(SableTypography.labelSmall)
                            .foregroundStyle(Color.secondary)
                            .frame(minWidth: 18, alignment: .trailing)
                        inlineText(item)
                            .font(SableTypography.messageBody)
                            .foregroundStyle(.primary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 2)

        case .rule:
            Rectangle()
                .fill(Color.primary.opacity(0.10))
                .frame(height: 0.5)
                .padding(.vertical, 6)

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)
        }
    }

    /// Parses inline markdown (bold, italic, code, links) within a single block.
    private func inlineText(_ text: String) -> Text {
        if let attr = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(text)
    }

    // MARK: - Block Parser

    enum MarkdownBlock {
        case paragraph(String)
        case heading(Int, String)
        case blockquote(String)
        case unorderedList([String])
        case orderedList([String])
        case rule
        case codeBlock(language: String, code: String)
    }

    /// Line-based parser that splits assistant text into semantic blocks.
    /// Handles paragraphs, headings, blockquotes, horizontal rules,
    /// unordered/ordered lists, and fenced code blocks (```).
    static func parseBlocks(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var quoteLines: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [String] = []

        // Fenced code block state
        var insideCode = false
        var codeLang = ""
        var codeLines: [String] = []

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
            paragraphLines = []
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            blocks.append(.blockquote(quoteLines.joined(separator: "\n")))
            quoteLines = []
        }

        func flushUnordered() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append(.unorderedList(unorderedItems))
            unorderedItems = []
        }

        func flushOrdered() {
            guard !orderedItems.isEmpty else { return }
            blocks.append(.orderedList(orderedItems))
            orderedItems = []
        }

        func flushAll() {
            flushParagraph()
            flushQuote()
            flushUnordered()
            flushOrdered()
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // --- Inside fenced code block ---
            if insideCode {
                if trimmed.hasPrefix("```") {
                    // Closing fence
                    let codeContent = codeLines.joined(separator: "\n")
                    blocks.append(.codeBlock(language: codeLang, code: codeContent))
                    codeLines = []
                    codeLang = ""
                    insideCode = false
                } else {
                    codeLines.append(line) // preserve original indentation
                }
                continue
            }

            // --- Opening fence ---
            if trimmed.hasPrefix("```") {
                flushAll()
                insideCode = true
                // Extract language tag after the backticks (e.g. ```swift)
                let after = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                codeLang = after
                continue
            }

            // Continue blockquote
            if !quoteLines.isEmpty {
                if trimmed.hasPrefix("> ") {
                    quoteLines.append(String(trimmed.dropFirst(2)))
                    continue
                } else if trimmed == ">" {
                    quoteLines.append("")
                    continue
                } else {
                    flushQuote()
                }
            }

            // Empty line
            if trimmed.isEmpty {
                flushParagraph()
                flushUnordered()
                flushOrdered()
                continue
            }

            // Horizontal rule: 3+ of same char (-, *, _)
            if trimmed.count >= 3 {
                let stripped = trimmed.filter { $0 != " " }
                if !stripped.isEmpty,
                   let first = stripped.first,
                   [Character("-"), Character("*"), Character("_")].contains(first),
                   stripped.allSatisfy({ $0 == first }) {
                    flushAll()
                    blocks.append(.rule)
                    continue
                }
            }

            // Heading
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" })
                let level = hashes.count
                if level <= 6 {
                    let rest = trimmed.dropFirst(level)
                    if rest.hasPrefix(" ") {
                        flushAll()
                        blocks.append(.heading(level, String(rest.dropFirst())))
                        continue
                    }
                }
            }

            // Blockquote start
            if trimmed.hasPrefix("> ") {
                flushParagraph()
                flushUnordered()
                flushOrdered()
                quoteLines.append(String(trimmed.dropFirst(2)))
                continue
            }
            if trimmed == ">" {
                flushParagraph()
                flushUnordered()
                flushOrdered()
                quoteLines.append("")
                continue
            }

            // Unordered list item: - , * , +
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                flushOrdered()
                unorderedItems.append(String(trimmed.dropFirst(2)))
                continue
            }

            // Ordered list item: 1. , 2. , 10. , etc.
            let digits = trimmed.prefix(while: { $0.isNumber })
            if !digits.isEmpty {
                let afterDigits = trimmed.dropFirst(digits.count)
                if afterDigits.hasPrefix(". ") {
                    flushParagraph()
                    flushUnordered()
                    orderedItems.append(String(afterDigits.dropFirst(2)))
                    continue
                }
            }

            // Regular line — flush any open lists first
            flushUnordered()
            flushOrdered()
            paragraphLines.append(line)
        }

        // If we end mid-code-block (streaming), flush what we have
        if insideCode && !codeLines.isEmpty {
            blocks.append(.codeBlock(language: codeLang, code: codeLines.joined(separator: "\n")))
        }

        flushQuote()
        flushUnordered()
        flushOrdered()
        flushParagraph()
        return blocks
    }

    // MARK: - User

    private var userStyle: some View {
        Text(text)
            .font(SableTypography.messageBody)
            .foregroundStyle(.primary.opacity(0.90))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: SableRadius.xxl, style: .continuous)
                    .fill(SableTheme.bgBubbleUser)
            )
            .frame(maxWidth: 480, alignment: .trailing)
            .textSelection(.enabled)
    }

    // MARK: - Error

    private var errorStyle: some View {
        Text(text)
            .font(SableTypography.caption)
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - CodeBlockView

/// Renders a fenced code block with language label, monospaced content,
/// and a one-click copy button. Styled to feel native on macOS dark/light.
private struct CodeBlockView: View {
    let language: String
    let code: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var copied = false

    private var displayLanguage: String {
        language.isEmpty ? "code" : language.lowercased()
    }

    /// Background slightly darker than the chat surface to create depth.
    private var bgColor: Color {
        colorScheme == .dark
            ? Color(white: 0.10)
            : Color(white: 0.94)
    }

    private var headerBgColor: Color {
        colorScheme == .dark
            ? Color(white: 0.13)
            : Color(white: 0.90)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: language label + copy button
            HStack {
                Text(displayLanguage)
                    .font(SableTypography.codeLabel)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(SableTypography.captionMedium)
                        Text(copied ? "Copied" : "Copy")
                            .font(SableTypography.caption)
                    }
                    .foregroundStyle(copied ? SableTheme.success : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(headerBgColor)

            Divider()
                .opacity(0.4)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(SableTypography.codeBlock)
                    .foregroundStyle(.primary.opacity(0.88))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(bgColor)
        .clipShape(RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                .strokeBorder(SableTheme.borderStrong,
                              lineWidth: 0.5)
        )
    }

    private func copyCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
            copied = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(SableAnimation.move()) {
                copied = false
            }
        }
    }
}
