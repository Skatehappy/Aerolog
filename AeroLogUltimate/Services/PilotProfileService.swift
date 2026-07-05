import Foundation
import SwiftData

/// Data access helpers for pilot profile operations.
@MainActor
struct PilotProfileService {
    let dataStore: DataStore

    func primaryProfile() throws -> PilotProfile? {
        try dataStore.primaryPilotProfile()
    }

    func allProfiles() throws -> [PilotProfile] {
        let descriptor = FetchDescriptor<PilotProfile>(
            sortBy: [SortDescriptor(\.lastName), SortDescriptor(\.firstName)]
        )
        return try dataStore.fetch(descriptor)
    }

    func students() throws -> [PilotProfile] {
        let descriptor = FetchDescriptor<PilotProfile>(
            predicate: #Predicate { $0.isPrimaryProfile == false && $0.isCFI == false },
            sortBy: [SortDescriptor(\.lastName)]
        )
        return try dataStore.fetch(descriptor)
    }

    func cfis() throws -> [PilotProfile] {
        let descriptor = FetchDescriptor<PilotProfile>(
            predicate: #Predicate { $0.isCFI == true },
            sortBy: [SortDescriptor(\.lastName)]
        )
        return try dataStore.fetch(descriptor)
    }

    @discardableResult
    func createProfile(
        firstName: String,
        lastName: String,
        isCFI: Bool = false
    ) throws -> PilotProfile {
        let profile = PilotProfile(firstName: firstName, lastName: lastName, isCFI: isCFI)
        dataStore.insert(profile)
        try dataStore.save()
        return profile
    }

    func update(_ profile: PilotProfile) throws {
        profile.touch()
        try dataStore.save()
    }
}