import SwiftUI
import AppKit

/// Renders an image attachment as a thumbnail in a message bubble.
/// Click to open a full-size preview in a popover.
struct ImageAttachmentView: View {
    let attachment: ImageAttachment
    @State private var showFullSize = false

    private var nsImage: NSImage? {
        NSImage(contentsOfFile: attachment.filePath)
    }

    var body: some View {
        if let image = nsImage {
            Button {
                showFullSize = true
            } label: {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 240, maxHeight: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                            .strokeBorder(SableTheme.border, lineWidth: 0.5)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFullSize, arrowEdge: .top) {
                ImagePreviewPopover(image: image, filename: attachment.filename)
            }
        } else {
            // File missing or unreadable — show placeholder
            HStack(spacing: 6) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 14))
                    .foregroundStyle(SableTheme.textTertiary)
                Text(attachment.filename)
                    .font(SableTypography.caption)
                    .foregroundStyle(SableTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                    .fill(SableTheme.bgTertiary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SableRadius.lg, style: .continuous)
                    .strokeBorder(SableTheme.border, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Full-Size Preview Popover

private struct ImagePreviewPopover: View {
    let image: NSImage
    let filename: String

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 600, maxHeight: 500)

            HStack {
                Text(filename)
                    .font(SableTypography.caption)
                    .foregroundStyle(SableTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
                Text(imageSizeLabel)
                    .font(SableTypography.caption)
                    .foregroundStyle(SableTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(4)
    }

    private var imageSizeLabel: String {
        let w = Int(image.size.width)
        let h = Int(image.size.height)
        return "\(w) × \(h)"
    }
}
