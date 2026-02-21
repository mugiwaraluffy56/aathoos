/**
 * aathoos_core.h
 *
 * C API for the aathoos-core Rust library.
 *
 * Usage
 * -----
 *  macOS / Swift  — add this header via a bridging header or module map,
 *                   link against libaathoos_core.a (staticlib).
 *  Windows / C#   — P/Invoke the functions from aathoos_core.dll (cdylib).
 *
 * Memory contract
 * ---------------
 *  - Functions that return `char*` allocate on the Rust heap.
 *    The caller MUST free that pointer with `aathoos_free_string`.
 *  - The database handle returned by `aathoos_db_open` MUST be
 *    closed with `aathoos_db_close` when no longer needed.
 *  - Never free a pointer with the platform allocator (free / delete).
 *
 * Return values
 * -------------
 *  - `char*`  — JSON-encoded object / array, or NULL on error.
 *  - `bool`   — true on success, false on error (record not found, etc.).
 *  - `int64_t`— numeric result, or -1 on error.
 */

#ifndef AATHOOS_CORE_H
#define AATHOOS_CORE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── Opaque database handle ───────────────────────────────────────────────── */

typedef struct AathoosDb AathoosDb;

/* ── Database lifecycle ───────────────────────────────────────────────────── */

/** Open (or create) a SQLite database at `path`. Returns NULL on failure. */
AathoosDb *aathoos_db_open(const char *path);

/** Close and free a handle returned by `aathoos_db_open`. */
void aathoos_db_close(AathoosDb *db);

/** Free a `char*` returned by any function in this library. */
void aathoos_free_string(char *ptr);

/* ── Tasks ────────────────────────────────────────────────────────────────── */

/**
 * Create a task.
 *   title    — required, UTF-8.
 *   notes    — optional; pass NULL for none.
 *   due_date — Unix timestamp (seconds); pass 0 for no due date.
 *   priority — 0 = Low, 1 = Medium, 2 = High.
 * Returns JSON Task object, or NULL on error.
 */
char *aathoos_task_create(
  AathoosDb  *db,
  const char *title,
  const char *notes,
  int64_t     due_date,
  int32_t     priority
);

/** Returns JSON Task object for the given ID, or NULL. */
char *aathoos_task_get(AathoosDb *db, const char *id);

/** Returns JSON array of all tasks ordered by creation date, or NULL. */
char *aathoos_task_list_all(AathoosDb *db);

/** Returns JSON array of incomplete tasks ordered by due date / priority, or NULL. */
char *aathoos_task_list_incomplete(AathoosDb *db);

/** Mark a task complete or incomplete. Returns true on success. */
bool aathoos_task_set_completed(AathoosDb *db, const char *id, bool completed);

/** Update a task's title. Returns true on success. */
bool aathoos_task_update_title(AathoosDb *db, const char *id, const char *title);

/** Delete a task. Returns true on success. */
bool aathoos_task_delete(AathoosDb *db, const char *id);

/* ── Notes ────────────────────────────────────────────────────────────────── */

/**
 * Create a note.
 *   subject — optional; pass NULL for none.
 * Returns JSON Note object, or NULL on error.
 */
char *aathoos_note_create(
  AathoosDb  *db,
  const char *title,
  const char *body,
  const char *subject
);

/** Returns JSON Note object for the given ID, or NULL. */
char *aathoos_note_get(AathoosDb *db, const char *id);

/** Returns JSON array of all notes ordered by last update, or NULL. */
char *aathoos_note_list_all(AathoosDb *db);

/** Returns JSON array of notes for a given subject, or NULL. */
char *aathoos_note_list_by_subject(AathoosDb *db, const char *subject);

/** Replace a note's body. Returns true on success. */
bool aathoos_note_update_body(AathoosDb *db, const char *id, const char *body);

/** Delete a note. Returns true on success. */
bool aathoos_note_delete(AathoosDb *db, const char *id);

/* ── Goals ────────────────────────────────────────────────────────────────── */

/**
 * Create a goal.
 *   description — optional; pass NULL for none.
 *   target_date — Unix timestamp; pass 0 for open-ended.
 * Returns JSON Goal object, or NULL on error.
 */
char *aathoos_goal_create(
  AathoosDb  *db,
  const char *title,
  const char *description,
  int64_t     target_date
);

/** Returns JSON Goal object for the given ID, or NULL. */
char *aathoos_goal_get(AathoosDb *db, const char *id);

/** Returns JSON array of all goals ordered by creation date, or NULL. */
char *aathoos_goal_list_all(AathoosDb *db);

/**
 * Set goal progress (0.0–1.0). Automatically marks the goal complete
 * when progress reaches 1.0. Returns true on success.
 */
bool aathoos_goal_set_progress(AathoosDb *db, const char *id, double progress);

/** Delete a goal. Returns true on success. */
bool aathoos_goal_delete(AathoosDb *db, const char *id);

/* ── Study Sessions ───────────────────────────────────────────────────────── */

/**
 * Record a completed study session.
 *   duration_secs — length of the session in seconds.
 *   notes         — optional; pass NULL for none.
 * Returns JSON StudySession object, or NULL on error.
 */
char *aathoos_study_session_create(
  AathoosDb  *db,
  const char *subject,
  int64_t     duration_secs,
  const char *notes
);

/** Returns JSON StudySession for the given ID, or NULL. */
char *aathoos_study_session_get(AathoosDb *db, const char *id);

/** Returns JSON array of all sessions ordered by start time, or NULL. */
char *aathoos_study_session_list_all(AathoosDb *db);

/** Returns JSON array of sessions for a given subject, or NULL. */
char *aathoos_study_session_list_by_subject(AathoosDb *db, const char *subject);

/** Total seconds studied for a subject. Returns -1 on error. */
int64_t aathoos_study_session_total_duration(AathoosDb *db, const char *subject);

/** Delete a study session. Returns true on success. */
bool aathoos_study_session_delete(AathoosDb *db, const char *id);

#ifdef __cplusplus
}
#endif

#endif /* AATHOOS_CORE_H */
