# Contributing

## Development

1. Fork and clone repository
2. Create a branch with prefix `codex/` or `feature/`
3. Implement changes with tests or manual verification notes
4. Open a pull request with:
   - change summary
   - verification steps
   - risk and rollback notes

Quit any running Rhythm copy before starting a dev build. Rhythm keeps the first running instance as primary, so `swift run Rhythm`, Xcode builds, and `dist/Rhythm.app` will exit if another Rhythm copy is already active.

## Code Style

- Keep logic modular (`TimerEngine`, `OverlayManager`, `LockMonitor`)
- Prefer explicit state transitions over implicit side effects
- Avoid changing unrelated behavior in the same PR

## Commit Convention

- `feat: ...`
- `fix: ...`
- `docs: ...`
- `chore: ...`
