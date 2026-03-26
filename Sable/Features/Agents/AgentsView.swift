import SwiftUI

struct AgentsView: View {
    @Environment(OpenClawService.self) private var openClaw
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedSection: AgentSection?
    @State private var showAdvanced = false

    // Unsaved changes confirmation
    @State private var editorIsDirty = false
    @State private var pendingNavigation: PendingNavigation?
    @State private var showUnsavedConfirm = false
    @State private var editorSaveTrigger = false

    private enum PendingNavigation {
        case section(AgentSection)
        case deselect
    }

    private var workspacePath: String {
        "~/.openclaw/workspace/"
    }

    private var visibleSections: [AgentSection] {
        showAdvanced ? AgentSection.allCases : AgentSection.defaultSections
    }

    var body: some View {
        VStack(spacing: 0) {
            if openClaw.status.isOnboarded {
                agentContent
            } else {
                notOnboardedPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SableTheme.chatBackground)
        .onExitCommand {
            navigateAway(to: .deselect)
        }
        .confirmationDialog(
            "You have unsaved changes.",
            isPresented: $showUnsavedConfirm,
            titleVisibility: .visible
        ) {
            Button("Save & Switch") {
                editorSaveTrigger = true
            }
            Button("Discard", role: .destructive) {
                applyPendingNavigation()
            }
            Button("Cancel", role: .cancel) {
                pendingNavigation = nil
            }
        } message: {
            Text("Do you want to save your changes before leaving this section?")
        }
    }

    // MARK: - Main Content

    private var agentContent: some View {
        HStack(spacing: 0) {
            sectionList
                .frame(width: 200)
                .background(SableTheme.sidebarBackground(colorScheme))

            Divider()

            sectionDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Section List

    private var sectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                workspaceHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                ForEach(visibleSections) { section in
                    sectionRow(section)
                }

                advancedToggle
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
            }
        }
    }

    private var workspaceHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Workspace")
                    .font(SableTypography.captionMedium)
                    .foregroundStyle(.secondary)
            }
            Text(workspacePath)
                .font(SableTypography.mono)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func sectionRow(_ section: AgentSection) -> some View {
        Button {
            navigateAway(to: .section(section))
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(section.isDefault ? .primary : .secondary)
                    .frame(width: 16)
                Text(section.label)
                    .font(SableTypography.labelSmall)
                    .foregroundStyle(section.isDefault ? .primary : .secondary)
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                selectedSection == section
                    ? SableTheme.bgActive
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: SableRadius.md)
            )
            .contentShape(RoundedRectangle(cornerRadius: SableRadius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var advancedToggle: some View {
        Button {
            if showAdvanced, let sel = selectedSection, !sel.isDefault {
                // Collapsing while viewing an advanced section — need to deselect
                navigateAway(to: .deselect)
                // Only collapse if not blocked by unsaved changes
                if !showUnsavedConfirm {
                    withAnimation(SableAnimation.enter()) {
                        showAdvanced = false
                    }
                }
            } else {
                withAnimation(SableAnimation.enter()) {
                    showAdvanced.toggle()
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                Text("Advanced")
                    .font(SableTypography.caption)
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Detail

    @ViewBuilder
    private var sectionDetail: some View {
        if let section = selectedSection {
            if editableSections.contains(section) {
                AgentEditorView(
                    section: section,
                    isDirtyBinding: $editorIsDirty,
                    saveTrigger: $editorSaveTrigger,
                    onSaveCompleted: { applyPendingNavigation() }
                )
            } else {
                readOnlySectionDetail(section)
            }
        } else {
            emptyDetailPlaceholder
        }
    }

    private var emptyDetailPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Select a section to view or edit")
                .font(SableTypography.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Sections that have a working editor.
    private var editableSections: Set<AgentSection> {
        [.identity, .soul, .instructions, .user, .tools, .heartbeat, .memory]
    }

    /// Read-only detail view for advanced sections (bootstrap, boot).
    /// Shows purpose, guide info, and actual file content as a preview.
    private func readOnlySectionDetail(_ section: AgentSection) -> some View {
        AdvancedSectionView(section: section)
    }

    // MARK: - Navigation Guard

    /// Attempt to navigate away from the current section.
    /// If the editor has unsaved changes, show a confirmation dialog instead.
    private func navigateAway(to target: PendingNavigation) {
        // Already going to the same place — no-op
        if case .section(let s) = target, s == selectedSection { return }
        if case .deselect = target, selectedSection == nil { return }

        // Not in an editable section or not dirty — switch immediately
        guard editorIsDirty,
              let current = selectedSection,
              editableSections.contains(current) else {
            applyNavigation(target)
            return
        }

        pendingNavigation = target
        showUnsavedConfirm = true
    }

    /// Apply a navigation target (switch section or deselect).
    private func applyNavigation(_ target: PendingNavigation) {
        switch target {
        case .section(let s):
            selectedSection = s
        case .deselect:
            selectedSection = nil
        }
    }

    /// Apply the pending navigation and clear state.
    private func applyPendingNavigation() {
        guard let target = pendingNavigation else { return }
        pendingNavigation = nil
        applyNavigation(target)
    }

    // MARK: - Not Onboarded

    private var notOnboardedPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.badge.gearshape")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Agent workspace not available")
                .font(SableTypography.title)
            Text("Complete OpenClaw onboarding from the Dashboard to access the agent workspace.")
                .font(SableTypography.labelSmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
