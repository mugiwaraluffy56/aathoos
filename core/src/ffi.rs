//! C FFI layer — every function here is callable from Swift (macOS) and
//! C# via P/Invoke (Windows).  The pattern is:
//!
//!   * Functions that return data  → JSON C string  (caller frees with `aathoos_free_string`)
//!   * Functions that mutate data  → `bool`  (true = success)
//!   * Numeric aggregates          → raw `i64`
//!   * The database handle         → opaque `*mut Database` (free with `aathoos_db_close`)
//!
//! All pointer inputs are null-checked.  The library never panics across
//! the FFI boundary — errors return NULL / false instead.

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;

use crate::db::Database;
use crate::models::task::Priority;
use crate::repos::goal_repo::GoalRepo;
use crate::repos::note_repo::NoteRepo;
use crate::repos::study_session_repo::StudySessionRepo;
use crate::repos::task_repo::TaskRepo;

// ── Internal helpers ────────────────────────────────────────────────────────

/// Serialize `value` to JSON and hand ownership to the caller as a C string.
fn json_to_c<T: serde::Serialize>(value: &T) -> *mut c_char {
  match serde_json::to_string(value) {
    Ok(s) => match CString::new(s) {
      Ok(cs) => cs.into_raw(),
      Err(_) => ptr::null_mut(),
    },
    Err(_) => ptr::null_mut(),
  }
}

/// Borrow a `&str` from a nullable C string pointer.
unsafe fn c_to_str<'a>(ptr: *const c_char) -> Option<&'a str> {
  if ptr.is_null() {
    None
  } else {
    CStr::from_ptr(ptr).to_str().ok()
  }
}

/// Borrow a `&str` from a C string, returning `""` if null.
unsafe fn c_to_str_or_empty<'a>(ptr: *const c_char) -> &'a str {
  if ptr.is_null() {
    ""
  } else {
    CStr::from_ptr(ptr).to_str().unwrap_or("")
  }
}

// ── Database lifecycle ──────────────────────────────────────────────────────

/// Open (or create) a SQLite database at `path`.
/// Returns an opaque handle, or NULL on failure.
/// Caller must close with `aathoos_db_close`.
#[no_mangle]
pub extern "C" fn aathoos_db_open(path: *const c_char) -> *mut Database {
  let path = match unsafe { c_to_str(path) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match Database::open(path) {
    Ok(db) => Box::into_raw(Box::new(db)),
    Err(_) => ptr::null_mut(),
  }
}

/// Close and free a database handle obtained from `aathoos_db_open`.
#[no_mangle]
pub extern "C" fn aathoos_db_close(db: *mut Database) {
  if !db.is_null() {
    unsafe { drop(Box::from_raw(db)) };
  }
}

/// Free a C string returned by any function in this library.
#[no_mangle]
pub extern "C" fn aathoos_free_string(ptr: *mut c_char) {
  if !ptr.is_null() {
    unsafe { drop(CString::from_raw(ptr)) };
  }
}

// ── Tasks ───────────────────────────────────────────────────────────────────

/// Create a task.  Pass `due_date = 0` for no due date.
/// `notes` may be NULL.  `priority`: 0 = Low, 1 = Medium, 2 = High.
/// Returns JSON Task object, or NULL on error.
#[no_mangle]
pub extern "C" fn aathoos_task_create(
  db: *mut Database,
  title: *const c_char,
  notes: *const c_char,
  due_date: i64,
  priority: i32,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let title = match unsafe { c_to_str(title) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  let notes = unsafe { c_to_str(notes) };
  let due_date = if due_date == 0 { None } else { Some(due_date) };
  let priority = Priority::from(priority as i64);

  match TaskRepo::new(db).create(title, notes, due_date, priority) {
    Ok(task) => json_to_c(&task),
    Err(_) => ptr::null_mut(),
  }
}

/// Fetch a single task by ID. Returns JSON Task or NULL.
#[no_mangle]
pub extern "C" fn aathoos_task_get(
  db: *mut Database,
  id: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match TaskRepo::new(db).get_by_id(id) {
    Ok(task) => json_to_c(&task),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of all tasks, or NULL on error.
#[no_mangle]
pub extern "C" fn aathoos_task_list_all(db: *mut Database) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  match TaskRepo::new(db).list_all() {
    Ok(tasks) => json_to_c(&tasks),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of incomplete tasks ordered by due date, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_task_list_incomplete(db: *mut Database) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  match TaskRepo::new(db).list_incomplete() {
    Ok(tasks) => json_to_c(&tasks),
    Err(_) => ptr::null_mut(),
  }
}

/// Mark a task complete or incomplete. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_task_set_completed(
  db: *mut Database,
  id: *const c_char,
  completed: bool,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  TaskRepo::new(db).set_completed(id, completed).is_ok()
}

/// Update a task's title. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_task_update_title(
  db: *mut Database,
  id: *const c_char,
  title: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  let title = unsafe { c_to_str_or_empty(title) };
  TaskRepo::new(db).update_title(id, title).is_ok()
}

/// Delete a task. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_task_delete(
  db: *mut Database,
  id: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  TaskRepo::new(db).delete(id).is_ok()
}

// ── Notes ───────────────────────────────────────────────────────────────────

/// Create a note. `subject` may be NULL. Returns JSON Note or NULL.
#[no_mangle]
pub extern "C" fn aathoos_note_create(
  db: *mut Database,
  title: *const c_char,
  body: *const c_char,
  subject: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let title = match unsafe { c_to_str(title) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  let body = unsafe { c_to_str_or_empty(body) };
  let subject = unsafe { c_to_str(subject) };

  match NoteRepo::new(db).create(title, body, subject) {
    Ok(note) => json_to_c(&note),
    Err(_) => ptr::null_mut(),
  }
}

/// Fetch a single note by ID. Returns JSON Note or NULL.
#[no_mangle]
pub extern "C" fn aathoos_note_get(
  db: *mut Database,
  id: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match NoteRepo::new(db).get_by_id(id) {
    Ok(note) => json_to_c(&note),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of all notes, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_note_list_all(db: *mut Database) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  match NoteRepo::new(db).list_all() {
    Ok(notes) => json_to_c(&notes),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of notes filtered by subject, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_note_list_by_subject(
  db: *mut Database,
  subject: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let subject = match unsafe { c_to_str(subject) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match NoteRepo::new(db).list_by_subject(subject) {
    Ok(notes) => json_to_c(&notes),
    Err(_) => ptr::null_mut(),
  }
}

/// Update a note's body. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_note_update_body(
  db: *mut Database,
  id: *const c_char,
  body: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  let body = unsafe { c_to_str_or_empty(body) };
  NoteRepo::new(db).update_body(id, body).is_ok()
}

/// Delete a note. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_note_delete(
  db: *mut Database,
  id: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  NoteRepo::new(db).delete(id).is_ok()
}

// ── Goals ───────────────────────────────────────────────────────────────────

/// Create a goal. `description` and `target_date` are optional (NULL / 0).
/// Returns JSON Goal or NULL.
#[no_mangle]
pub extern "C" fn aathoos_goal_create(
  db: *mut Database,
  title: *const c_char,
  description: *const c_char,
  target_date: i64,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let title = match unsafe { c_to_str(title) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  let description = unsafe { c_to_str(description) };
  let target_date = if target_date == 0 { None } else { Some(target_date) };

  match GoalRepo::new(db).create(title, description, target_date) {
    Ok(goal) => json_to_c(&goal),
    Err(_) => ptr::null_mut(),
  }
}

/// Fetch a single goal by ID. Returns JSON Goal or NULL.
#[no_mangle]
pub extern "C" fn aathoos_goal_get(
  db: *mut Database,
  id: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match GoalRepo::new(db).get_by_id(id) {
    Ok(goal) => json_to_c(&goal),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of all goals, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_goal_list_all(db: *mut Database) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  match GoalRepo::new(db).list_all() {
    Ok(goals) => json_to_c(&goals),
    Err(_) => ptr::null_mut(),
  }
}

/// Set goal progress (0.0–1.0). Automatically marks complete at 1.0.
/// Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_goal_set_progress(
  db: *mut Database,
  id: *const c_char,
  progress: f64,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  GoalRepo::new(db).set_progress(id, progress).is_ok()
}

/// Delete a goal. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_goal_delete(
  db: *mut Database,
  id: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  GoalRepo::new(db).delete(id).is_ok()
}

// ── Study Sessions ──────────────────────────────────────────────────────────

/// Record a study session. `notes` may be NULL.
/// Returns JSON StudySession or NULL.
#[no_mangle]
pub extern "C" fn aathoos_study_session_create(
  db: *mut Database,
  subject: *const c_char,
  duration_secs: i64,
  notes: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let subject = match unsafe { c_to_str(subject) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  let notes = unsafe { c_to_str(notes) };

  match StudySessionRepo::new(db).create(subject, duration_secs, notes) {
    Ok(session) => json_to_c(&session),
    Err(_) => ptr::null_mut(),
  }
}

/// Fetch a single study session by ID. Returns JSON StudySession or NULL.
#[no_mangle]
pub extern "C" fn aathoos_study_session_get(
  db: *mut Database,
  id: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match StudySessionRepo::new(db).get_by_id(id) {
    Ok(session) => json_to_c(&session),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of all study sessions, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_study_session_list_all(db: *mut Database) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  match StudySessionRepo::new(db).list_all() {
    Ok(sessions) => json_to_c(&sessions),
    Err(_) => ptr::null_mut(),
  }
}

/// Returns a JSON array of sessions for a given subject, or NULL.
#[no_mangle]
pub extern "C" fn aathoos_study_session_list_by_subject(
  db: *mut Database,
  subject: *const c_char,
) -> *mut c_char {
  if db.is_null() {
    return ptr::null_mut();
  }
  let db = unsafe { &*db };
  let subject = match unsafe { c_to_str(subject) } {
    Some(s) => s,
    None => return ptr::null_mut(),
  };
  match StudySessionRepo::new(db).list_by_subject(subject) {
    Ok(sessions) => json_to_c(&sessions),
    Err(_) => ptr::null_mut(),
  }
}

/// Total seconds studied for a subject. Returns -1 on error.
#[no_mangle]
pub extern "C" fn aathoos_study_session_total_duration(
  db: *mut Database,
  subject: *const c_char,
) -> i64 {
  if db.is_null() {
    return -1;
  }
  let db = unsafe { &*db };
  let subject = match unsafe { c_to_str(subject) } {
    Some(s) => s,
    None => return -1,
  };
  StudySessionRepo::new(db)
    .total_duration_for_subject(subject)
    .unwrap_or(-1)
}

/// Delete a study session. Returns true on success.
#[no_mangle]
pub extern "C" fn aathoos_study_session_delete(
  db: *mut Database,
  id: *const c_char,
) -> bool {
  if db.is_null() {
    return false;
  }
  let db = unsafe { &*db };
  let id = match unsafe { c_to_str(id) } {
    Some(s) => s,
    None => return false,
  };
  StudySessionRepo::new(db).delete(id).is_ok()
}
