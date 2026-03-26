import SwiftUI

/// Structured form for editing USER.md fields.
/// Owns its 6 field @State; pushes markdown content + dirty flag to parent via callback.
struct UserFormView: View {
    let diskContent: String
    var onContentUpdate: (String, Bool) -> Void

    @State private var name = ""
    @State private var callName = ""
    @State private var pronouns = ""
    @State private var timezone = ""
    @State private var notes = ""
    @State private var context = ""

    private var isDirty: Bool {
        let d = parsedDisk
        return name != d.name || callName != d.callName
            || pronouns != d.pronouns || timezone != d.timezone
            || notes != d.notes || context != d.context
    }

    private var parsedDisk: (name: String, callName: String, pronouns: String, timezone: String, notes: String, context: String) {
        (
            name: MarkdownFieldParser.extractField("Name", from: diskContent),
            callName: MarkdownFieldParser.extractField("What to call them", from: diskContent),
            pronouns: MarkdownFieldParser.extractField("Pronouns", from: diskContent),
            timezone: MarkdownFieldParser.extractField("Timezone", from: diskContent),
            notes: MarkdownFieldParser.extractField("Notes", from: diskContent),
            context: MarkdownFieldParser.extractContextSection(from: diskContent)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StructuredFormField(label: "Name", placeholder: "Your real name", text: $name, icon: "person.fill")
                StructuredFormField(label: "What to call them", placeholder: "Nickname or preferred name", text: $callName, icon: "text.bubble")
                StructuredFormField(label: "Pronouns", placeholder: "he/him, she/her, they/them (optional)", text: $pronouns, icon: "person.2")
                StructuredFormField(label: "Timezone", placeholder: "e.g. Asia/Shanghai, America/New_York", text: $timezone, icon: "clock")
                StructuredFormField(label: "Notes", placeholder: "Quick notes about preferences, pet peeves, etc.", text: $notes, icon: "note.text")

                Divider()

                // Context — larger text area
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                        Text("Context")
                            .font(SableTypography.captionMedium)
                            .foregroundStyle(.secondary)
                    }
                    Text("What do you care about? Projects? Interests? What annoys you?")
                        .font(SableTypography.caption)
                        .foregroundStyle(.quaternary)
                    TextEditor(text: $context)
                        .font(SableTypography.body)
                        .lineSpacing(3)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 300)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                                .strokeBorder(SableTheme.border)
                        )
                }

                Divider()

                RawMarkdownPreview(content: buildMarkdown())
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { parseFields(from: diskContent) }
        .onChange(of: diskContent) { _, newValue in parseFields(from: newValue) }
        .onChange(of: name) { _, _ in pushUpdate() }
        .onChange(of: callName) { _, _ in pushUpdate() }
        .onChange(of: pronouns) { _, _ in pushUpdate() }
        .onChange(of: timezone) { _, _ in pushUpdate() }
        .onChange(of: notes) { _, _ in pushUpdate() }
        .onChange(of: context) { _, _ in pushUpdate() }
    }

    // MARK: - Parse & Build

    private func parseFields(from markdown: String) {
        name = MarkdownFieldParser.extractField("Name", from: markdown)
        callName = MarkdownFieldParser.extractField("What to call them", from: markdown)
        pronouns = MarkdownFieldParser.extractField("Pronouns", from: markdown)
        timezone = MarkdownFieldParser.extractField("Timezone", from: markdown)
        notes = MarkdownFieldParser.extractField("Notes", from: markdown)
        context = MarkdownFieldParser.extractContextSection(from: markdown)
    }

    func buildMarkdown() -> String {
        func fl(_ label: String, _ value: String, _ ph: String? = nil) -> String {
            if value.isEmpty {
                if let ph { return "- **\(label):** _(\(ph))_" }
                return "- **\(label):**"
            }
            return "- **\(label):** \(value)"
        }

        let contextBlock: String
        if context.isEmpty {
            contextBlock = "_(What do they care about? What projects are they working on? What annoys them? What makes them laugh? Build this over time.)_"
        } else {
            contextBlock = context
        }

        return [
            "# USER.md - About Your Human", "",
            "_Learn about the person you're helping. Update this as you go._", "",
            fl("Name", name),
            fl("What to call them", callName),
            fl("Pronouns", pronouns, "optional"),
            fl("Timezone", timezone),
            fl("Notes", notes),
            "", "## Context", "",
            contextBlock, "",
            "---", "",
            "The more you know, the better you can help. But remember — you're learning about a person, not building a dossier. Respect the difference.", ""
        ].joined(separator: "\n")
    }

    private func pushUpdate() {
        onContentUpdate(buildMarkdown(), isDirty)
    }
}
