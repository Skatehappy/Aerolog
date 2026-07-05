import Foundation

/// Debounces rapid search input to reduce list re-filtering on large logbooks.
@MainActor
final class SearchDebouncer: ObservableObject {
    @Published private(set) var debouncedText = ""
    private var task: Task<Void, Never>?
    private let delayNanoseconds: UInt64

    init(delayMilliseconds: Int = 200) {
        self.delayNanoseconds = UInt64(delayMilliseconds) * 1_000_000
    }

    func submit(_ text: String) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            debouncedText = text
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}