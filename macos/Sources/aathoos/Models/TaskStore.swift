import Foundation

@MainActor
final class TaskStore: ObservableObject {

  @Published var tasks: [ATask] = []

  private let bridge: CoreBridge

  init(bridge: CoreBridge = AppDatabase.shared.bridge) {
    self.bridge = bridge
    refresh()
  }

  func refresh() {
    tasks = bridge.taskListAll()
  }

  func add(title: String, notes: String? = nil, priority: TaskPriority = .medium) {
    bridge.taskCreate(title: title, notes: notes, priority: priority)
    refresh()
  }

  func toggleCompleted(_ task: ATask) {
    bridge.taskSetCompleted(id: task.id, completed: !task.isCompleted)
    refresh()
  }

  func delete(id: String) {
    bridge.taskDelete(id: id)
    refresh()
  }

  func delete(at offsets: IndexSet) {
    offsets.forEach { delete(id: tasks[$0].id) }
  }
}
