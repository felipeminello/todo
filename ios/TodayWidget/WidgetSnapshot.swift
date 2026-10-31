import Foundation

/// The JSON the Flutter app writes (`WidgetSnapshotCodec` in Dart). Both
/// sides must change together with `supportedVersion`.
struct WidgetSnapshot: Decodable, Equatable {
  static let supportedVersion = 2
  static let appGroupId = "group.br.dev.minello.todo"
  static let storageKey = "today_widget_snapshot"

  struct Task: Decodable, Equatable {
    let id: String
    let title: String
    /// `YYYY-MM-DD`, a calendar day with no time zone.
    let dueDate: String
  }

  /// A text whose count only the widget knows.
  struct CountText: Decodable, Equatable {
    /// Must match `WidgetCountText.countToken` in Dart.
    static let countToken = "{count}"

    let one: String
    let other: String

    func format(_ count: Int) -> String {
      count == 1 ? one : other.replacingOccurrences(of: Self.countToken, with: String(count))
    }
  }

  struct Strings: Decodable, Equatable {
    let header: String
    let empty: String
    let stale: String
    let signedOut: String
    /// Absent in snapshots older than version 2, which then read as stale
    /// instead of failing to decode.
    let pendingCount: CountText?
    let overdueCount: CountText?
  }

  let version: Int
  let signedIn: Bool
  /// `YYYY-MM-DD`; absent when signed out.
  let coversUntil: String?
  /// Most recent due date first, then most recently created first.
  let tasks: [Task]
  let strings: Strings

  static func decode(_ json: String) -> WidgetSnapshot? {
    guard let data = json.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
  }

  static func load() -> WidgetSnapshot? {
    guard
      let json = UserDefaults(suiteName: appGroupId)?.string(forKey: storageKey)
    else { return nil }
    return decode(json)
  }
}
