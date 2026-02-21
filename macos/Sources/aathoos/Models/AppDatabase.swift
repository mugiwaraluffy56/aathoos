import Foundation
import AathoosCore

/// Manages the single application-wide database handle.
///
/// Opens the SQLite file in ~/Library/Application Support/aathoos/aathoos.db
/// and vends a `CoreBridge` that wraps it.
final class AppDatabase {

  static let shared = AppDatabase()

  let bridge: CoreBridge

  private init() {
    let appSupport = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = appSupport.appendingPathComponent("aathoos", isDirectory: true)

    try? FileManager.default.createDirectory(
      at: dir,
      withIntermediateDirectories: true
    )

    let dbPath = dir.appendingPathComponent("aathoos.db").path
    guard let handle = aathoos_db_open(dbPath) else {
      fatalError("Failed to open database at \(dbPath)")
    }
    bridge = CoreBridge(db: handle)
  }
}
