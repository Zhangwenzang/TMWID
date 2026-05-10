# Changelog

## 1.3.15 - 2026-05-10

### Added

- Added Codex hook support alongside Claude Code, including Codex feature-flag setup and hook file creation.
- Added API-error status support with a dedicated `apiErr` animation, menu bar count, bubble item, menu item, and sound priority.
- Added hover session lists in the floating bubble so each status can reveal the matching sessions.
- Added a resource lookup fallback for flat PNG and imageset-style animation assets.

### Changed

- Updated the floating bubble layout so visible content is pinned to the top-left of a stable host window.
- Reserved the expanded bubble host frame up front, preventing hover enter/leave from resizing the outer macOS window.
- Removed hover-driven icon offsets and resize interpolation that could make the bubble edge appear to drift.
- Updated README installation and behavior documentation for Claude Code, Codex, API-error status, and the stable bubble.

### Fixed

- Fixed hover expansion and collapse flicker where SwiftUI content could be clipped by an intermediate `NSWindow` size.
- Fixed top and left edge instability during bubble hover transitions.
- Fixed packaged API-error frame loading by supporting the resource layout used inside the release bundle.

### Verified

- `swift test` passes: 97 tests.
- `packaging/build-release.sh 1.3.15` produces `dist/Tmwid-1.3.15.dmg`.

## 1.2.2 - 2026-04-30

- Previous public release.
