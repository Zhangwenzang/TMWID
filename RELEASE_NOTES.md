# Release Notes

## Tmwid 1.3.15

Release date: 2026-05-10

### Highlights

Tmwid 1.3.15 expands support beyond Claude Code by adding Codex hook integration, introduces a dedicated API-error state, and stabilizes the floating bubble so hover enter/leave no longer produces clipped or jumpy intermediate frames.

### User-Facing Changes

- Claude Code and Codex sessions can both write status into Tmwid.
- API and credit-limit failures are surfaced as a separate status with their own animation.
- The menu bar and bubble status icons now show counts.
- Hovering a bubble status reveals the matching session list.
- Clicking a listed session activates its app window.
- The floating bubble keeps its top-left edge stable during hover expansion and collapse.

### Fixes

- Removed the hover flicker caused by SwiftUI content changing size while the AppKit host window was still resizing.
- Prevented the narrow-and-tall clipped intermediate frame seen during bubble collapse.
- Fixed animation loading for packaged release resources, including `apiErr` frames.

### Install

Open `Tmwid-1.3.15.dmg` and drag `Tmwid.app` to `/Applications`.

### Verification

```bash
swift test
packaging/build-release.sh 1.3.15
```

The release build completed successfully and the test suite passed with 97 tests.
