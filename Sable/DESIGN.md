# Design System — Sable

## Product Context
- **What this is:** macOS native desktop app — daily cockpit for OpenClaw AI agent framework
- **Who it's for:** Developers and security researchers who manage AI agents
- **Space/industry:** AI agent management tools (peers: Claude Desktop, ChatGPT Desktop, Raycast, Warp, Linear)
- **Project type:** Desktop app — dashboard + agent editor + chat

## Aesthetic Direction
- **Direction:** Industrial/Utilitarian — Monochrome
- **Decoration level:** Minimal — zero decorative elements, zero accent color
- **Mood:** Precise, silent, functional. A tool that disappears into the work. Color only appears when it means something (semantic states). Everything else is black, white, and gray.
- **Core principle:** Hierarchy through opacity, not hue. Interactive states use intensity shifts, not color changes.

## Typography
- **System:** SF Pro (macOS system font) — no custom fonts
- **Display/Hero:** `.system(size: 20, weight: .semibold)` — empty states, onboarding headings
- **Title:** `.system(size: 15, weight: .semibold)` — page/section titles, agent names
- **Subtitle:** `.system(size: 13, weight: .semibold)` — card titles, group names
- **Message Body:** `.system(size: 13.5, weight: .regular)` — chat messages, editor content
- **Body:** `.system(size: 13, weight: .regular)` — descriptions, settings, secondary content
- **Label:** `.system(size: 13, weight: .medium)` — buttons, form fields, list items
- **Label Small:** `.system(size: 12, weight: .regular)` — secondary info, badges
- **Caption:** `.system(size: 11, weight: .regular)` — timestamps, token counts, metadata
- **Micro:** `.system(size: 10, weight: .regular)` — dense UI, version numbers (use sparingly)
- **Code Inline:** `.system(size: 12.5, design: .monospaced)` — backtick spans
- **Code Block:** `.system(size: 12.5, design: .monospaced)` — fenced code, CLI output
- **Code Label:** `.system(size: 11, weight: .medium, design: .monospaced)` — language headers
- **Mono:** `.system(size: 11, design: .monospaced)` — model IDs, session keys
- **Markdown Headings:** H1=16/semibold, H2=15/semibold, H3=14/semibold, H4+=13.5/medium
- **Rationale:** 13pt base matches macOS native density. 13.5pt for messages adds readability where users spend the most time. System fonts give perfect native feel.

## Color

### Approach: Monochrome + Semantic-only
Zero accent color. The entire app is black/white/gray. Color appears exclusively for semantic states.

### Interactive Opacity Scale (Dark Mode)
| Token | Value | Usage |
|-------|-------|-------|
| `text-primary` | `white 92%` | Headings, body text, primary content |
| `interactive` | `white 85%` | Buttons, send icon, active elements |
| `interactive-hover` | `white 100%` | Hover state for interactive elements |
| `text-secondary` | `white 56%` | Secondary text, descriptions |
| `interactive-muted` | `white 50%` | Disabled interactive, subtle indicators |
| `text-tertiary` | `white 32%` | Captions, hints, timestamps |
| `text-ghost` | `white 18%` | Placeholder text, dividers |

### Interactive Opacity Scale (Light Mode)
| Token | Value | Usage |
|-------|-------|-------|
| `text-primary` | `black 88%` | Headings, body text, primary content |
| `interactive` | `black 80%` | Buttons, send icon, active elements |
| `interactive-hover` | `black 95%` | Hover state for interactive elements |
| `text-secondary` | `black 50%` | Secondary text, descriptions |
| `interactive-muted` | `black 42%` | Disabled interactive, subtle indicators |
| `text-tertiary` | `black 28%` | Captions, hints, timestamps |
| `text-ghost` | `black 14%` | Placeholder text, dividers |

### Surface Colors (Dark Mode)
| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `bg-primary` | — | `#1A1A1C` | Main window background |
| `bg-secondary` | — | `#1F1F22` | Sidebar background |
| `bg-tertiary` | — | `#26262A` | Cards, elevated surfaces |
| `bg-elevated` | — | `#2C2C32` | Hover menus, popovers |
| `bg-hover` | `white 5%` | — | Hover overlay |
| `bg-active` | `white 8%` | — | Active/selected overlay |
| `bg-bubble-user` | — | `#2A2A2E` | User chat bubbles |
| `bg-bubble-assistant` | — | `#222226` | Assistant chat bubbles |
| `bg-input` | — | `#222226` | Input fields |
| `border` | `white 7%` | — | Default borders |
| `border-strong` | `white 13%` | — | Emphasized borders |
| `border-focus` | `white 28%` | — | Focus rings |

### Surface Colors (Light Mode)
| Token | Value | Hex | Usage |
|-------|-------|-----|-------|
| `bg-primary` | — | `#FFFFFF` | Main window background |
| `bg-secondary` | — | `#F6F6F7` | Secondary areas |
| `bg-tertiary` | — | `#EFEFEF` | Cards, elevated surfaces |
| `bg-elevated` | — | `#FFFFFF` | Hover menus, popovers |
| `bg-hover` | `black 4%` | — | Hover overlay |
| `bg-active` | `black 7%` | — | Active/selected overlay |
| `bg-bubble-user` | — | `#F0F0F2` | User chat bubbles |
| `bg-bubble-assistant` | — | `#FFFFFF` | Assistant chat bubbles |
| `bg-input` | — | `#FFFFFF` | Input fields |
| `sidebar-bg` | — | `#EAEAEB` | Sidebar background |
| `border` | `black 7%` | — | Default borders |
| `border-strong` | `black 14%` | — | Emphasized borders |
| `border-focus` | `black 32%` | — | Focus rings |

### Neutral Scale
| Token | Hex |
|-------|-----|
| Gray-50 | `#F5F5F6` |
| Gray-100 | `#E7E7E8` |
| Gray-200 | `#D4D4D6` |
| Gray-300 | `#B0B0B4` |
| Gray-400 | `#8A8A90` |
| Gray-500 | `#6A6A72` |
| Gray-600 | `#4A4A52` |
| Gray-700 | `#34343A` |
| Gray-800 | `#28282E` |
| Gray-850 | `#232328` |
| Gray-900 | `#1F1F22` |
| Gray-950 | `#141416` |

### Semantic Colors (the only color in the app)
| Token | Hex | Usage |
|-------|-----|-------|
| Success | `#6B9B7C` | Gateway running, health check pass, positive states |
| Warning | `#B0923E` | High usage, approaching limits, caution states |
| Error | `#B05A52` | Connection failed, gateway down, critical states |
| Info | `#7C909C` | Informational notices, updates available |

Semantic colors are deliberately desaturated — they should be readable but never dominate the UI. Use at 8% opacity for backgrounds, 18% for borders.

### Code Syntax (Dimmed)
Ultra-low saturation syntax colors — tinted grays, not full-spectrum. Same restraint as semantic colors. Must not break the monochrome feel at a glance.

| Token | Dark Mode | Light Mode | Usage |
|-------|-----------|------------|-------|
| `code-keyword` | `#9B8AA4` | `#7A6B84` | Keywords: `function`, `require`, `external`, `if`, `return` |
| `code-function` | `#8A9BA4` | `#5A7080` | Function names, method calls |
| `code-string` | `#8A9B8C` | `#5A7A60` | String literals, template strings |
| `code-comment` | `white 32%` | `black 28%` | Comments — uses text-tertiary, no tint |
| `code-number` | `#A49B8A` | `#847A62` | Numeric literals, hex values |
| `code-type` | `#8AA4A4` | `#5A8080` | Type names, annotations |
| `code-operator` | `white 56%` | `black 50%` | Operators — uses text-secondary, no tint |

Design notes:
- All syntax colors sit within 12-18% saturation — barely colored, mostly gray with a tint
- Dark mode colors are lighter (pastel-gray), light mode colors are darker (muted-gray)
- Comments and operators use the existing neutral opacity scale, no dedicated color
- At normal reading distance, the code block should still read as "grayscale with hints"

## Spacing
- **Base unit:** 4px
- **Density:** Compact — professional tool, not consumer app

| Token | Value |
|-------|-------|
| `2xs` | 2px |
| `xs` | 4px |
| `sm` | 6px |
| `md` | 8px |
| `base` | 10px |
| `lg` | 12px |
| `xl` | 16px |
| `2xl` | 20px |
| `3xl` | 24px |
| `4xl` | 32px |
| `5xl` | 48px |
| `6xl` | 64px |

## Layout
- **Approach:** Grid-disciplined — standard macOS sidebar + content pattern
- **Sidebar:** min 220, ideal 240, max 260
- **Chat column max width:** 680px
- **Message bubble max width:** 620px (within chat column)
- **User message max width:** 520px
- **Composer max width:** 680px
- **Chat column leading inset:** 32px
- **Composer leading inset:** 24px

### Border Radius
| Token | Value | Usage |
|-------|-------|-------|
| `sm` | 4px | Badges, tags, small chips |
| `md` | 6px | Buttons, inputs, dropdowns |
| `lg` | 8px | Cards, sidebar items, containers |
| `xl` | 12px | Large cards, mockup containers |
| `2xl` | 16px | Message bubbles |
| `pill` | 18px | Input bar, search fields |
| `full` | 9999px | Circles, send button, status dots |

## Motion
- **Approach:** Minimal-functional — only transitions that aid comprehension

### Duration Tokens
| Token | Value | Usage |
|-------|-------|-------|
| `micro` | 80ms | Press feedback, button compression |
| `fast` | 120ms | Hover states, toggles, color shifts |
| `normal` | 200ms | Expand/collapse, modals, focus ring |
| `slow` | 350ms | Page transitions, large state changes |
| `entrance` | 420ms | Message appearance, view transitions |

### Spring Presets (SwiftUI)
| Preset | Response | Damping | Usage |
|--------|----------|---------|-------|
| `interactive` | 0.25 | 0.92 | UI feedback, button press |
| `bouncy` | 0.38 | 0.78 | Entrance animations |
| `gentle` | 0.55 | 0.75 | Large element entrance |

### Easing
- **Enter:** `easeOut` — things appearing
- **Exit:** `easeIn` — things leaving
- **Move:** `easeInOut` — things transitioning

## Button Styles
| Style | Dark Mode | Light Mode | Usage |
|-------|-----------|------------|-------|
| Primary | `white 85%` bg, dark text | `black 80%` bg, white text | Main actions (Start Gateway) |
| Secondary | `bg-elevated` + `border-strong` | Same | Secondary actions (Settings, Restart) |
| Ghost | Transparent, `text-secondary` | Same | Cancel, dismissive actions |
| Danger | Transparent, `error` text + border | Same | Destructive actions (Stop, Delete) |

## Rules
1. **No accent color.** Never add a colored accent. Interactive = opacity shift.
2. **Color = meaning.** If it has color, it must be semantic (success/warning/error/info).
3. **Use tokens.** Never hardcode `.system(size: N)`, `.opacity(0.X)`, or hex colors in views.
4. **Dark mode first.** Design for dark, verify in light.
5. **Density over decoration.** Prefer tighter spacing with more content over generous whitespace.
6. **Light mode is secondary.** All design decisions target dark mode first. Light mode is functional but lower priority — allow post-launch refinement.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-23 | Monochrome — no accent color | User chose fully achromatic direction. Color reserved for semantic states only. Differentiates from peers (Claude orange, ChatGPT green) through deliberate absence. |
| 2026-03-23 | Desaturated semantic colors | Success #6B9B7C, Warning #B0923E, Error #B05A52, Info #7C909C — readable but never dominate the monochrome UI |
| 2026-03-23 | SF Pro system fonts only | macOS native app — system fonts give perfect native feel, no brand differentiation needed |
| 2026-03-23 | 4px spacing base, 12-step scale | Fills gaps in previous 5-token system (6/10/16/24/32). Covers all use cases from 2px micro to 64px section gaps |
| 2026-03-23 | 5 motion durations (consolidated from 12+) | Audit found inconsistent timing across codebase. Standardized to micro/fast/normal/slow/entrance |
| 2026-03-23 | 7-step border radius scale | Audit found 6 different ad-hoc values. Standardized: sm(4) through full(9999) |
| 2026-03-23 | Dimmed code syntax | Ultra-low saturation tinted grays (12-18% saturation), GitHub Dimmed Theme inspired. Maintains monochrome feel while giving enough differentiation for code readability |
| 2026-03-23 | Light mode secondary priority | Dark mode is the primary design target. Light mode functional but allows post-launch refinement |
