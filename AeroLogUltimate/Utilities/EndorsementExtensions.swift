import Foundation

extension Endorsement {
    var filledPlaceholders: [String: String] {
        get {
            guard let json = filledPlaceholdersJSON,
                  let data = json.data(using: .utf8),
                  let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
            return map
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                filledPlaceholdersJSON = json
            }
        }
    }

    var isAwaitingSignature: Bool { status == .pendingSignature }
    var isSigned: Bool { status == .signed }

    var displayStudentName: String {
        student?.fullName ?? studentNameSnapshot ?? "Student"
    }

    var displayInstructorName: String {
        instructor?.fullName ?? instructorNameSnapshot ?? signerName ?? "Instructor"
    }

    var isDeleted: Bool {
        syncMetadata?.isSoftDeleted ?? false
    }
}

extension EndorsementTemplate {
    var syncID: UUID {
        syncMetadata?.syncID ?? UUID()
    }
}