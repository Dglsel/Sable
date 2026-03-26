import SwiftUI

struct SkillInstallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Set of currently installed skill IDs (names/slugs) for cross-reference.
    let installedSkillIDs: Set<String>

    /// Called with the installed skill's slug on success.
    var onInstalled: ((String) -> Void)?

    @State private var query = ""
    @State private var phase: InstallPhase = .idle
    @State private var results: [SkillService.SearchResult] = []
    @State private var selectedDetail: SkillService.SkillDetail?
    @State private var errorMessage: String?
    @State private var urlError: String?
    @State private var importDiagnostic: ImportDiagnostic?
    /// Guards against state changes after a terminal state is reached.
    @State private var installCompleted = false
    /// Tracks the current async navigation task so we can cancel stale ones.
    @State private var navigationTask: Task<Void, Never>?

    private enum InstallPhase: Equatable {
        case idle
        case resolving          // slug/URL → inspect in progress
        case searching          // keyword search in progress
        case noResults
        case results
        case loadingDetail      // clicked a search result → inspect
        case detail
        case installing
        case success(slug: String)
        case failure
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            if showSearchBar {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Divider()
            }

            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            footer
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(width: 500, height: 480)
        .sheet(item: $importDiagnostic) { diagnostic in
            ImportDiagnosticSheet(diagnostic: diagnostic)
        }
    }

    private var showSearchBar: Bool {
        switch phase {
        case .resolving, .loadingDetail, .detail, .installing: false
        case .success: false
        default: true
        }
    }

    // MARK: - Title Bar

    private var showBackButton: Bool {
        if case .detail = phase { return true }
        if case .failure = phase, selectedDetail != nil { return true }
        return false
    }

    private var titleBar: some View {
        ZStack {
            // Center: title — always centered regardless of back button
            Text("Install Skill")
                .font(SableTypography.title)

            HStack(spacing: 0) {
                // Left: back button or spacer (fixed width to keep layout stable)
                if showBackButton {
                    backButton
                }

                Spacer()

                // Right: close button
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .focusEffectDisabled()
            }
        }
        .frame(height: 28)
    }

    @ViewBuilder
    private var backButton: some View {
        let action: () -> Void = {
            navigationTask?.cancel()
            if case .failure = phase {
                errorMessage = nil
                phase = .detail
            } else if results.isEmpty {
                selectedDetail = nil
                phase = .idle
            } else {
                selectedDetail = nil
                phase = .results
            }
        }
        let label = (results.isEmpty && !(phase == .failure)) ? "Back" : "Results"

        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(SableTypography.labelSmallMedium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Paste sable.ai link, slug, or search keywords\u{2026}", text: $query)
                    .textFieldStyle(.plain)
                    .font(SableTypography.body)
                    .onSubmit { performSearch() }
                    .disabled(phase == .searching || phase == .resolving)

                if !query.isEmpty {
                    Button {
                        navigationTask?.cancel()
                        query = ""
                        phase = .idle
                        results = []
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                    .fill(SableTheme.bgHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SableRadius.md, style: .continuous)
                    .stroke(SableTheme.borderStrong)
            )

            Button("Search") {
                performSearch()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || phase == .searching || phase == .resolving)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch phase {
        case .idle:
            idlePlaceholder
        case .resolving:
            loadingView("Resolving skill\u{2026}")
        case .searching:
            loadingView("Searching\u{2026}")
        case .noResults:
            noResultsView
        case .results:
            resultsListView
        case .loadingDetail:
            loadingView("Loading skill details\u{2026}")
        case .detail:
            if let detail = selectedDetail {
                detailConfirmView(detail)
            }
        case .installing:
            loadingView("Installing\u{2026}")
        case .success(let slug):
            successView(slug: slug)
        case .failure:
            if let detail = selectedDetail {
                detailConfirmView(detail)
            } else {
                resultsListView
            }
        }
    }

    // MARK: - Idle

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)

            VStack(spacing: 4) {
                Text("Paste a Sable.ai skill link or slug")
                    .font(SableTypography.labelSmallMedium)
                    .foregroundStyle(.secondary)
                Text("Don\u{2019}t have a link? Type keywords to search.")
                    .font(SableTypography.caption)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadingView(_ text: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text("No skills found for \"\(query)\"")
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
            Text("Try a different keyword or check the spelling.")
                .font(SableTypography.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results List (delegated)

    private var resultsListView: some View {
        SkillSearchResultsView(
            results: results,
            installedSkillIDs: installedSkillIDs,
            errorMessage: errorMessage,
            showError: phase == .failure
        ) { slug in
            loadDetail(slug: slug)
        }
    }

    // MARK: - Detail & Success (delegated)

    private func detailConfirmView(_ detail: SkillService.SkillDetail) -> some View {
        SkillDetailConfirmView(
            detail: detail,
            isInstalled: installedSkillIDs.contains(detail.slug),
            errorMessage: errorMessage,
            showError: phase == .failure,
            isInstalling: phase == .installing
        ) {
            installSkill(detail.slug)
        }
    }

    private func successView(slug: String) -> some View {
        SkillInstallSuccessView(slug: slug) { dismiss() }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                importLocalFolder()
            } label: {
                Label("Import Local Folder\u{2026}", systemImage: "folder.badge.plus")
                    .font(SableTypography.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            if let error = urlError {
                Text(error)
                    .font(SableTypography.micro)
                    .foregroundStyle(SableTheme.error)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    // MARK: - Actions

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        selectedDetail = nil

        // Primary path: URL or slug → resolve directly
        if let slug = SkillService.extractSlugFromInput(trimmed) {
            resolveSlug(slug)
            return
        }

        // Fallback path: keyword search
        searchKeyword(trimmed)
    }

    /// Direct slug/URL path: inspect first, fall back to keyword search on failure.
    private func resolveSlug(_ slug: String) {
        navigationTask?.cancel()
        phase = .resolving
        errorMessage = nil

        navigationTask = Task {
            let detail = await SkillService.inspectSkill(slug: slug)
            guard !Task.isCancelled else { return }
            if let detail {
                selectedDetail = detail
                phase = .detail
            } else {
                // Slug not found — fall back to keyword search
                searchKeyword(slug)
            }
        }
    }

    /// Keyword search path.
    private func searchKeyword(_ keyword: String) {
        navigationTask?.cancel()
        phase = .searching

        navigationTask = Task {
            let searchResults = await SkillService.searchRegistry(query: keyword)
            guard !Task.isCancelled else { return }
            if searchResults.isEmpty {
                phase = .noResults
            } else {
                results = searchResults
                phase = .results
            }
        }
    }

    /// Load detail for a search result row click.
    private func loadDetail(slug: String) {
        navigationTask?.cancel()
        selectedDetail = nil
        phase = .loadingDetail
        errorMessage = nil

        navigationTask = Task {
            let detail = await SkillService.inspectSkill(slug: slug)
            guard !Task.isCancelled else { return }
            if let detail {
                selectedDetail = detail
                phase = .detail
            } else {
                errorMessage = "Could not load details for \"\(slug)\"."
                phase = .failure
            }
        }
    }

    private func installSkill(_ slug: String) {
        // Guard: only allow one install attempt at a time
        guard phase != .installing, !installCompleted else { return }
        phase = .installing
        errorMessage = nil

        Task {
            let result = await SkillService.installSkill(slug: slug)

            // Guard: if already completed (shouldn't happen, but safety)
            guard !installCompleted else { return }

            switch result {
            case .success(let installedSlug, _):
                installCompleted = true
                phase = .success(slug: installedSlug)
                onInstalled?(installedSlug)

            case .failure(let message):
                errorMessage = message
                phase = .failure
            }
        }
    }

    private func importLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a skill folder containing SKILL.md"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let skillMD = url.appendingPathComponent("SKILL.md")
        if FileManager.default.fileExists(atPath: skillMD.path) {
            performImport(from: url)
        } else {
            // No SKILL.md — run diagnostics
            urlError = nil
            importDiagnostic = ImportDiagnostic.diagnose(folder: url)
        }
    }

    private func performImport(from url: URL) {
        let skillName = url.lastPathComponent
        let dest = WorkspaceService.workspaceDirectory
            .appendingPathComponent("skills")
            .appendingPathComponent(skillName)

        do {
            try FileManager.default.createDirectory(
                at: dest.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            urlError = nil
            installCompleted = true
            onInstalled?(skillName)
            phase = .success(slug: skillName)
        } catch {
            urlError = "Import failed: \(error.localizedDescription)"
        }
    }

}
