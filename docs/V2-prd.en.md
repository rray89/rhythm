# Rhythm V2 PRD (Fork Draft)

## 1. Purpose of This Document

This document captures the product direction and near-term ideas for my local fork. It does not replace the upstream V1 design document.

- `docs/V1-design.md` remains the historical V1 baseline for upstream `main`
- `docs/V2-prd.md` is the Chinese fork draft
- this file is the English version of the fork draft for readers who prefer English

In short: if you want to understand upstream V1, read `docs/V1-design.md`; if you want to understand where this fork may go next, read one of the V2 PRD drafts.

## 2. Current Baseline and Fork Deltas

### 2.1 Upstream V1 Baseline

Upstream `main` is still centered on a stable, usable break-reminder app for macOS. The core capabilities are:

- a menu bar app
- configurable focus and break rhythm
- a full-screen break overlay
- `ESC` to skip a break
- cycle reset after screen lock
- no-rest mode
- local session history

### 2.2 Behavior Explored in This Fork

This fork has already explored the following ideas in branches such as `codex/phase-extension-controls`. These should be treated as V2 candidate behavior, not as default behavior already shipped on upstream `main`.

1. The current focus phase can be adjusted directly:
   - `Extend Focus 5 Minutes`
   - `Extend Focus 10 Minutes`
   - `Start Break 5 Minutes Early`
2. `Start Break 5 Minutes Early` is only available when at least 5 minutes remain in the current focus phase.
3. The current break phase can also be adjusted directly:
   - `Extend Break 1 Minute`
   - `Extend Break 5 Minutes`
4. Default settings and current-phase adjustments are treated as different concepts:
   - changing focus interval or break duration affects the next cycle
   - extending or shortening a phase affects only the current phase
5. Menu bar visibility and related UI resilience have been hardened further:
   - the menu bar icon has been polished for better visibility
   - the status item can be restored if the system removes it unexpectedly

## 3. What V2 Is Trying to Improve

V1 already handles the core job of reminding the user to rest. This fork wants to make the rhythm easier to adjust in the moment, without forcing a full cycle reset whenever the user needs a small change.

The core V2 goals are:

1. Separate "default rhythm" from "adjustments to the current phase"
2. Let common in-the-moment decisions happen directly from the menu bar or overlay
3. Leave room for localization and longer-break scenarios without introducing a heavy product surface

## 4. Product Direction for V2

### 4.1 Temporary Phase Controls

The fork keeps the phase-control model already explored in the branch work:

- During focus:
  - start break 5 minutes early
  - extend focus by 5 minutes
  - extend focus by 10 minutes
- During break:
  - extend break by 1 minute
  - extend break by 5 minutes

The design principles behind this model are:

- default settings describe how the next cycle should start
- phase controls describe how the current cycle should be adjusted right now
- these two kinds of actions should not blur together

### 4.2 Rules for When Settings Take Effect

V2 leans toward the following rules as the official behavior:

1. Changing the focus interval should not reset the current focus phase
2. Changing the break duration should not alter a break that is already in progress
3. New default settings should take effect on the next cycle
4. Manual phase extensions or reductions should apply only to the current cycle

Why this helps:

- it prevents users from accidentally interrupting the current rhythm while editing defaults
- it keeps "change my defaults" separate from "give me a little more or less time right now"
- it gives future quick controls a consistent semantic model

### 4.3 Menu Bar Reliability

This fork treats menu bar presence and recoverability as part of the core experience, not just polish.

Near-term expectations:

- the menu bar icon should remain legible in both light and dark contexts
- the status item should not quietly disappear because of UI or system edge cases
- if something does go wrong, the app should prefer restoring the menu bar entry instead of forcing the user to restart

## 5. Near-Term Candidate Directions

The following ideas are promising V2 directions, but they are still proposals rather than commitments.

### 5.1 English / Chinese Localization

The goal is to support at least English and Chinese UI text so the fork is not tied to a Chinese-only interface.

Expected scope:

- menu bar status text
- settings labels and buttons
- break overlay copy
- better alignment between README language and product docs

### 5.2 Longer Break Support

V1 is mostly designed around short breaks. This fork may also support longer breaks for lunch, naps, stretching, walking, or gym time.

There are currently two likely directions:

- add larger break presets only
- introduce a distinct long-break mode instead of treating everything as the same kind of break

### 5.3 Daily Focus / Break Totals

Without introducing a heavy analytics surface, add lightweight daily totals so users can answer two basic questions:

- how much did I focus today?
- how much did I rest today?

### 5.4 Revisit Screen-Lock Reset Behavior

V1's "screen lock always resets the cycle" rule is simple, but it may deserve another look once phase-level adjustments become more important.

Questions worth revisiting:

- should screen lock always return the app to a full focus cycle?
- should phase extensions made before the lock be discarded?
- should a short lock and a long away-from-keyboard period behave the same way?

## 6. Non-Goals

This V2 draft still does not aim to add the following right away:

- cloud sync
- multi-device sync
- complex reporting or charting
- task management or social pomodoro features

## 7. Acceptance Direction

If the fork's phase-adjustment model is formalized, it should at least satisfy the following:

1. Changing default focus or break settings does not interrupt the current phase
2. The current focus phase can be extended safely or moved into break earlier
3. `Start Break 5 Minutes Early` is unavailable when fewer than 5 minutes remain
4. The current break phase can be extended safely by 1 or 5 minutes
5. Session history records the final planned break duration for that cycle, not the stale default value
6. The menu bar entry remains visible or recoverable in common failure scenarios

## 8. Open Questions

These questions remain intentionally unresolved in this draft:

1. Should the next PR focus on localization first, or should it first clarify the longer-break model?
2. Should longer breaks be implemented as larger presets only, or as a separate long-break mode?
3. Should daily totals be simple numbers only, or should there be a minimal trend view?
4. Should screen-lock behavior stay as an immediate reset, or should it vary based on how long the machine was locked?
