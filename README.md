# AeroLog Ultimate

A professional iPad-first electronic pilot logbook for iOS 17+, with iPhone companion support. Built with SwiftUI and SwiftData for offline-first operation.

## Release 1.0.0

**Schema version:** 1.1.0  
**Minimum iOS:** 17.0  
**Platforms:** iPad (primary), iPhone (compact tab layout)

## Features

### Logbook
- Draft and finalized flight entries with full FAA time breakdown
- Multi-leg routes, instrument approaches, hobbs/tach, conditions
- Attachments (photos, documents) with local storage
- Natural language search (`"pinned cross country to KTRK last month"`)
- Pinned and favorite flights

### Currency & Compliance
- Built-in 14 CFR Part 61 currency rules (day/night passenger, instrument, flight review, medical, CFI, tailwheel, complex, high-performance)
- Custom currency requirements
- Dashboard with expiring-soon warnings

### Endorsements
- FAA template library with merge fields
- Digital signature capture (Apple Pencil)
- Remote signing package export/import
- Custom templates with `{{placeholder}}` syntax

### Reports & Analytics
- Total time summary, FAA Form 8710 totals, flight log export
- Airport and aircraft statistics, monthly breakdown
- PDF, CSV, and JSON export

### Training (CFI)
- Student relationships, syllabus tracking, lesson logging
- Checkride readiness and custom syllabi

### Aircraft
- Fleet management with performance notes (cruise, best glide, fuel burn)
- Maintenance reminders with local notifications

### Advanced (Phase 8)
- Fuel tracking (added, burn, remaining)
- Weight & balance worksheets with CG limits
- Optional per-flight expense logging
- Maintenance item scheduling

### Data Management
- CSV logbook import (LogTen-compatible headers)
- Full backup/restore (`.json` or `.aerologbackup` bundles)
- Encrypted sync foundation (local-first; cloud transport planned)

### iPad Experience
- Split View navigation, aviation dark theme
- Apple Pencil notes and signatures
- Keyboard shortcuts

## Building

Requires Xcode 16.2+ and macOS.

```bash
xcodebuild \
  -project AeroLogUltimate.xcodeproj \
  -scheme AeroLogUltimate \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build

xcodebuild \
  -project AeroLogUltimate.xcodeproj \
  -scheme AeroLogUltimate \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16)' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

CI runs on GitHub Actions (`.github/workflows/ios.yml`): build, unit tests, and iPhone companion layout verification.

## Test Coverage

| Suite | Focus |
|-------|-------|
| `PilotScenarioTests` | End-to-end pilot workflows (Sarah Chen scenarios) |
| `CurrencyEngineTests` | FAA currency rule calculations |
| `EndorsementServiceTests` | Templates, signing, remote packages |
| `DataManagementTests` | Import, export, backup/restore |
| `ReportAnalyticsEngineTests` | Report totals and filters |
| `AdvancedFeaturesTests` | Fuel, expenses, maintenance |
| `NaturalLanguageSearchEngineTests` | Search parsing and filtering |

## Project Structure

```
AeroLogUltimate/
├── App/                 # Entry point, environment, navigation
├── Core/                # Persistence, sync, settings
├── Models/              # SwiftData entities and schema
├── Services/            # Business logic
├── Features/            # SwiftUI screens by domain
├── UI/                  # Shared components, theme, layout
└── Utilities/           # Validation, formatting, extensions

AeroLogUltimateTests/    # Unit and scenario tests
```

## Privacy & Offline Operation

All logbook data is stored locally on device. The app functions fully offline. Backup files are user-controlled exports. Optional encrypted sync provisions a local encrypted container; remote upload is not yet enabled.

## License

Proprietary — All rights reserved.