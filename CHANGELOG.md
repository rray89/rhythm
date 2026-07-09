# Changelog

## Unreleased

### Added

- Added an `About Rhythm` window for app version/build details, project links, and direct-update controls.
- Added direct-release update plumbing for future signed Sparkle releases outside the Mac App Store.

### Fixed

- Reduced menu-only CPU/energy use by keeping the hidden Insights window off the one-second timer path and avoiding repeated full history snapshots while the window is closed.
- Kept the closed menu panel inert so its hidden SwiftUI/AppKit window does not keep the live menu tree on the per-second timer path.
