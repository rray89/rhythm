# Rhythm V2 PRD (Fork Draft)

## 1. Purpose of This Document

This document captures the product direction and near-term ideas for my local fork. It does not replace the upstream V1 design document.

- `docs/V1-design.md` remains the historical V1 baseline for upstream `main`
- `docs/V2-prd.zh.md` is the Chinese fork draft
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

### 2.2 Behavior Already Shipped in This Fork

This fork now ships the following behavior beyond the upstream V1 baseline:

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
   - the visible `Rhythm` label is now replaced by a live countdown while keeping the icon
   - the status item can be restored if the system removes it unexpectedly
6. The fork now supports bilingual UI:
   - the app can switch between Chinese and English in the menu settings
   - first-run language defaults to Chinese only for `zh*` system languages, and to English otherwise
   - future user-facing features are expected to remain bilingual by default
7. The fork now ships a lighter rest model and local history baseline:
   - the regular break default can be set up to 20 minutes
   - `Desk break` is the single explicit on-screen non-work break action in the menu
   - `Desk break` is intentionally non-blocking and continues in the menu without forcing a full-screen overlay
   - screen lock now counts as hidden away-from-screen rest until unlock, then starts a fresh focus cycle
   - system sleep without prior lock now also counts as hidden away-from-screen rest, ending at wake or continuing until unlock if wake lands on a locked screen
   - app-off time after normal quit or shutdown is counted as hidden rest on next launch, with a 15-minute heartbeat fallback for unclean exits and a 12-hour cap per gap
   - local history now stores focus and rest sessions in weekly JSON folders under Application Support
8. Daily totals and local history now have a dedicated browsing surface:
   - the menu keeps a compact Today summary with today's focus and rest totals
   - a dedicated Insights window shows Today, Last 7 Days, Last 30 Days, and All Time summaries
   - the Insights window groups session history by reporting day and can export Today, Last 7 Days, Last 30 Days, or All Time as CSV or JSON
   - the day boundary for totals and history grouping can be shifted from `00:00` to `23:00`

## 3. What V2 Is Trying to Improve

V1 already handles the core job of reminding the user to rest. This fork wants to make the rhythm easier to adjust in the moment, without forcing a full cycle reset whenever the user needs a small change.

The core V2 goals are:

1. Separate "default rhythm" from "adjustments to the current phase"
2. Let common in-the-moment decisions happen directly from the menu bar or overlay
3. Make bilingual UI the default product baseline for all future features, while keeping the menu lightweight and moving deeper history into a dedicated window

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
- the status item should show the current countdown in both focus and break states without obvious width jitter
- the status item should not quietly disappear because of UI or system edge cases
- if something does go wrong, the app should prefer restoring the menu bar entry instead of forcing the user to restart

## 5. Near-Term Directions

The following areas shape the near-term V2 roadmap. Some are now part of the baseline, while others remain open product directions.

### 5.1 Bilingual UI Baseline

The fork now treats bilingual UI as a shipped baseline rather than a future idea.

Current expectations:

- the visible app UI supports both English and Chinese
- the menu panel includes a language switch for `中文` and `English`
- first-run language follows a simple rule: `zh*` system languages use Chinese, and all other system languages use English
- future user-facing features should ship with both Chinese and English copy instead of adding a single-language UI first

### 5.2 Rest Model Baseline

The current shipped rest model is intentionally simpler than the earlier long-break preset matrix:

- regular short breaks remain configurable and can now go up to 20 minutes
- `Desk break` is the deliberate on-screen, non-work break for watching a video, reading posts, or similar casual use
- when `Desk break` ends, Rhythm returns to focus automatically and should notify the user when notification permissions allow
- away-from-desk time is represented by locking the Mac, which is counted as hidden rest until unlock

This keeps one clear on-screen break action while letting real away time follow normal screen-lock behavior.

### 5.3 Daily Focus / Break Totals and Insights Window

Without turning the menu into a dense analytics surface, the fork now ships lightweight daily totals plus a dedicated Insights window so users can answer a few basic questions:

- how much did I focus today?
- how much did I rest today?
- what did the last week or month look like?
- what sessions actually make up those totals?

The shipped UI keeps this compact:

- the menu keeps two numbers for today's focus and rest plus an entry point into Insights
- the Insights window shows Today, Last 7 Days, Last 30 Days, and All Time summaries
- the Insights window groups sessions by reporting day, keeps hidden rest out of the list by default, and can export preset ranges as CSV or JSON
- a configurable day cutoff hour lets totals and grouping roll over later than midnight

### 5.4 Revisit Screen-Lock Reset Behavior

The shipped fork no longer treats screen lock as a plain reset.

Current behavior:

- locking the screen ends the current visible focus or break segment
- the lock-to-unlock interval is recorded as hidden rest time
- unlocking starts a fresh focus cycle

This better matches "I left my desk" behavior without requiring extra break presets.

### 5.5 Sleep-As-Rest Handling

The shipped fork also treats system sleep as away-from-desk rest when the machine sleeps before the user explicitly locks the screen.

Current behavior:

- sleep ends the current visible focus or timer-break segment at sleep time
- the sleep interval is recorded as hidden rest
- if the machine wakes directly back to the desktop, hidden sleep rest ends at wake and Rhythm starts a fresh focus cycle
- if the machine wakes to a locked screen, hidden sleep rest continues until the user unlocks
- if the machine was already locked before sleeping, the interval remains one continuous hidden screen-lock rest segment instead of being split into a second rest type

### 5.6 App-Off Rest Recovery

The shipped fork also treats app-off time as hidden rest so daily totals do not lose time when the user quits Rhythm or shuts down the Mac.

Current behavior:

- normal quit and expected macOS termination paths record an exact exit timestamp
- on the next launch, the exit-to-launch gap is recorded as hidden app-downtime rest
- a 15-minute heartbeat provides a fallback estimate for unclean exits such as force-quit, crash, or power loss
- each single app-off gap is capped at 12 hours; time beyond the cap is not shown as a special blank in the 7-day aggregate trend
- app-downtime rest counts in Today totals and the 7-day trend, but stays out of Recent Sessions

### 5.7 History and Export UX

The fork now treats local history as more than a raw JSON folder.

Current behavior:

- the menu keeps a compact Today summary and lightweight Recent Sessions list
- a singleton Insights window can be opened on demand from the menu
- the Insights window shows Today, Last 7 Days, Last 30 Days, and All Time sections in one scrollable view
- the session list is grouped by reporting day and can filter `All`, `Focus`, or `Rest`
- hidden rest from screen lock, sleep, and app downtime counts in totals and charts, but only appears in the list when the user enables `Show Hidden Rest`
- export is explicit and preset-based: Today, Last 7 Days, Last 30 Days, or All Time as CSV or JSON

## 6. Non-Goals

This V2 draft still does not aim to add the following right away:

- cloud sync
- multi-device sync
- complex reporting or charting
- task management or social pomodoro features

If Apple companion sync is revisited later, it should still be treated as a separate follow-on effort rather than folded into this V2 baseline. The current feasibility read is:

- iPhone and Apple Watch support would likely need dedicated companion app targets instead of trying to stretch the macOS menu bar app across devices
- private iCloud / CloudKit is the most likely first-party sync path if we want Apple-only companion sync without inventing a custom backend first
- active timer sync should be modeled as shared phase snapshots and completed session records, not a per-second countdown stream
- read-only companion surfaces are the safer first milestone; remote timer control and cross-device conflict resolution should come later

## 7. Acceptance Direction

If the fork's phase-adjustment model is formalized, it should at least satisfy the following:

1. Changing default focus or break settings does not interrupt the current phase
2. The current focus phase can be extended safely or moved into break earlier
3. `Start Break 5 Minutes Early` is unavailable when fewer than 5 minutes remain
4. The current break phase can be extended safely by 1 or 5 minutes
5. Session history records the final planned break duration for that cycle, not the stale default value
6. The menu bar entry remains visible or recoverable in common failure scenarios
7. The menu bar entry keeps the icon and shows a live countdown in both focus and break states without obvious jitter
8. `Desk break` can continue without a blocking overlay
9. Daily totals stay compact in the menu while deeper history and export live in the dedicated Insights window
10. Screen lock contributes to rest totals and begins a fresh focus cycle when the machine unlocks
11. System sleep contributes hidden rest and starts a fresh focus cycle after wake or unlock, depending on whether wake lands locked
12. App-off time contributes hidden rest through clean exit timestamps or heartbeat fallback, capped at 12 hours per gap
13. Hidden rest counts in totals, trends, and export, but stays out of the default session list unless explicitly revealed
14. Export supports explicit Today, Last 7 Days, Last 30 Days, and All Time scopes in both CSV and JSON

## 8. Open Questions

These questions remain intentionally unresolved in this draft:

1. Whether export should later support custom date ranges beyond Today, Last 7 Days, Last 30 Days, and All Time
2. Whether custom user-defined break presets should come back later as a separate feature from totals/history
3. If Apple companion sync is explored later, whether the first shipped scope should be iPhone-first history/today views, then a lighter Apple Watch live-status companion
4. If active timer state is shared across devices later, which device should own phase changes and how conflicting edits should resolve
