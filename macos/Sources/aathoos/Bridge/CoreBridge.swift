import Foundation
import AathoosCore

// ── Swift model types ────────────────────────────────────────────────────────

enum TaskPriority: Int32, Codable {
  case low    = 0
  case medium = 1
  case high   = 2

  var label: String {
    switch self {
    case .low:    return "Low"
    case .medium: return "Medium"
    case .high:   return "High"
    }
  }
}

struct ATask: Identifiable, Codable {
  let id: String
  let title: String
  let notes: String?
  let dueDate: Int64?
  let priority: TaskPriority
  let isCompleted: Bool
  let createdAt: Int64
  let updatedAt: Int64

  enum CodingKeys: String, CodingKey {
    case id, title, notes
    case dueDate      = "due_date"
    case priority
    case isCompleted  = "is_completed"
    case createdAt    = "created_at"
    case updatedAt    = "updated_at"
  }
}

struct ANote: Identifiable, Codable {
  let id: String
  let title: String
  let body: String
  let subject: String?
  let createdAt: Int64
  let updatedAt: Int64

  enum CodingKeys: String, CodingKey {
    case id, title, body, subject
    case createdAt = "created_at"
    case updatedAt = "updated_at"
  }
}

struct AGoal: Identifiable, Codable {
  let id: String
  let title: String
  let description: String?
  let targetDate: Int64?
  let progress: Double
  let isCompleted: Bool
  let createdAt: Int64
  let updatedAt: Int64

  enum CodingKeys: String, CodingKey {
    case id, title, description, progress
    case targetDate  = "target_date"
    case isCompleted = "is_completed"
    case createdAt   = "created_at"
    case updatedAt   = "updated_at"
  }
}

struct AStudySession: Identifiable, Codable {
  let id: String
  let subject: String
  let durationSecs: Int64
  let notes: String?
  let startedAt: Int64

  enum CodingKeys: String, CodingKey {
    case id, subject, notes
    case durationSecs = "duration_secs"
    case startedAt    = "started_at"
  }
}

// ── CoreBridge ───────────────────────────────────────────────────────────────

/// Thin Swift wrapper over the C FFI. All calls are synchronous; callers
/// should dispatch to a background queue if needed.
final class CoreBridge {

  private let db: OpaquePointer

  init(db: OpaquePointer) {
    self.db = db
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  private func decode<T: Decodable>(_ ptr: UnsafeMutablePointer<Int8>?) -> T? {
    guard let ptr else { return nil }
    defer { aathoos_free_string(ptr) }
    let data = Data(String(cString: ptr).utf8)
    return try? JSONDecoder().decode(T.self, from: data)
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────

  @discardableResult
  func taskCreate(
    title: String,
    notes: String? = nil,
    dueDate: Int64 = 0,
    priority: TaskPriority = .medium
  ) -> ATask? {
    let ptr = aathoos_task_create(db, title, notes, dueDate, priority.rawValue)
    return decode(ptr)
  }

  func taskGet(id: String) -> ATask? {
    decode(aathoos_task_get(db, id))
  }

  func taskListAll() -> [ATask] {
    decode(aathoos_task_list_all(db)) ?? []
  }

  func taskListIncomplete() -> [ATask] {
    decode(aathoos_task_list_incomplete(db)) ?? []
  }

  @discardableResult
  func taskSetCompleted(id: String, completed: Bool) -> Bool {
    aathoos_task_set_completed(db, id, completed)
  }

  @discardableResult
  func taskUpdateTitle(id: String, title: String) -> Bool {
    aathoos_task_update_title(db, id, title)
  }

  @discardableResult
  func taskDelete(id: String) -> Bool {
    aathoos_task_delete(db, id)
  }

  // ── Notes ──────────────────────────────────────────────────────────────────

  @discardableResult
  func noteCreate(title: String, body: String, subject: String? = nil) -> ANote? {
    decode(aathoos_note_create(db, title, body, subject))
  }

  func noteGet(id: String) -> ANote? {
    decode(aathoos_note_get(db, id))
  }

  func noteListAll() -> [ANote] {
    decode(aathoos_note_list_all(db)) ?? []
  }

  func noteListBySubject(_ subject: String) -> [ANote] {
    decode(aathoos_note_list_by_subject(db, subject)) ?? []
  }

  @discardableResult
  func noteUpdateBody(id: String, body: String) -> Bool {
    aathoos_note_update_body(db, id, body)
  }

  @discardableResult
  func noteDelete(id: String) -> Bool {
    aathoos_note_delete(db, id)
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  @discardableResult
  func goalCreate(
    title: String,
    description: String? = nil,
    targetDate: Int64 = 0
  ) -> AGoal? {
    decode(aathoos_goal_create(db, title, description, targetDate))
  }

  func goalGet(id: String) -> AGoal? {
    decode(aathoos_goal_get(db, id))
  }

  func goalListAll() -> [AGoal] {
    decode(aathoos_goal_list_all(db)) ?? []
  }

  @discardableResult
  func goalSetProgress(id: String, progress: Double) -> Bool {
    aathoos_goal_set_progress(db, id, progress)
  }

  @discardableResult
  func goalDelete(id: String) -> Bool {
    aathoos_goal_delete(db, id)
  }

  // ── Study Sessions ─────────────────────────────────────────────────────────

  @discardableResult
  func studySessionCreate(
    subject: String,
    durationSecs: Int64,
    notes: String? = nil
  ) -> AStudySession? {
    decode(aathoos_study_session_create(db, subject, durationSecs, notes))
  }

  func studySessionGet(id: String) -> AStudySession? {
    decode(aathoos_study_session_get(db, id))
  }

  func studySessionListAll() -> [AStudySession] {
    decode(aathoos_study_session_list_all(db)) ?? []
  }

  func studySessionListBySubject(_ subject: String) -> [AStudySession] {
    decode(aathoos_study_session_list_by_subject(db, subject)) ?? []
  }

  func studySessionTotalDuration(subject: String) -> Int64 {
    aathoos_study_session_total_duration(db, subject)
  }

  @discardableResult
  func studySessionDelete(id: String) -> Bool {
    aathoos_study_session_delete(db, id)
  }
}
