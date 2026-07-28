import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published private(set) var loadState: TaskLoadState = .idle
    @Published private(set) var retryingTaskIDs: Set<String> = []

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var errorMessage: String {
        if case let .failed(message) = loadState { return message }
        return ""
    }

    func load() async {
        guard !isLoading else { return }
        loadState = .loading
        do {
            tasks = try await APIClient.shared.tasks()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func retry(_ task: TaskItem) async {
        guard task.status == "failed", !retryingTaskIDs.contains(task.id) else {
            return
        }
        retryingTaskIDs.insert(task.id)
        defer { retryingTaskIDs.remove(task.id) }
        do {
            _ = try await APIClient.shared.retryTask(id: task.id)
            await load()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
