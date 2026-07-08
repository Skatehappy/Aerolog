# AeroLog Ultimate 1.1.0 — Decision Log

Per the CC directive (FULL AUTONOMY): decisions taken where the directive left a
choice, a conflict arose, or the environment constrained execution.

## D1 — Version number
Directive Ground Rules mandate `MARKETING_VERSION = 1.1.0`, `CURRENT_PROJECT_VERSION = 2`,
tag `v1.1.0`, RELEASE_NOTES "1.1.0" section. An earlier verbal request had set 2.1;
the owner then delegated ("bump to whatever makes sense"). Chosen **1.1.0** to stay
consistent with the directive's mandated tag/notes/migration identity. Set in
Info.plist (CFBundleShortVersionString) and all four pbxproj configs.

## D2 — Build/test environment
This implementation session runs on **Windows with no Xcode/Swift toolchain**. All
source, tests, CI workflow, and docs are authored and pushed to `Skatehappy/Aerolog`.
The directive's mandatory green-gates (local XCTest, GitHub Actions, `measure` perf
gate, archive) execute on the **Mac / CI**, which is where the toolchain lives. Code
is written to compile; the Mac confirms green.

## D3 — M2 label
Audit offered "sum picTime/label PIC" OR "sum totalTime/label total". Directive WS4
M2 is explicit: sum `totalTime`, label "time in type/class". Reconciled to the
directive (was briefly picTime during the audit pass).

## D4 — H1 date-utility names
Implemented as `endOfCalendarMonth(afterAdding:to:)` /
`startOfCalendarMonthWindow(months:from:)` (functionally identical to the directive's
`endOfCalendarMonths(after:months:)` / `calendarMonthWindowStart(months:from:)`).
Kept the existing names to avoid churn; behavior matches the spec and tests.

## D5 — .draft creation-site sweep (H6)
Every `Flight(... status: .draft ...)` / `status = .draft` creation site, and its
finalize path:
1. `Flight.revertToDraft()` (Flight.swift) — intentional draft toggle; the logbook
   editor re-finalizes. Reachable. ✅
2. `FlightService.createDraft()` — new-flight button → FlightEditorView → Finalize.
   Reachable. ✅
3. `TrainingService.createFlightLessonDraft()` — LessonLogView flight mode opens
   FlightEditorView. Reachable. ✅
4. `TrainingService.createGroundLessonDraft()` — WAS the bug: LessonLogView ground
   mode dismissed without a finalize path, so ground entries stayed drafts and
   never counted. FIXED: ground now opens FlightEditorView for review/finalize
   (same as flight lessons), and `FlightValidation` exempts ground-only entries
   from the aircraft requirement so they can finalize. ✅
(Endorsement.swift `status = .draft` is an endorsement, not a Flight — out of scope
for the flight-draft sweep; endorsements have their own sign/finalize flow.)

Stranded-draft launch prompt (existing orphan ground drafts): pending UI (does not
change TrainingProgressEngine; auto-finalize of existing drafts intentionally NOT
done per directive).
