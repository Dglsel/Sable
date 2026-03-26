import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Attachment Model

private struct Attachment: Identifiable {
    let id = UUID()
    let filename: String
    let icon: String          // SF Symbol name
    let content: String?      // nil for binary/unsupported
    let url: URL
    let thumbnail: NSImage?   // thumbnail for image attachments
    let isImage: Bool
}

// MARK: - ChatInputBar

struct ChatInputBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft = ""
    @State private var plusHovered = false
    @State private var sendPressed = false
    @State private var attachments: [Attachment] = []
    @State private var showFilePicker = false
    @State private var isDragOver = false
    @FocusState private var isFocused: Bool

    let isSending: Bool
    let onSend: (String, [ChatAttachment]) -> Void
    var onStop: (() -> Void)?

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Dynamic line count based on content.
    private var lineCount: Int {
        let newlines = draft.components(separatedBy: .newlines).count
        return min(max(newlines, 1), 8)
    }

    /// Dynamic editor height: single line = 22pt, grows with content up to 8 lines.
    private var editorHeight: CGFloat {
        let lineHeight: CGFloat = 20
        let padding: CGFloat = 12
        return CGFloat(lineCount) * lineHeight + padding
    }

    /// Background opacity elevates slightly when focused for a subtle lift effect.
    private var bgOpacity: Double {
        if colorScheme == .dark {
            return isFocused ? 0.065 : 0.04
        } else {
            return isFocused ? 0.035 : 0.02
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                // Attachment chips strip — visible only when files are attached
                if !attachments.isEmpty {
                    AttachmentStripView(attachments: attachments) { id in
                        withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
                            attachments.removeAll { $0.id == id }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }

                // Row 1: Text input area — full width
                ZStack(alignment: .topLeading) {
                    // Placeholder
                    if draft.isEmpty {
                        Text(isSending
                             ? "Waiting for response\u{2026}"
                             : L10n.string("chat.input.placeholder", default: "Message Sable"))
                            .font(SableTypography.input)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $draft)
                        .font(SableTypography.input)
                        .lineSpacing(3)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(height: editorHeight)
                        .focused($isFocused)
                        .disabled(isSending)
                        .onKeyPress(.return, phases: .down) { press in
                            if press.modifiers.contains(.shift) {
                                return .ignored
                            }
                            // Don't send while IME is composing (e.g. Chinese/Japanese input)
                            if IMEState.isComposing {
                                return .ignored
                            }
                            submit()
                            return .handled
                        }

                    // Invisible drop overlay — appears during drag to intercept
                    // before NSTextView can insert the file path as text
                    if isDragOver {
                        Color.clear
                            .contentShape(Rectangle())
                            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                                handleDrop(providers: providers)
                            }
                    }
                }
                .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                    handleDrop(providers: providers)
                }

                // Row 2: Toolbar — left: attach tools, right: send
                HStack(spacing: 0) {
                    // Left: tool buttons
                    HStack(spacing: 2) {
                        Button {
                            showFilePicker = true
                        } label: {
                            Image(systemName: attachments.isEmpty ? "plus" : "plus.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(
                                    attachments.isEmpty
                                        ? (plusHovered ? SableTheme.interactive : SableTheme.interactiveMuted)
                                        : SableTheme.interactive
                                )
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                                        .fill(plusHovered ? SableTheme.bgHover : .clear)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onHover { plusHovered = $0 }
                        .help("Add attachment")
                    }

                    Spacer()

                    // Right: send / stop button
                    SendStopButton(
                        isSending: isSending,
                        canSend: canSend,
                        onSend: { triggerSend() },
                        onStop: { onStop?() }
                    )
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                    .fill(SableTheme.bgTertiary)
                    .animation(SableAnimation.enter(), value: isFocused)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SableRadius.xl, style: .continuous)
                    .strokeBorder(
                        isDragOver
                            ? SableTheme.borderFocus
                            : (isFocused ? SableTheme.borderFocus : SableTheme.borderStrong),
                        lineWidth: (isFocused || isDragOver) ? 1.0 : 0.5
                    )
                    .animation(SableAnimation.enter(), value: isFocused)
                    .animation(SableAnimation.enter(), value: isDragOver)
            )
            .shadow(
                color: isFocused ? Color.primary.opacity(0.06) : .clear,
                radius: 8, x: 0, y: 2
            )
            .animation(SableAnimation.enter(), value: isFocused)
            .frame(maxWidth: AppLayoutMetrics.composerMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, SableSpacing.xLarge)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(SableTheme.chatBackground)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: Self.allAttachmentTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Send

    private func triggerSend() {
        guard canSend else { return }
        sendPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendPressed = false
            submit()
        }
    }

    private func submit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        // Convert all attachments to ChatAttachment for unified API handling
        let chatAttachments = attachments.map { att in
            let ext = att.url.pathExtension.lowercased()
            return ChatAttachment(
                filename: att.filename,
                filePath: att.url.path,
                isImage: Self.imageExtensions.contains(ext),
                content: att.content
            )
        }

        onSend(trimmed, chatAttachments)
        draft = ""
        attachments = []
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        addFiles(urls: urls, securityScoped: true)
    }

    /// Unified file ingestion — used by both file picker and drag-and-drop.
    private func addFiles(urls: [URL], securityScoped: Bool) {
        for url in urls {
            if securityScoped {
                guard url.startAccessingSecurityScopedResource() else { continue }
            }
            defer {
                if securityScoped { url.stopAccessingSecurityScopedResource() }
            }

            let filename = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            let isImage = Self.imageExtensions.contains(ext)

            let textContent = FileContentExtractor.extractText(from: url)
            let icon = Self.icon(for: ext)

            // Generate thumbnail for images
            let thumbnail: NSImage?
            if isImage {
                thumbnail = NSImage(contentsOf: url)
            } else {
                thumbnail = nil
            }

            let attachment = Attachment(
                filename: filename, icon: icon, content: textContent,
                url: url, thumbnail: thumbnail, isImage: isImage
            )

            if !attachments.contains(where: { $0.filename == filename }) {
                withAnimation(SableAnimation.move(duration: SableAnimation.fast)) {
                    attachments.append(attachment)
                }
            }
        }
    }

    // MARK: - Drag & Drop

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let urlString = String(data: data, encoding: .utf8),
                          let url = URL(string: urlString) else { return }
                    DispatchQueue.main.async {
                        addFiles(urls: [url], securityScoped: false)
                    }
                }
            }
        }
        return handled
    }

    // MARK: - Static Helpers

    private static let allAttachmentTypes: [UTType] = [
        .image, .png, .jpeg, .gif, .webP, .heic, .tiff, .bmp,
        .text, .plainText, .utf8PlainText,
        .sourceCode, .pythonScript, .javaScript, .shellScript,
        .json, .xml, .yaml,
        .pdf,
        .spreadsheet, .presentation,
        .data    // catch-all so users can attach any file
    ]

    private static let imageExtensions = FileContentExtractor.imageExtensions

    private static func icon(for ext: String) -> String {
        switch ext {
        case "pdf":                              return "doc.richtext"
        case "png", "jpg", "jpeg", "gif",
             "webp", "heic", "tiff":            return "photo"
        case "swift":                            return "swift"
        case "py":                               return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "jsx", "tsx":          return "chevron.left.forwardslash.chevron.right"
        case "json":                             return "curlybraces"
        case "yaml", "yml", "toml":             return "list.bullet.indent"
        case "sh", "bash", "zsh":               return "terminal"
        case "md", "markdown":                  return "text.alignleft"
        case "csv":                              return "tablecells"
        case "html", "htm", "xml":              return "globe"
        case "css", "scss", "less":             return "paintbrush"
        case "docx", "doc":                     return "doc.text"
        case "xlsx", "xls":                     return "tablecells"
        case "pptx", "ppt":                     return "rectangle.split.3x1"
        case "rtf":                             return "doc.richtext"
        case "sql":                             return "cylinder"
        case "sol":                             return "chevron.left.forwardslash.chevron.right"
        default:                                return "doc"
        }
    }
}

// MARK: - Attachment Strip

private struct AttachmentStripView: View {
    let attachments: [Attachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(attachments) { attachment in
                    AttachmentChipView(attachment: attachment) {
                        onRemove(attachment.id)
                    }
                }
            }
        }
    }
}

// MARK: - Attachment Chip

private struct AttachmentChipView: View {
    @State private var isHovered = false

    let attachment: Attachment
    let onRemove: () -> Void

    var body: some View {
        if attachment.isImage, let thumb = attachment.thumbnail {
            // Image chip: thumbnail + remove button
            imageChip(thumb)
        } else {
            // File chip: icon + filename + remove button
            fileChip
        }
    }

    private func imageChip(_ thumb: NSImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: thumb)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous))

            // Remove button — visible on hover
            if isHovered {
                Button { onRemove() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .onHover { isHovered = $0 }
        .animation(SableAnimation.move(duration: SableAnimation.fast), value: isHovered)
    }

    private var fileChip: some View {
        HStack(spacing: 5) {
            Image(systemName: attachment.icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SableTheme.interactive)

            Text(attachment.filename)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 140)

            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                .fill(SableTheme.bgActive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                .strokeBorder(SableTheme.border, lineWidth: 0.5)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Send / Stop Button

/// Unified button that morphs between send (arrow up) and stop (square) states.
/// Stop state shows a pulsing ring to indicate active generation.
private struct SendStopButton: View {
    let isSending: Bool
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var ringRotation: Double = 0

    private let size: CGFloat = 26

    var body: some View {
        Button {
            if isSending {
                onStop()
            } else {
                onSend()
            }
        } label: {
            ZStack {
                if isSending {
                    // Animated ring
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            SableTheme.textSecondary.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: size, height: size)
                        .rotationEffect(.degrees(ringRotation))

                    // Stop square
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(isHovered ? SableTheme.textPrimary : SableTheme.textSecondary)
                        .frame(width: 9, height: 9)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                } else {
                    // Send arrow
                    Image(systemName: canSend ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(
                            canSend
                                ? (isHovered ? SableTheme.textPrimary : SableTheme.textPrimary.opacity(0.85))
                                : SableTheme.interactiveMuted
                        )
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
            .scaleEffect(isPressed ? 0.82 : (isHovered && isSending ? 1.08 : 1.0))
        }
        .buttonStyle(.plain)
        .disabled(!isSending && !canSend)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
        .animation(SableAnimation.move(duration: SableAnimation.normal), value: isSending)
        .animation(SableAnimation.move(duration: SableAnimation.fast), value: canSend)
        .onAppear { startRingAnimation() }
        .onChange(of: isSending) { _, sending in
            if sending { startRingAnimation() }
        }
    }

    private func startRingAnimation() {
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            ringRotation += 360
        }
    }
}
