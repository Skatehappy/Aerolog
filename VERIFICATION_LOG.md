# AeroLog Ultimate — Regulatory Verification Log

Provenance record for the FAA regulatory constants AeroLog relies on, and the Phase 3
correction of the complex/high-performance "currency". Append-only. Verification method:
Perplexity MCP against **primary sources** (14 CFR via Cornell LII / eCFR). Pilot-entered
data (flight times, dates, certificate class/expiry) is USER data and structurally immune;
the VERIFIED layer is the regulatory *interval/rule* the engine encodes.

Machine-readable provenance: `AeroLogUltimate/Resources/RegulatoryConstants.plist`, locked by
`AeroLogUltimateTests/RegulatoryProvenanceTests.swift`.

---

## STEP A1 (2026-07-19) — Genuine recurrent currencies: VERIFIED (values unchanged)

All values confirmed CORRECT against primary sources; **no value changed** — this step is
provenance only.

| Currency | Citation | Rule (verified) | Recurrent |
|----------|----------|-----------------|-----------|
| Passenger day | **14 CFR 61.57(a)** | 3 takeoffs + 3 landings in preceding **90 days**, same cat/class/type | Yes |
| Passenger night | **14 CFR 61.57(b)** | 3 takeoffs + 3 **full-stop** landings, 1h after sunset–1h before sunrise, preceding 90 days | Yes |
| Instrument | **14 CFR 61.57(c)** | **6** approaches + holding + intercept/track in preceding **6 calendar months**; 6-mo grace (61.57(d)); IPC after 12 mo | Yes |
| Flight review | **14 CFR 61.56** | 1h ground + 1h flight within preceding **24 calendar months** | Yes |
| BasicMed exam | **14 CFR 68.7 / Part 68** | Comprehensive medical exam every **48 calendar months** | Yes |
| BasicMed course | **14 CFR 68.3 / Part 68** | Medical education course every **24 calendar months** | Yes |

## STEP A2 (2026-07-19) — 14 CFR 61.23 medical certificate: IMMUNE

The FAA medical-certificate validity durations (14 CFR 61.23) are **not hardcoded** in
AeroLog — the app tracks the pilot-entered certificate class and expiration date and reports
against that user data. There is no regulatory constant to verify beyond BasicMed (Part 68,
above). Recorded as IMMUNE in `RegulatoryConstants.plist → medicalCertificate`.

## STEP A3 (2026-07-19) — Complex / High-Performance: CORRECTED (invented currency removed)

**Finding (portfolio sweep §4.5):** `CurrencyEngine.calculateAircraftExperience` treated
complex and high-performance airplanes as a **currency** — a 0.5-hour-in-90-days threshold
that, when unmet, rendered a `.expired` status and "Not current"/"required" language
(built-ins seeded in `DataStore` with `lookbackDays: 90`, `requiredFlightHours: 0.5`).

**Verified reality (primary source):** **14 CFR 61.31(e)** (complex) and **14 CFR 61.31(f)**
(high-performance) are **ONE-TIME logbook endorsements**. Neither imposes any recurrency —
**no 90-day rule, no hourly recency, no "currency"** specific to complex or high-performance
airplanes. After the endorsement the pilot remains qualified indefinitely, subject only to
the general currency rules (61.57 / 61.56). Telling a pilot they are "not current" for
complex/HP is factually wrong and could induce an unnecessary flight.

**Fix (code):**
- `DataStore.swift` — built-ins relabeled "Complex/High Performance Proficiency **(Advisory)**"
  with a comment documenting the one-time-endorsement basis.
- `CurrencyEngine.swift` `calculateAircraftExperience` — status is now `.current` when the
  self-selected proficiency threshold is met, else **`.notApplicable`** (neutral "N/A"),
  **never `.expired`**. Summary reads "Advisory only — 14 CFR 61.31(e)/(f) is a one-time
  endorsement, not a currency. No FAA recurrency applies." Warning and `nextRequiredAction`
  are `nil` (no action implied). `regulationReference` annotated "one-time endorsement
  (advisory proficiency, no FAA recurrency)".
- The 0.5h/90d numbers are retained ONLY as an optional personal-proficiency nudge; they no
  longer drive any "not current"/expired determination.

**Gate 2:** `AeroLogUltimateTests/RegulatoryProvenanceTests.swift` (XCTest) asserts (a) the
provenance plist matches the recurrent-currency citations/intervals + 61.23 immune note, and
(b) complex/HP with zero recent flights are `.notApplicable` (never `.expired`), emit no
warning, imply no required action; with a recent flight they surface an advisory `.current`.
(Runs on the Mac build — no local Swift toolchain in this environment; field names verified
against the real `CurrencyCalculationResult` / `CurrencyDetailPayload`.)

**Build note:** add `RegulatoryProvenanceTests.swift` to the test target and (optionally)
`RegulatoryConstants.plist` to the app target's Resources in Xcode. The test loads the plist
via `#filePath` from the source tree, so it does not depend on bundle membership.
