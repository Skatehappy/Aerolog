# AeroLog Ultimate — Release Notes

## Version 1.0.0 (July 2026)

First production release. Validated through automated pilot-scenario tests and CI build pipeline.

### What's Included

**Core logbook** — Flight logging with draft/finalize workflow, multi-leg routes, approaches, hobbs/tach, attachments, and remarks.

**Currency engine** — Day/night passenger carrying (61.57), instrument (61.57(c)), flight review (61.56), medical, CFI renewal, tailwheel, complex/high-performance experience, and custom rules.

**Endorsements** — 12 built-in FAA templates, custom templates, Apple Pencil signatures, remote signing packages.

**Reports** — Analytics dashboard, FAA 8710 totals, flight log, airport/aircraft stats; export to PDF, CSV, JSON.

**Training** — CFI student management, syllabus progress, lesson logging, checkride readiness.

**Data management** — CSV import, full backup/restore with endorsements and Phase 8 fields, replace-all or merge strategies.

**iPad polish** — Split View, aviation dark palette, keyboard shortcuts, Apple Pencil canvas.

**Advanced features** — Fuel tracking, weight & balance, optional expenses, natural language search, aircraft performance notes, maintenance reminders, pinned/favorites, iPhone tab layout.

### Phase 9 Validation Summary

| Area | Status | Notes |
|------|--------|-------|
| Day passenger currency (61.57a) | ✅ | 3 landings in 90 days |
| Night passenger currency (61.57b) | ✅ | Full-stop only (bug fixed) |
| Instrument currency (61.57c) | ✅ | Approaches + holds |
| Flight review (61.56) | ✅ | Signed endorsement path |
| CSV import | ✅ | LogTen-style headers |
| Backup/restore | ✅ | Flights, aircraft, endorsements, fuel, W&B, expenses, maintenance |
| Offline operation | ✅ | Sync disabled; local data intact |
| Reports (8710, totals) | ✅ | Scenario-tested |
| NL search | ✅ | Pinned, XC, airport filters |
| Maintenance overdue | ✅ | Date-based detection |
| CFI dual-given logging | ✅ | Instructor time in reports |

### Bug Fixes in 1.0.0

- **Night currency:** Touch-and-go night landings no longer count toward 61.57(b) passenger currency; only `fullStopNightLandings` qualify.
- **Backup restore:** Endorsements were exported but not restored — now fully round-tripped including signature metadata.
- **Backup restore:** Phase 8 fields (fuel, W&B, expenses, maintenance, performance notes, pinned/favorites) now included in portable backup format.
- **Replace-all restore:** Clears endorsements and maintenance items in addition to flights/aircraft.

### Known Limitations

- Encrypted cloud sync prepares local payloads; remote provider upload is not yet implemented.
- App Store distribution requires Apple Developer account and code signing setup.
- GitHub Actions CI requires billing enabled on the repository account.

### Upgrade Path

Backup format remains backward compatible. Older `.json` backups without Phase 8 fields restore with defaults (no fuel/expense data). Re-export after upgrading to capture full field set.

### Test Pilot Scenario

Release validation uses **Sarah Chen** (PPL, KPAO, N5283E C172S):

1. Logs pattern work for day currency
2. Imports legacy CSV from previous paper logbook
3. Takes a cross-country to KTRK with fuel, W&B, and FBO expense
4. Pins the Tahoe trip; finds it via natural language search
5. Receives signed flight review endorsement from CFI Mike Torres
6. Creates full backup; restores on clean install
7. Operates offline with sync disabled
8. Generates FAA 8710 report for certificate renewal

See `AeroLogUltimateTests/PilotScenarioTests.swift` for automated coverage.