import SwiftUI

struct TasksView: View {
  @StateObject private var store = TaskStore()
  @State private var showingAddSheet = false

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(AppSection.tasks.rawValue)
            .font(.largeTitle.weight(.bold))
            .foregroundColor(Color.appForeground)
          Text(AppSection.tasks.subtitle)
            .font(.subheadline)
            .foregroundColor(Color.appForeground.opacity(0.5))
        }
        Spacer()
        Button {
          showingAddSheet = true
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color.appForeground)
            .padding(8)
            .background(Color.appSurface)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 32)
      .padding(.top, 32)
      .padding(.bottom, 20)

      if store.tasks.isEmpty {
        Spacer()
        VStack(spacing: 8) {
          Image(systemName: "checkmark.circle")
            .font(.system(size: 40))
            .foregroundColor(Color.appForeground.opacity(0.2))
          Text("No tasks yet")
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Color.appForeground.opacity(0.35))
          Text("Press + to add your first task")
            .font(.system(size: 12))
            .foregroundColor(Color.appForeground.opacity(0.2))
        }
        Spacer()
      } else {
        List {
          ForEach(store.tasks) { task in
            TaskRow(task: task) {
              store.toggleCompleted(task)
            }
            .listRowBackground(Color.appBackground)
            .listRowSeparator(.hidden)
          }
          .onDelete { offsets in
            store.delete(at: offsets)
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
      }
    }
    .background(Color.appBackground)
    .sheet(isPresented: $showingAddSheet) {
      AddTaskSheet { title, notes, priority in
        store.add(title: title, notes: notes.isEmpty ? nil : notes, priority: priority)
      }
    }
  }
}

// ── Task row ─────────────────────────────────────────────────────────────────

private struct TaskRow: View {
  let task: ATask
  let onToggle: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: onToggle) {
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18))
          .foregroundColor(task.isCompleted ? Color.appAccent : Color.appForeground.opacity(0.4))
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 2) {
        Text(task.title)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(
            task.isCompleted
              ? Color.appForeground.opacity(0.35)
              : Color.appForeground
          )
          .strikethrough(task.isCompleted, color: Color.appForeground.opacity(0.35))

        if let notes = task.notes, !notes.isEmpty {
          Text(notes)
            .font(.system(size: 11))
            .foregroundColor(Color.appForeground.opacity(0.4))
            .lineLimit(1)
        }
      }

      Spacer()

      PriorityBadge(priority: TaskPriority(rawValue: task.priority.rawValue) ?? .medium)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(Color.appSurface.opacity(0.5))
    .cornerRadius(8)
    .padding(.horizontal, 16)
    .padding(.vertical, 3)
  }
}

// ── Priority badge ────────────────────────────────────────────────────────────

private struct PriorityBadge: View {
  let priority: TaskPriority

  var color: Color {
    switch priority {
    case .high:   return Color.appAccent
    case .medium: return Color(red: 0.9, green: 0.6, blue: 0.2)
    case .low:    return Color.appForeground.opacity(0.3)
    }
  }

  var body: some View {
    Text(priority.label)
      .font(.system(size: 10, weight: .semibold))
      .foregroundColor(color)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(color.opacity(0.12))
      .cornerRadius(4)
  }
}

// ── Add task sheet ────────────────────────────────────────────────────────────

private struct AddTaskSheet: View {
  @Environment(\.dismiss) private var dismiss
  let onAdd: (String, String, TaskPriority) -> Void

  @State private var title = ""
  @State private var notes = ""
  @State private var priority: TaskPriority = .medium

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("New Task")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(Color.appForeground)

      VStack(alignment: .leading, spacing: 6) {
        Text("Title")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Color.appForeground.opacity(0.5))
        TextField("Task title", text: $title)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
          .foregroundColor(Color.appForeground)
          .padding(10)
          .background(Color.appSurface)
          .cornerRadius(8)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Notes")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Color.appForeground.opacity(0.5))
        TextField("Optional notes", text: $notes)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
          .foregroundColor(Color.appForeground)
          .padding(10)
          .background(Color.appSurface)
          .cornerRadius(8)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("Priority")
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Color.appForeground.opacity(0.5))
        Picker("Priority", selection: $priority) {
          Text("Low").tag(TaskPriority.low)
          Text("Medium").tag(TaskPriority.medium)
          Text("High").tag(TaskPriority.high)
        }
        .pickerStyle(.segmented)
      }

      HStack {
        Button("Cancel") { dismiss() }
          .buttonStyle(.plain)
          .foregroundColor(Color.appForeground.opacity(0.5))

        Spacer()

        Button("Add Task") {
          guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
          onAdd(title, notes, priority)
          dismiss()
        }
        .buttonStyle(.plain)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.appAccent)
        .cornerRadius(8)
        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding(24)
    .frame(width: 400)
    .background(Color.appBackground)
  }
}
