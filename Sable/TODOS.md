# TODOS

## Unit tests for ImportDiagnostic and MarkdownFieldParser
**Priority:** Medium
**Added:** 2026-03-23

**What:** Write unit tests for `ImportDiagnostic.diagnose(folder:)` (4 ProjectType paths) and `MarkdownFieldParser.extractField`/`extractContextSection` (field extraction + edge cases).

**Why:** These modules were extracted during the 3-file split and are now internal-access independent units for the first time. No test coverage exists for their logic.

**Where to start:**
- `ImportDiagnosticSheet.swift` → `ImportDiagnostic.diagnose(folder:)` — test with temp directories containing various file layouts
- `SharedFormComponents.swift` → `MarkdownFieldParser` — test field extraction from valid/malformed markdown

**Depends on:** Nothing — can be done independently.
