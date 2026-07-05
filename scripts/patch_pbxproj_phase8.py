from pathlib import Path

pbx_path = Path("AeroLogUltimate.xcodeproj/project.pbxproj")
pbx = pbx_path.read_text(encoding="utf-8")

entries = [
    ("D2", "WeightBalanceLog.swift", "app"),
    ("D3", "FlightExpense.swift", "app"),
    ("D4", "MaintenanceItem.swift", "app"),
    ("D5", "FlightSearchCriteria.swift", "app"),
    ("D6", "NaturalLanguageSearchEngine.swift", "app"),
    ("D7", "WeightBalanceCalculator.swift", "app"),
    ("D8", "ExpenseService.swift", "app"),
    ("D9", "MaintenanceService.swift", "app"),
    ("D10", "MaintenanceReminderScheduler.swift", "app"),
    ("D11", "FlightFuelSection.swift", "app"),
    ("D12", "FlightWeightBalanceSection.swift", "app"),
    ("D13", "FlightExpensesSection.swift", "app"),
    ("D14", "AircraftPerformanceView.swift", "app"),
    ("D15", "MaintenanceListView.swift", "app"),
    ("D16", "MaintenanceEditorView.swift", "app"),
    ("D17", "AircraftHubView.swift", "app"),
    ("D18", "CompactRootView.swift", "app"),
    ("D19", "AdaptiveRootView.swift", "app"),
    ("D20", "NaturalLanguageSearchEngineTests.swift", "test"),
    ("D21", "WeightBalanceCalculatorTests.swift", "test"),
    ("D22", "AdvancedFeaturesTests.swift", "test"),
]

build_lines = []
file_lines = []
app_source_lines = []
test_source_lines = []

for suffix, name, target in entries:
    bid = f"A100000100000000000000{suffix}"
    fid = f"A200000100000000000000{suffix}"
    build_lines.append(
        f"\t\t{bid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
    )
    file_lines.append(
        f"\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
    )
    line = f"\t\t\t\t{bid} /* {name} in Sources */,"
    if target == "test":
        test_source_lines.append(line)
    else:
        app_source_lines.append(line)

pbx = pbx.replace("/* End PBXBuildFile section */", "\n".join(build_lines) + "\n/* End PBXBuildFile section */")
pbx = pbx.replace(
    "\t\tA50000010000000000000001 /* AeroLogUltimate.app */",
    "\n".join(file_lines) + "\n\t\tA50000010000000000000001 /* AeroLogUltimate.app */",
)

if "00000027 /* Search */" not in pbx:
    search_group = """\t\tA70000010000000000000027 /* Search */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tA200000100000000000000D5 /* FlightSearchCriteria.swift */,
\t\t\t\tA200000100000000000000D6 /* NaturalLanguageSearchEngine.swift */,
\t\t\t),
\t\t\tpath = Search;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tA70000010000000000000028 /* WeightBalance */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tA200000100000000000000D7 /* WeightBalanceCalculator.swift */,
\t\t\t),
\t\t\tpath = WeightBalance;
\t\t\tsourceTree = "<group>";
\t\t};
\t\tA70000010000000000000029 /* Notifications */ = {
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\tA200000100000000000000D10 /* MaintenanceReminderScheduler.swift */,
\t\t\t),
\t\t\tpath = Notifications;
\t\t\tsourceTree = "<group>";
\t\t};
"""
    pbx = pbx.replace(
        "\t\tA7000001000000000000000D /* Settings */ = {",
        search_group + "\t\tA7000001000000000000000D /* Settings */ = {",
    )
    pbx = pbx.replace(
        "\t\t\t\tA7000001000000000000000D /* Settings */,\n\t\t\t),\n\t\t\tpath = Core;",
        "\t\t\t\tA7000001000000000000000D /* Settings */,\n\t\t\t\tA70000010000000000000029 /* Notifications */,\n\t\t\t),\n\t\t\tpath = Core;",
    )
    pbx = pbx.replace(
        "\t\t\t\tA70000010000000000000023 /* DataManagement */,\n\t\t\t),\n\t\t\tpath = Services;",
        "\t\t\t\tA70000010000000000000023 /* DataManagement */,\n\t\t\t\tA70000010000000000000027 /* Search */,\n\t\t\t\tA70000010000000000000028 /* WeightBalance */,\n\t\t\t),\n\t\t\tpath = Services;",
    )

for suffix, name in [("D2", "WeightBalanceLog.swift"), ("D3", "FlightExpense.swift"), ("D4", "MaintenanceItem.swift")]:
    fid = f"A200000100000000000000{suffix}"
    pbx = pbx.replace(
        "\t\t\t\tA2000001000000000000001C /* Attachment.swift */,\n\t\t\t),\n\t\t\tpath = Entities;",
        f"\t\t\t\tA2000001000000000000001C /* Attachment.swift */,\n\t\t\t\t{fid} /* {name} */,\n\t\t\t),\n\t\t\tpath = Entities;",
    )

pbx = pbx.replace(
    "\t\t\t\tA20000010000000000000021 /* AircraftService.swift */,",
    "\t\t\t\tA20000010000000000000021 /* AircraftService.swift */,\n\t\t\t\tA200000100000000000000D8 /* ExpenseService.swift */,\n\t\t\t\tA200000100000000000000D9 /* MaintenanceService.swift */,",
)

for suffix, name in [("D11", "FlightFuelSection.swift"), ("D12", "FlightWeightBalanceSection.swift"), ("D13", "FlightExpensesSection.swift")]:
    pbx = pbx.replace(
        "\t\t\t\tA20000010000000000000059 /* FlightAttachmentsSection.swift */,",
        f"\t\t\t\tA20000010000000000000059 /* FlightAttachmentsSection.swift */,\n\t\t\t\tA200000100000000000000{suffix} /* {name} */,",
    )

pbx = pbx.replace(
    "\t\t\t\tA2000001000000000000005C /* AircraftPickerSheet.swift */,",
    "\t\t\t\tA2000001000000000000005C /* AircraftPickerSheet.swift */,\n\t\t\t\tA200000100000000000000D14 /* AircraftPerformanceView.swift */,\n\t\t\t\tA200000100000000000000D15 /* MaintenanceListView.swift */,\n\t\t\t\tA200000100000000000000D16 /* MaintenanceEditorView.swift */,\n\t\t\t\tA200000100000000000000D17 /* AircraftHubView.swift */,",
)

pbx = pbx.replace(
    "\t\t\t\tA200000100000000000000C0 /* IPadAdaptiveLayout.swift */,",
    "\t\t\t\tA200000100000000000000C0 /* IPadAdaptiveLayout.swift */,\n\t\t\t\tA200000100000000000000D18 /* CompactRootView.swift */,\n\t\t\t\tA200000100000000000000D19 /* AdaptiveRootView.swift */,",
)

pbx = pbx.replace(
    "\t\t\t\tA200000100000000000000D0 /* iPadOptimizationTests.swift */,",
    "\t\t\t\tA200000100000000000000D0 /* iPadOptimizationTests.swift */,\n\t\t\t\tA200000100000000000000D20 /* NaturalLanguageSearchEngineTests.swift */,\n\t\t\t\tA200000100000000000000D21 /* WeightBalanceCalculatorTests.swift */,\n\t\t\t\tA200000100000000000000D22 /* AdvancedFeaturesTests.swift */,",
)

pbx = pbx.replace(
    "\t\t\t\tA100000100000000000000CE /* SearchDebouncer.swift in Sources */,",
    "\t\t\t\tA100000100000000000000CE /* SearchDebouncer.swift in Sources */,\n" + "\n".join(app_source_lines),
)

pbx = pbx.replace(
    "\t\t\t\tA100000100000000000000D0 /* iPadOptimizationTests.swift in Sources */,",
    "\t\t\t\tA100000100000000000000D0 /* iPadOptimizationTests.swift in Sources */,\n" + "\n".join(test_source_lines),
)

pbx_path.write_text(pbx, encoding="utf-8", newline="\n")
print("pbxproj updated")