# Rhythm Repo Notes

- Whenever a new feature is added or a bug is fixed, update `README.md` and the relevant PRD docs in the same change.
- For user-facing product behavior changes, keep both `docs/V2-prd.zh.md` and `docs/V2-prd.en.md` aligned.
- Internal refactors with no product or workflow change do not need PRD updates unless they affect documented behavior.
- When completing a feature and opening or updating a PR, generate a local app bundle with `SKIP_DMG=1 ./scripts/package_dmg.sh` and tell the user the app is available at `dist/Rhythm.app` so they can try it without opening Xcode.
- When addressing PR review comments, post a response to every reviewed comment, including discussion-only or intentionally-not-changed comments. For Codex GitHub replies, prefix each response with `Review by Codex:`.
