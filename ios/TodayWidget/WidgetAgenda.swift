import Foundation

/// What the widget draws for one day.
enum WidgetContent: Equatable {
  /// The app never wrote anything: no text is available yet.
  case appIcon
  case signedOut(text: String)
  /// Nothing due (empty) or the snapshot no longer covers the day (stale).
  case message(header: String, text: String)
  case tasks(header: String, rows: [WidgetRow])
}

struct WidgetRow: Equatable {
  let id: String
  let title: String
  let isOverdue: Bool
  let accessibilityLabel: String
}

/// The part of the rule the native side owns. The Flutter app already chose
/// and ordered the tasks, so here they are only filtered by the local day,
/// cut to what fits and marked overdue.
enum WidgetAgenda {
  /// [rows] keeps the snapshot order, most recent first: the view draws it
  /// bottom-up.
  static func content(
    for snapshot: WidgetSnapshot?,
    today: String,
    capacity: Int
  ) -> WidgetContent {
    guard let snapshot else { return .appIcon }
    let strings = snapshot.strings
    guard snapshot.signedIn else { return .signedOut(text: strings.signedOut) }
    guard
      snapshot.version <= WidgetSnapshot.supportedVersion,
      let coversUntil = snapshot.coversUntil,
      today <= coversUntil
    else { return .message(header: strings.header, text: strings.stale) }

    // ISO days compare in calendar order.
    let rows = snapshot.tasks
      .filter { $0.dueDate <= today }
      .prefix(max(capacity, 0))
      .map { task -> WidgetRow in
        let isOverdue = task.dueDate < today
        return WidgetRow(
          id: task.id,
          title: task.title,
          isOverdue: isOverdue,
          accessibilityLabel: isOverdue
            ? "\(strings.overdue): \(task.title)" : task.title
        )
      }
    guard !rows.isEmpty else {
      return .message(header: strings.header, text: strings.empty)
    }
    return .tasks(header: strings.header, rows: Array(rows))
  }

  static func isoDay(of date: Date, calendar: Calendar) -> String {
    let day = calendar.dateComponents([.year, .month, .day], from: date)
    return String(
      format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
  }

  /// Every local midnight after [now] up to the first day past
  /// [coversUntil], when the widget turns stale. Capped as a safeguard
  /// against a malformed date.
  static func midnights(
    after now: Date,
    through coversUntil: String,
    calendar: Calendar,
    limit: Int = 16
  ) -> [Date] {
    var dates: [Date] = []
    var cursor = now
    while dates.count < limit,
      let midnight = calendar.nextDate(
        after: cursor,
        matching: DateComponents(hour: 0, minute: 0, second: 0),
        matchingPolicy: .nextTime
      )
    {
      dates.append(midnight)
      if isoDay(of: midnight, calendar: calendar) > coversUntil { break }
      cursor = midnight
    }
    return dates
  }
}
