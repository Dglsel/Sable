import SwiftUI

struct SkillsView: View {
    @Environment(OpenClawService.self) private var openClaw
    @Environment(\.colorScheme) private var colorScheme

    @State private var skills: [SkillService.SkillInfo] = []
    @State private var selectedSkillID: String?
    @State private var isLoading = false
    @State private var filter: SkillFilter = .all
    @State private var showInstallSheet = false
    @State private var scrollTarget: String?
    @State private var installWarning: InvalidSkillWarning?

    private var installedSkillIDs: Set<String> {
        Set(skills.map(\.id))
    }

    private var selectedSkill: SkillService.SkillInfo? {
        guard let id = selectedSkillID else { return nil }
        return skills.first { $0.id == id }
    }

    private var filteredSkills: [SkillService.SkillInfo] {
        switch filter {
        case .all: skills
        case .ready: skills.filter { $0.status == .ready }
        case .missing: skills.filter { $0.status == .missing }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if openClaw.status.isOnboarded {
                skillsContent
            } else {
                notOnboardedPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SableTheme.chatBackground)
        .onExitCommand {
            selectedSkillID = nil
        }
        .sheet(isPresented: $showInstallSheet) {
            SkillInstallSheet(installedSkillIDs: installedSkillIDs) { installedSlug in
                Task {
                    await refreshSkillsSilently()
                    if !selectAndScroll(installedSlug) {
                        installWarning = Self.diagnoseInstalledSkill(slug: installedSlug)
                    }
                }
            }
        }
        .alert("Invalid Skill Package", isPresented: Binding(
            get: { installWarning != nil },
            set: { if !$0 { installWarning = nil } }
        )) {
            if let warning = installWarning, let path = warning.folderPath {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                    installWarning = nil
                }
            }
            Button("OK", role: .cancel) { installWarning = nil }
        } message: {
            Text(installWarning?.message ?? "")
        }
    }

    // MARK: - Main Content

    private var skillsContent: some View {
        HStack(spacing: 0) {
            skillListPanel
                .frame(width: 280)

            Divider()

            skillDetailPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            if skills.isEmpty {
                await loadSkills()
            } else {
                await refreshSkillsSilently()
            }
        }
    }

    // MARK: - Left Panel: Skill List

    private var skillListPanel: some View {
        VStack(spacing: 0) {
            listHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            if isLoading && skills.isEmpty {
                skeletonList
            } else if filteredSkills.isEmpty {
                Spacer()
                Text("No skills found")
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredSkills) { skill in
                                skillRow(skill)
                                    .id(skill.id)
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        .padding(.vertical, 4)
                        .animation(SableAnimation.move(), value: filteredSkills.map(\.id))
                    }
                    .onAppear {
                        // Scroll to selected item when list first appears (initial load or post-install)
                        scrollToSelected(proxy: proxy)
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let id = target else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                            scrollTarget = nil
                        }
                    }
                }
            }

            Divider()

            listFooter
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(SableTheme.sidebarBackground(colorScheme))
    }

    private func scrollToSelected(proxy: ScrollViewProxy) {
        guard let id = selectedSkillID,
              filteredSkills.contains(where: { $0.id == id }) else { return }
        // Slight delay for LazyVStack to lay out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private var listHeader: some View {
        HStack(spacing: 8) {
            Picker("", selection: $filter) {
                ForEach(SkillFilter.allCases) { f in
                    Text(f.label).tag(f)
                }
            }
            .labelsHidden()
            .frame(width: 90)

            Spacer()

            Button {
                showInstallSheet = true
            } label: {
                Label("Install", systemImage: "plus.circle")
                    .font(SableTypography.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Button {
                Task {
                    if skills.isEmpty {
                        await loadSkills()
                    } else {
                        await refreshSkillsSilently()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isLoading)
        }
    }

    private func skillRow(_ skill: SkillService.SkillInfo) -> some View {
        Button {
            selectedSkillID = skill.id
        } label: {
            HStack(spacing: 8) {
                Text(skill.emoji)
                    .font(SableTypography.label)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(.system(size: 12, weight: selectedSkillID == skill.id ? .semibold : .medium))
                        .foregroundStyle(selectedSkillID == skill.id ? .white : .primary)
                        .lineLimit(1)

                    Text(skill.description)
                        .font(SableTypography.micro)
                        .foregroundStyle(selectedSkillID == skill.id ? Color.white.opacity(0.65) : .secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusBadge(skill.status)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selectedSkillID == skill.id
                    ? SableTheme.gray600
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: SableRadius.md)
            )
            .contentShape(RoundedRectangle(cornerRadius: SableRadius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func statusBadge(_ status: SkillService.SkillInfo.Status) -> some View {
        Text(status.label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(statusColor(status).opacity(0.12), in: Capsule())
    }

    private func statusColor(_ status: SkillService.SkillInfo.Status) -> Color {
        switch status {
        case .ready: SableTheme.success
        case .missing: SableTheme.warning
        case .disabled: SableTheme.textSecondary
        }
    }

    private var listFooter: some View {
        HStack {
            let readyCount = skills.filter { $0.status == .ready }.count
            Text("\(readyCount)/\(skills.count) ready")
                .font(SableTypography.micro)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - Skeleton Loading

    private static let skeletonWidths: [(CGFloat, CGFloat)] = [
        (100, 160), (120, 140), (90, 170), (130, 150),
        (110, 130), (95, 175), (125, 145), (105, 155),
        (115, 165), (85, 135), (120, 150), (100, 140)
    ]

    private var skeletonList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(0..<12, id: \.self) { i in
                    let widths = Self.skeletonWidths[i]
                    skeletonRow(nameWidth: widths.0, descWidth: widths.1)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func skeletonRow(nameWidth: CGFloat, descWidth: CGFloat) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: SableRadius.sm, style: .continuous)
                .fill(SableTheme.bgHover)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: SableRadius.sm, style: .continuous)
                    .fill(SableTheme.bgActive)
                    .frame(width: nameWidth, height: 10)
                RoundedRectangle(cornerRadius: SableRadius.sm, style: .continuous)
                    .fill(SableTheme.bgHover)
                    .frame(width: descWidth, height: 8)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .shimmering()
    }

    // MARK: - Right Panel: Detail

    @ViewBuilder
    private var skillDetailPanel: some View {
        if let skill = selectedSkill {
            SkillDetailView(skill: skill, onUninstalled: {
                let removedID = skill.id
                // 1. Clear selection immediately
                selectedSkillID = nil
                // 2. Animate the skill out of the list
                withAnimation(SableAnimation.move()) {
                    skills.removeAll { $0.id == removedID }
                }
                // 3. Sync with CLI in background (no spinner)
                Task { await refreshSkillsSilently() }
            })
        } else {
            emptyDetailPlaceholder
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Select a skill to view details")
                .font(SableTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Not Onboarded

    private var notOnboardedPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Skills not available")
                .font(SableTypography.title)
            Text("Complete OpenClaw onboarding from the Dashboard to manage skills.")
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private func loadSkills() async {
        isLoading = true
        let result = await SkillService.fetchSkills()
        withAnimation(SableAnimation.enter(duration: SableAnimation.slow)) {
            skills = result
            isLoading = false
        }
    }

    /// Refresh from CLI without showing the loading spinner.
    /// Used after uninstall to sync state without UI flicker.
    private func refreshSkillsSilently() async {
        let result = await SkillService.fetchSkills()
        withAnimation(SableAnimation.move()) {
            skills = result
        }
    }

    /// Select and scroll to a skill — used after install for full closedloop.
    /// `identifier` can be either the registry slug or the skill name.
    /// Returns `true` if the skill was found and selected.
    @discardableResult
    private func selectAndScroll(_ identifier: String) -> Bool {
        guard let skill = skills.first(where: {
            $0.id == identifier || $0.registrySlug == identifier || $0.workspaceFolderName == identifier
        }) else { return false }
        selectedSkillID = skill.id
        scrollTarget = skill.id
        return true
    }

    /// Diagnose why an installed skill wasn't recognized by OpenClaw.
    /// Checks the actual folder on disk for SKILL.md issues.
    private static func diagnoseInstalledSkill(slug: String) -> InvalidSkillWarning {
        let skillsDir = WorkspaceService.workspaceDirectory.appendingPathComponent("skills")
        let fm = FileManager.default

        // Find the folder — could be slug, slug-version, etc.
        let folders = (try? fm.contentsOfDirectory(atPath: skillsDir.path))?.filter { !$0.hasPrefix(".") } ?? []
        let matchedFolder = folders.first { $0 == slug || $0.hasPrefix(slug) }

        guard let folder = matchedFolder else {
            return InvalidSkillWarning(
                message: "\"\(slug)\" was downloaded but the skill folder was not found on disk.",
                folderPath: nil
            )
        }

        let folderURL = skillsDir.appendingPathComponent(folder)
        let skillMDPath = folderURL.appendingPathComponent("SKILL.md")

        // Check if SKILL.md exists
        guard fm.fileExists(atPath: skillMDPath.path) else {
            return InvalidSkillWarning(
                message: "\"\(slug)\" was downloaded but does not contain a SKILL.md file. OpenClaw requires SKILL.md with valid YAML frontmatter to register a skill.",
                folderPath: folderURL.path
            )
        }

        // SKILL.md exists — check frontmatter validity
        guard let content = try? String(contentsOf: skillMDPath, encoding: .utf8) else {
            return InvalidSkillWarning(
                message: "\"\(slug)\" has a SKILL.md file but it could not be read.",
                folderPath: folderURL.path
            )
        }

        // Check for YAML frontmatter delimiters
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            return InvalidSkillWarning(
                message: "\"\(slug)\" has a SKILL.md but it is missing YAML frontmatter. The file must start with \"---\" followed by name, description, and emoji fields.",
                folderPath: folderURL.path
            )
        }

        // Check required fields
        let lines = content.components(separatedBy: "\n")
        let hasName = lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("name:") }
        let hasDescription = lines.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix("description:") }

        var missing: [String] = []
        if !hasName { missing.append("name") }
        if !hasDescription { missing.append("description") }

        if !missing.isEmpty {
            return InvalidSkillWarning(
                message: "\"\(slug)\" has a SKILL.md but is missing required fields: \(missing.joined(separator: ", ")). OpenClaw needs at least name and description in the YAML frontmatter.",
                folderPath: folderURL.path
            )
        }

        // Frontmatter looks OK — unknown reason
        return InvalidSkillWarning(
            message: "\"\(slug)\" has a SKILL.md with frontmatter, but OpenClaw did not recognize it. The YAML syntax may be invalid — check for indentation or quoting issues.",
            folderPath: folderURL.path
        )
    }
}

// MARK: - Invalid Skill Warning

struct InvalidSkillWarning {
    let message: String
    let folderPath: String?
}

// MARK: - Filter

enum SkillFilter: String, CaseIterable, Identifiable {
    case all
    case ready
    case missing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .ready: "Ready"
        case .missing: "Missing"
        }
    }
}

// MARK: - Shimmer Effect

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.4), location: phase - 0.2),
                        .init(color: .white, location: phase),
                        .init(color: .white.opacity(0.4), location: phase + 0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 2
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
