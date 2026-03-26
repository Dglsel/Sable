import Foundation

/// Represents a section of the OpenClaw Agent workspace.
/// Each section maps to a real file in `~/.openclaw/workspace/`.
enum AgentSection: String, CaseIterable, Identifiable {
    case instructions
    case soul
    case identity
    case user
    case tools
    case heartbeat
    case memory
    case bootstrap
    case boot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instructions: "Instructions"
        case .soul: "Soul"
        case .identity: "Identity"
        case .user: "User"
        case .tools: "Tools"
        case .heartbeat: "Heartbeat"
        case .memory: "Memory"
        case .bootstrap: "Bootstrap"
        case .boot: "Boot"
        }
    }

    var icon: String {
        switch self {
        case .instructions: "doc.text"
        case .soul: "sparkles"
        case .identity: "person.text.rectangle"
        case .user: "person.crop.circle"
        case .tools: "wrench.and.screwdriver"
        case .heartbeat: "heart.text.square"
        case .memory: "brain.head.profile"
        case .bootstrap: "bolt"
        case .boot: "power"
        }
    }

    /// The workspace file this section maps to.
    var fileName: String {
        switch self {
        case .instructions: "AGENTS.md"
        case .soul: "SOUL.md"
        case .identity: "IDENTITY.md"
        case .user: "USER.md"
        case .tools: "TOOLS.md"
        case .heartbeat: "HEARTBEAT.md"
        case .memory: "MEMORY.md"
        case .bootstrap: "BOOTSTRAP.md"
        case .boot: "BOOT.md"
        }
    }

    /// Whether this section is shown by default (primary) or only in advanced mode.
    var isDefault: Bool {
        switch self {
        case .instructions, .soul, .identity, .user, .tools, .heartbeat, .memory:
            true
        case .bootstrap, .boot:
            false
        }
    }

    /// Brief description of this section's purpose.
    var summary: String {
        switch self {
        case .instructions:
            "Primary directive file that defines the agent's task instructions, constraints, and behavioral boundaries."
        case .soul:
            "Defines the agent's personality, tone, communication style, and core values."
        case .identity:
            "Sets the agent's name, role description, and how it introduces itself to users."
        case .user:
            "Stores information about the user to personalize agent interactions and responses."
        case .tools:
            "Declares which tools, APIs, and external integrations the agent can access."
        case .heartbeat:
            "Configures periodic health checks and cron-style recurring tasks for the agent."
        case .memory:
            "Manages the agent's persistent memory, context retention, and knowledge base."
        case .bootstrap:
            "Defines initialization steps the agent executes on startup or first launch."
        case .boot:
            "Optional boot script that runs once when the agent process starts."
        }
    }

    /// Detailed guide for the section info card.
    var guide: SectionGuide {
        switch self {
        case .instructions:
            SectionGuide(
                what: "Tell your agent what to do and what not to do. This is the primary directive — task rules, constraints, behavioral boundaries.",
                affects: "Every response. This is the first file the agent reads before acting.",
                versus: "Soul defines who the agent is. Instructions defines what it should do."
            )
        case .soul:
            SectionGuide(
                what: "Define your agent's personality — tone, values, communication style. This is the agent's character, not its task list.",
                affects: "How the agent speaks, what it cares about, how it handles ambiguity.",
                versus: "Instructions tells the agent what to do. Soul tells it how to be."
            )
        case .identity:
            SectionGuide(
                what: "Give your agent a name, a creature type, a vibe. This is its self-concept — how it thinks of itself and introduces itself.",
                affects: "Self-references, introductions, avatar display.",
                versus: "Soul is personality and values. Identity is name and self-image."
            )
        case .user:
            SectionGuide(
                what: "Tell the agent about yourself — your name, timezone, preferences, context. The more it knows, the better it can personalize.",
                affects: "Personalization, time-aware responses, tone calibration.",
                versus: "Identity is about the agent. User is about you."
            )
        case .tools:
            SectionGuide(
                what: "Document your local setup — device names, SSH hosts, API keys, TTS voices. This helps the agent use your tools correctly.",
                affects: "Tool invocation, device targeting, integration accuracy.",
                versus: "Instructions defines rules. Tools defines what the agent can reach."
            )
        case .heartbeat:
            SectionGuide(
                what: "Add tasks the agent should check periodically — monitoring, reminders, recurring checks. Leave empty to disable heartbeat.",
                affects: "Cron-style periodic behavior. The agent runs these tasks on a schedule.",
                versus: "Instructions runs on every prompt. Heartbeat runs on a timer, even when you're away."
            )
        case .memory:
            SectionGuide(
                what: "Long-term memory index. The agent reads this to recall context across sessions. Think of it as the table of contents for what it remembers.",
                affects: "Cross-session continuity, context recall, relationship building.",
                versus: "MEMORY.md is the long-term index. Daily memories go to workspace/memory/*.md files."
            )
        case .bootstrap:
            SectionGuide(
                what: "Initialization steps the agent runs on startup. Used for environment checks, dependency verification, or first-run setup.",
                affects: "Agent startup behavior. Runs before the agent is ready to interact.",
                versus: "Boot runs the process. Bootstrap runs the setup within it."
            )
        case .boot:
            SectionGuide(
                what: "Low-level boot script that runs once when the agent process starts. Most users don't need to edit this.",
                affects: "Process-level initialization. Runs before everything else.",
                versus: "Bootstrap is setup logic. Boot is process-level startup."
            )
        }
    }

    struct SectionGuide {
        /// What this file does.
        let what: String
        /// What part of the agent it affects.
        let affects: String
        /// How it differs from the most commonly confused section.
        let versus: String
    }

    /// Sections shown by default in the Agents page.
    static var defaultSections: [AgentSection] {
        allCases.filter(\.isDefault)
    }

    /// Sections only visible when advanced mode is toggled on.
    static var advancedSections: [AgentSection] {
        allCases.filter { !$0.isDefault }
    }
}
