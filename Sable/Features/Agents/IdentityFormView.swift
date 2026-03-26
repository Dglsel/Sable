import SwiftUI

/// Structured form for editing IDENTITY.md fields.
/// Owns its 5 field @State; pushes markdown content + dirty flag to parent via callback.
struct IdentityFormView: View {
    let diskContent: String
    var onContentUpdate: (String, Bool) -> Void

    @State private var name = ""
    @State private var creature = ""
    @State private var vibe = ""
    @State private var emoji = ""
    @State private var avatar = ""

    private var isDirty: Bool {
        let d = parsedDisk
        return name != d.name || creature != d.creature
            || vibe != d.vibe || emoji != d.emoji || avatar != d.avatar
    }

    private var parsedDisk: (name: String, creature: String, vibe: String, emoji: String, avatar: String) {
        (
            name: MarkdownFieldParser.extractField("Name", from: diskContent),
            creature: MarkdownFieldParser.extractField("Creature", from: diskContent),
            vibe: MarkdownFieldParser.extractField("Vibe", from: diskContent),
            emoji: MarkdownFieldParser.extractField("Emoji", from: diskContent),
            avatar: MarkdownFieldParser.extractField("Avatar", from: diskContent)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                StructuredFormField(label: "Name", placeholder: "Pick something you like", text: $name, icon: "person.fill")
                StructuredFormField(label: "Creature", placeholder: "AI? Robot? Ghost in the machine?", text: $creature, icon: "sparkles")
                StructuredFormField(label: "Vibe", placeholder: "Sharp? Warm? Chaotic? Calm?", text: $vibe, icon: "waveform")
                StructuredFormField(label: "Emoji", placeholder: "Your signature emoji", text: $emoji, icon: "face.smiling")
                StructuredFormField(label: "Avatar", placeholder: "Path or URL to avatar image", text: $avatar, icon: "photo")

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
        .onChange(of: creature) { _, _ in pushUpdate() }
        .onChange(of: vibe) { _, _ in pushUpdate() }
        .onChange(of: emoji) { _, _ in pushUpdate() }
        .onChange(of: avatar) { _, _ in pushUpdate() }
    }

    // MARK: - Parse & Build

    private func parseFields(from markdown: String) {
        name = MarkdownFieldParser.extractField("Name", from: markdown)
        creature = MarkdownFieldParser.extractField("Creature", from: markdown)
        vibe = MarkdownFieldParser.extractField("Vibe", from: markdown)
        emoji = MarkdownFieldParser.extractField("Emoji", from: markdown)
        avatar = MarkdownFieldParser.extractField("Avatar", from: markdown)
    }

    func buildMarkdown() -> String {
        func fl(_ label: String, _ value: String, _ ph: String) -> String {
            value.isEmpty ? "- **\(label):**\n  _(\(ph))_" : "- **\(label):** \(value)"
        }
        return [
            "# IDENTITY.md - Who Am I?", "",
            "_Fill this in during your first conversation. Make it yours._", "",
            fl("Name", name, "pick something you like"),
            fl("Creature", creature, "AI? robot? familiar? ghost in the machine? something weirder?"),
            fl("Vibe", vibe, "how do you come across? sharp? warm? chaotic? calm?"),
            fl("Emoji", emoji, "your signature — pick one that feels right"),
            fl("Avatar", avatar, "workspace-relative path, http(s) URL, or data URI"),
            "", "---", "",
            "This isn't just metadata. It's the start of figuring out who you are.", "",
            "Notes:", "",
            "- Save this file at the workspace root as `IDENTITY.md`.",
            "- For avatars, use a workspace-relative path like `avatars/openclaw.png`.", ""
        ].joined(separator: "\n")
    }

    private func pushUpdate() {
        onContentUpdate(buildMarkdown(), isDirty)
    }
}
