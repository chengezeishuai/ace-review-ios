import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published private(set) var loadState: TaskLoadState = .idle
    @Published private(set) var retryingTaskIDs: Set<String> = []
    @Published private(set) var workingTaskIDs: Set<String> = []

    var isLoading: Bool {
        if case .loading = loadState { return true }
        return false
    }

    var errorMessage: String {
        if case let .failed(message) = loadState {
            let normalized = message.lowercased()
            if normalized.contains("已取消") || normalized.contains("cancelled") { return "" }
            return message
        }
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

    func detail(id: String) async -> TaskItem? {
        do { return try await APIClient.shared.task(id: id) }
        catch {
            loadState = .failed(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    func retry(_ task: TaskItem) async -> TaskItem? {
        guard task.status == "failed", !workingTaskIDs.contains(task.id) else {
            return nil
        }
        workingTaskIDs.insert(task.id)
        retryingTaskIDs.insert(task.id)
        defer {
            retryingTaskIDs.remove(task.id)
            workingTaskIDs.remove(task.id)
        }
        do {
            let retried = try await APIClient.shared.retryTask(id: task.id)
            await load()
            return retried
        } catch {
            loadState = .failed(error.localizedDescription)
            return nil
        }
    }

    func reanalyze(_ task: TaskItem, focus: String, label: String) async {
        guard !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !workingTaskIDs.contains(task.id) else { return }
        workingTaskIDs.insert(task.id)
        defer { workingTaskIDs.remove(task.id) }
        do {
            _ = try await APIClient.shared.reanalyzeTask(
                id: task.id,
                focus: focus,
                label: label
            )
            await load()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func delete(_ task: TaskItem) async {
        guard !workingTaskIDs.contains(task.id) else { return }
        workingTaskIDs.insert(task.id)
        defer { workingTaskIDs.remove(task.id) }
        do {
            try await APIClient.shared.deleteTask(id: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func rename(_ task: TaskItem, title: String) async {
        let cleaned = String(
            title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)
        )
        guard !cleaned.isEmpty, !workingTaskIDs.contains(task.id) else { return }
        workingTaskIDs.insert(task.id)
        defer { workingTaskIDs.remove(task.id) }
        do {
            _ = try await APIClient.shared.renameTask(id: task.id, title: cleaned)
            await load()
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
