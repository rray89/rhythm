# Mac App Store Checklist (Future)

This note is a future-facing checklist for a possible Mac App Store release.
It is not part of the current V2 scope and should not block the direct-distribution path.

## Current Read

- Rhythm does not look Mac App Store-ready today.
- Rhythm also does not look fundamentally incompatible with the Mac App Store.
- The likely work is packaging, sandboxing, and a small amount of API / review-risk cleanup rather than a product rewrite.

## Main Gaps To Close

### 1. Add a Real App Store Build Path

- Stop treating `scripts/package_dmg.sh` as the release path for this flow.
- Create a proper App Store packaging / signing / upload path.
- Keep direct DMG distribution separate from any future App Store archive flow.

Repo hotspots:

- `scripts/package_dmg.sh`

### 2. Add App Sandbox Support

- Add the macOS App Sandbox capability and entitlements.
- Re-test all file access and system integration under sandboxed conditions.
- Confirm local history, lifecycle recovery state, and export continue to work from the app container.

Repo hotspots:

- `Sources/RhythmCore/Persistence.swift`
- `Sources/RhythmCore/AppLifecycleStore.swift`

### 3. Rework Launch-at-Login For a Store Build

- Keep the modern `SMAppService.mainApp` path if it behaves correctly in the App Store build.
- Remove, disable, or isolate the legacy cleanup path that touches `~/Library/LaunchAgents` and calls `launchctl`.
- Re-test login-item behavior only from an installed `/Applications` build.

Repo hotspots:

- `Sources/RhythmApp/LaunchAtLoginManager.swift`

### 4. Review Lock / Unlock Detection Against Public API Expectations

- Re-check whether the current lock detection approach is acceptable for App Store submission.
- If the `DistributedNotificationCenter` lock/unlock notifications are not safe to depend on, replace them or degrade gracefully for a store build.
- Keep the sleep/wake path if it remains documented and reliable.

Repo hotspots:

- `Sources/RhythmApp/LockMonitor.swift`
- `Sources/RhythmApp/SleepWakeMonitor.swift`

### 5. Validate The Break Overlay In A Sandboxed Build

- Re-test the full-screen break overlay after sandboxing and proper signing are in place.
- Confirm focus-stealing, screen coverage, and escape-to-skip behavior still work as intended.
- Prepare clear App Review notes explaining that the overlay is the core break-reminder interaction and how to dismiss it.

Repo hotspots:

- `Sources/RhythmApp/OverlayManager.swift`

### 6. Prepare App Store Connect Metadata

- Decide whether a Mac App Store release is free or paid.
- Prepare app description, subtitle, screenshots, support URL, and privacy policy URL.
- Write reviewer notes that explain:
  - menu bar behavior
  - launch at login
  - break overlay behavior
  - any lock / sleep related behavior reviewers should know how to trigger

## Suggested Future Sequence

1. Create a sandboxed App Store build path.
2. Fix launch-at-login and lock-detection issues found under that build.
3. Re-test overlay, notifications, persistence, export, and Insights.
4. Prepare metadata and reviewer notes.
5. Decide whether the App Store release is worth the ongoing maintenance cost.

## References

- Apple App Sandbox overview:
  - <https://developer.apple.com/documentation/security/app-sandbox>
- Apple macOS sandbox configuration:
  - <https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox>
- Apple App Review portal:
  - <https://developer.apple.com/app-store/review/>
