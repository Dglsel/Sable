# Contributing to Sable

Thanks for your interest in contributing.

## Quick Start

```bash
git clone https://github.com/Dglsel/Sable.git
cd Sable
xcodegen generate
open Sable.xcodeproj
```

## Pull Requests

- One fix per PR — don't bundle unrelated changes
- Run `xcodegen generate` if you added or removed files
- Build must pass (`⌘B`) before submitting
- Follow the existing code style (Swift 6 concurrency, design tokens from `Core/DesignSystem/`)
- Read `DESIGN.md` before making any visual changes

## Design Rules

- **No accent colors** — use opacity shifts only
- **No hardcoded values** — reference `SableTheme`, `SableTypography`, `SableSpacing`
- **Semantic color only** — success, warning, error, info

## Bug Reports

Use the [Bug Report](https://github.com/Dglsel/Sable/issues/new?template=bug_report.yml) template. Include:
- Steps to reproduce
- macOS version
- Screenshots if visual

## Security

If you find a security vulnerability, **do not open a public issue**. Email the maintainer directly.
