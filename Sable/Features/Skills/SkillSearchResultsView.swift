import SwiftUI

/// Search results list with installed badge and row-click navigation.
struct SkillSearchResultsView: View {
    let results: [SkillService.SearchResult]
    let installedSkillIDs: Set<String>
    var errorMessage: String?
    var showError: Bool = false
    var onSelectResult: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if showError, let error = errorMessage {
                SkillErrorBanner(message: error)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { result in
                        resultRow(result)
                        if result.id != results.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func resultRow(_ result: SkillService.SearchResult) -> some View {
        let isInstalled = installedSkillIDs.contains(result.slug)

        return Button {
            onSelectResult(result.slug)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(result.name)
                            .font(SableTypography.labelSmallMedium)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isInstalled {
                            Text("Installed")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(SableTheme.success)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(SableTheme.semanticBackground(SableTheme.success), in: Capsule())
                        }
                    }
                    Text(result.slug)
                        .font(SableTypography.monoSmall)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

}
