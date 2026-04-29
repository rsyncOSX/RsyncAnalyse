# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

Standard SwiftPM library targeting macOS 14+ with Swift 6.2 tools (strict concurrency).

```bash
swift build
swift test
swift test --filter RsyncAnalyseTests.basicParsing   # single test
swift test --filter OpenRsyncOutputRecordTests       # one suite
```

Tests use the **Swift Testing** framework (`@Test`, `#expect`), not XCTest.

## Architecture

The package exposes **two parallel parsing layers** that serve different callers and must stay independent:

### 1. Per-record parsers (line-level, used by SwiftUI rows)

- `RsyncOutputRecord` — strict **12-char** itemized format (`.f..t....... path`), the format produced by GNU/BSD rsync.
- `OpenRsyncOutputRecord` — strict **9-char** itemized format (`.f..t.... path`), the format produced by OpenBSD's openrsync. The trailing field is `z` (compressed) instead of rsync's `u/a/x/?` tail.

Both structs share the same shape (`path`, `updateType`, `fileType`, `[RsyncAttribute]`, optional `message`) and the same `init?(from: String)` contract:

1. Lines starting with `*` are treated as message records (`*deleting`, `*received`, `*unsafe`, `*skip-over`); everything after the first space is the path, the token between `*` and that space is stored in `message`.
2. Otherwise the line must match the strict fixed-width prefix exactly — count check + space at the boundary index. No fallback / lenient parsing. Returns `nil` on mismatch.

When editing one record parser, mirror the change in the other if the rule applies to both formats — the tests in `RsyncOutputRecordTests` and `OpenRsyncOutputRecordTests` are largely parallel and assume that symmetry.

### 2. Whole-output analyzer (aggregate, actor-isolated)

`ActorRsyncOutputAnalyser` is a public **actor** that consumes a full rsync stdout blob and produces an `AnalysisResult` (itemized changes + `Statistics` + dry-run flag + errors/warnings). It has its own internal itemized-change parser (`parseItemizedChange`) which is **separate** from `RsyncOutputRecord` — do not unify them without intent; the analyzer's parser is whitespace-tokenized and lenient, the record parser is strict fixed-width.

Statistics parsing keys off line prefixes (`Number of files:`, `Total file size:`, `speedup is`, …). Stat extraction starts the first time `Number of files:` is seen; everything before that is treated as itemized output. `analyze` returns `nil` if no `Number of files:` line is found — callers rely on this signal.

`analyzeCached(_:)` keys an in-actor dictionary by `String.hashValue`. The cache lives for the actor's lifetime; `clearCache()` is the only eviction.

### 3. SwiftUI components (`SupportingViewComponents.swift`)

Pure presentation. `RsyncOutputRowView` / `OpenRsyncOutputRowView` take a raw line and try the corresponding record parser, falling back to plain `Text` on parse failure. `ChangeItemRow` consumes the analyzer's `ItemizedChange`. Tags (`UpdateTypeTag`, `FileTypeTag`, `AttributeBadge`) are shared between both row variants.

## Conventions

- All public data types are `Sendable`. Preserve this when adding fields — actor returns and SwiftUI consumption depend on it.
- The two record parsers are intentionally duplicated rather than abstracted behind a protocol; the format constants (column count, attribute positions) differ enough that a shared base would obscure them. Keep them as siblings.
- Logging goes through `Logger.process` (see `Internal/PackageLogger.swift`); the `debugWithThreadInfo` / `debugMessage` helpers are `#if DEBUG`-gated.
- Public API is namespaced under `ActorRsyncOutputAnalyser` for the analyzer's nested types (`AnalysisResult`, `ItemizedChange`, `ChangeFlags`, `Statistics`, `FileCount`, `ChangeType`). The record parsers live at the top level.
