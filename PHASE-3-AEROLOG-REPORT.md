# Phase 3 Regulatory Fix — AeroLog Ultimate Report

**Directive:** Phase 3 Regulatory Fix Master Directive — FFLDesk / TattooLog / AeroLog / FreshLedger
**Date:** 2026-07-19 · **Mode:** autonomous
**Verification:** Perplexity MCP, primary sources (14 CFR via Cornell LII / eCFR)
**Gate 2:** XCTest `RegulatoryProvenanceTests.swift` added (runs on Mac build — no local Swift toolchain).

---

## Summary

Two deliverables: (1) a **provenance record** for the FAA constants AeroLog already encodes
correctly — no values changed; (2) the one real correction — AeroLog invented a **currency**
for complex and high-performance airplanes, but **14 CFR 61.31(e)/(f) are one-time
endorsements with no recurrency**. The tracker was rendering pilots "not current"/"Expired"
for complex/HP when no such currency exists. Reframed to an advisory that never reports
expired.

| Item | Verdict | Change |
|------|---------|--------|
| 61.57(a/b/c), 61.56, Part 68 intervals | **VERIFIED — no change** | Provenance recorded in RegulatoryConstants.plist |
| 61.23 medical certificate | **IMMUNE** | App tracks pilot-entered class/expiry; nothing hardcoded |
| Complex / High-Performance "currency" | **CORRECTED** | Removed the invented 0.5h/90d currency; now advisory, never "Expired"/"Not current" |

---

## 1. Recurrent currencies — VERIFIED, values unchanged (provenance only)

Confirmed against primary sources and recorded in
`AeroLogUltimate/Resources/RegulatoryConstants.plist`:

- **61.57(a)** 3 T/O + 3 landings / 90 days · **61.57(b)** 3 T/O + 3 full-stop night landings
  / 90 days · **61.57(c)** 6 approaches + holds + intercept/track / 6 calendar months (grace
  61.57(d); IPC after 12 mo) · **61.56** flight review / 24 calendar months · **Part 68**
  BasicMed exam / 48 mo + course / 24 mo.

## 2. 61.23 medical — IMMUNE

AeroLog does not hardcode 61.23 certificate durations; it tracks the pilot-entered class and
expiration date. Recorded as IMMUNE in the plist. No verification target beyond BasicMed.

## 3. Complex / High-Performance — invented currency removed

**Finding.** `CurrencyEngine.calculateAircraftExperience` applied a 0.5-hour-in-90-days
threshold to complex/HP airplanes and emitted `.expired` + "Not current" when unmet (built-ins
seeded with `lookbackDays: 90`, `requiredFlightHours: 0.5`).

**Verified reality.** 14 CFR **61.31(e)** (complex) and **61.31(f)** (high-performance) are
**one-time logbook endorsements** — no recurrency, no 90-day or hourly recency rule. Any
recency beyond that comes from insurance/operator policy, not the FARs.

**Fix.**
- `DataStore.swift`: built-ins relabeled "…Proficiency **(Advisory)**" + explanatory comment.
- `CurrencyEngine.swift`: complex/HP now resolve to `.current` (threshold met) or
  `.notApplicable` (neutral) — **never `.expired`**; summary states it is a one-time
  endorsement, not a currency; `warningText` and `nextRequiredAction` are `nil`;
  `regulationReference` annotated accordingly. The 0.5h/90d figure survives only as an
  optional personal-proficiency nudge and drives no compliance status.

## Gate 2 evidence

`AeroLogUltimateTests/RegulatoryProvenanceTests.swift` (XCTest, 9 tests):
- Provenance: plist verified date/schema; recurrent-currency citations + intervals
  (61.57 a/b/c, 61.56); BasicMed 48/24; 61.23 IMMUNE note; complex/HP `recurrent = false`.
- Behavior: complex & HP with **no recent flights → `.notApplicable`, not `.expired`**, no
  warning, no required action; complex with a recent flight → advisory `.current`.

Field names verified against the real `CurrencyCalculationResult` (`status`, `summaryText`,
`warningText`, `detail`) and `CurrencyDetailPayload` (`regulationReference`,
`nextRequiredAction`). No local Swift compiler in this environment (AeroLog builds on Mac, per
project convention); the test is written to compile and run on that build.

## Files changed / added

- `AeroLogUltimate/Services/Currency/CurrencyEngine.swift` — complex/HP reframe (no `.expired`).
- `AeroLogUltimate/Core/Persistence/DataStore.swift` — "(Advisory)" labels + comment.
- `AeroLogUltimate/Resources/RegulatoryConstants.plist` — **new**; provenance record.
- `AeroLogUltimateTests/RegulatoryProvenanceTests.swift` — **new**; XCTest lock.
- `VERIFICATION_LOG.md` — **new/seeded**; STEP A1–A3.

## Build note (for the Mac step)

Add `RegulatoryProvenanceTests.swift` to the test target (and optionally
`RegulatoryConstants.plist` to the app Resources build phase) in Xcode. The test reads the
plist from the source tree via `#filePath`, so it does not require bundle membership to pass.
No app-facing values changed except the complex/HP status framing.
