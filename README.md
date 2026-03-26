<p align="center">
  <img src="Sable/Resources/Assets.xcassets/AppIcon.appiconset/icon_256.png" width="128" height="128" alt="Sable">
</p>

<h1 align="center">Sable</h1>

<p align="center">
  <strong>Native macOS cockpit for AI agents</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-black?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-black?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/ui-SwiftUI-black?style=flat-square" alt="SwiftUI">
  <img src="https://img.shields.io/badge/license-MIT-black?style=flat-square" alt="License">
</p>

---

Sable is a native macOS desktop application that serves as a unified cockpit for interacting with AI agents through the [OpenClaw](https://github.com/openclaw/openclaw) framework. Built entirely with SwiftUI and SwiftData — zero external dependencies.

Think of it as a local-first, privacy-respecting alternative to web-based AI chat interfaces, with deep integration into agent workflows, tool execution, and multi-provider support.

## Features

### Chat
- **Real-time SSE streaming** with typewriter rendering — not fake delays, actual server-sent events
- **Tool call visibility** — see what the agent is doing (searching, reading, executing) in real time
- **Reasoning blocks** — collapsible thinking process display for reasoning models
- **Auto-retry** — transient failures (timeouts, 502/503) retry automatically with exponential backoff, like Claude and ChatGPT
- **Rich content** — Markdown rendering, code blocks with syntax differentiation, image attachments, file uploads
- **Message actions** — copy, regenerate, delete via hover overlay (no clutter)

### Multi-Provider
- **OpenClaw Gateway** — primary channel via `/v1/responses` API (SSE streaming)
- **Direct API** — Anthropic, OpenAI, Google Gemini, Moonshot Kimi, Ollama
- **Model discovery** — auto-detect available models from each provider
- **API keys** — stored in macOS Keychain, never in config files

### Agent Management
- Browse, configure, and edit OpenClaw agents
- Skill browser with one-click installation
- Real-time gateway health monitoring

### Design
- **Monochrome design system** — zero accent colors, hierarchy through opacity and weight
- **Dark & Light mode** — full support with semantic color tokens
- **Localization** — English and Chinese
- **Menu bar extra** — quick access from the system tray

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Xcode 16+
- [OpenClaw](https://github.com/openclaw/openclaw) (for gateway features)

### Build from Source

```bash
# Clone
git clone https://github.com/Dglsel/Sable.git
cd Sable

# Generate Xcode project
xcodegen generate

# Open in Xcode and build (⌘B), or:
xcodebuild -project Sable.xcodeproj -scheme Sable -destination 'platform=macOS' build
```

### Configure OpenClaw (Optional)

If you want to use the OpenClaw gateway for agent features:

```bash
# Install OpenClaw
curl -fsSL https://openclaw.ai/install.sh | bash

# Start the gateway
openclaw gateway start
```

Sable reads gateway configuration from `~/.openclaw/openclaw.json` automatically.

You can also use Sable as a standalone chat client by configuring provider API keys directly in Settings.

## Architecture

```
Sable/
├── App/                    # Entry point, DI container, window management
├── Features/               # Feature modules
│   ├── Chat/              # Message list, composer, streaming, typewriter
│   ├── Dashboard/         # Gateway status, health monitoring
│   ├── Agents/            # Agent browser & editor
│   ├── Skills/            # Skill browser & installer
│   ├── Settings/          # Provider config, appearance, data management
│   ├── Sidebar/           # Navigation, conversation history
│   └── MenuBar/           # System tray panel
├── Core/                   # Shared infrastructure
│   ├── DesignSystem/      # Tokens: theme, typography, spacing, animation
│   ├── Models/            # SwiftData entities (Conversation, Message)
│   ├── Types/             # Value types, enums, configuration
│   └── Utilities/         # Helpers
├── Services/               # Service layer
│   ├── OpenClaw/          # Gateway client, ACP protocol, SSE streaming
│   ├── Providers/         # Multi-provider abstraction (Anthropic, OpenAI, etc.)
│   ├── Security/          # Keychain integration
│   └── Persistence/       # SwiftData container management
└── Resources/              # Assets, localization strings
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Zero dependencies** | No SPM packages — ships with only Apple frameworks |
| **SwiftData over Core Data** | Type-safe, modern persistence with `@Model` macro |
| **SSE over WebSocket** | Simpler protocol, better compatibility with HTTP infrastructure |
| **Monochrome UI** | Intentional differentiation — content takes center stage |
| **XcodeGen** | Reproducible project generation, no `.xcodeproj` conflicts in git |
| **Keychain for secrets** | OS-level encryption, never stored in files or UserDefaults |

### Streaming Pipeline

```
User Input
  → URLContentFetcher (extract web content from URLs in prompt)
  → OpenResponsesService (POST /v1/responses, SSE stream)
  → StreamEvent enum (.delta, .toolCall, .reasoningDelta, .completed, .retrying)
  → ChatHomeView (state management, message accumulation)
  → TypewriterState (character-by-character rendering at 60fps)
  → MessageListView (LazyVStack + auto-scroll)
```

## Contributing

Contributions are welcome. Here's how to get started:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run `xcodegen generate` if you added/removed files
5. Build and test (`⌘B` in Xcode)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Areas That Need Help

- **Unit tests** — test coverage is minimal, especially for services and parsing logic
- **Accessibility** — VoiceOver support, keyboard navigation
- **Performance** — LazyVStack optimization for very long conversations
- **Localization** — additional language support beyond English and Chinese
- **Code syntax highlighting** — monochrome weight/opacity-based differentiation

### Code Style

- Swift 6 strict concurrency — all `@MainActor` annotations are intentional
- Design tokens are defined in `Core/DesignSystem/` — never hardcode colors, fonts, or spacing
- Read `DESIGN.md` before making visual changes

## License

[MIT](LICENSE) — use it however you want.
