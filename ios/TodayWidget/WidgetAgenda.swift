import Foundation

/// What the widget draws for one day.
enum WidgetContent: Equatable {
  /// The app never wrote anything: no text is available yet.
  case appIcon
  case signedOut(text: String)
  /// Nothing due (empty) or the snapshot no longer covers the day (stale).
  case message(header: String, text: String)
  /// [overdue] and [pending] group what is not listed in [rows]; each is
  /// `nil` when there is nothing to group.
  case tasks(header: String, overdue: String?, pending: String?, rows: [WidgetRow])
}

struct WidgetRow: Equatable {
  let id: String
  let title: String
}

/// The part of the rule the native side owns. The Flutter app already chose
/// and ordered the tasks, so here they are only split by the local day, cut
/// to what fits and grouped.
enum WidgetAgenda {
  /// [rows] holds today's tasks in the snapshot order, most recent first:
  /// the view draws it bottom-up, below the groups.
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
      today <= coversUntil,
      let pendingCount = strings.pendingCount,
      let overdueCount = strings.overdueCount
    else { return .message(header: strings.header, text: strings.stale) }

    // ISO days compare in calendar order.
    let todays = snapshot.tasks.filter { $0.dueDate == today }
    let overdue = snapshot.tasks.filter { $0.dueDate < today }.count
    guard !todays.isEmpty || overdue > 0 else {
      return .message(header: strings.header, text: strings.empty)
    }

    // The overdue group always takes a row. When today's tasks do not all
    // fit, one more row goes to the group of the oldest ones.
    let free = max(capacity - (overdue > 0 ? 1 : 0), 0)
    let shown = todays.count <= free ? todays.count : max(free - 1, 0)
    let pending = todays.count - shown
    return .tasks(
      header: strings.header,
      overdue: overdue > 0 ? overdueCount.format(overdue) : nil,
      pending: pending > 0 ? pendingCount.format(pending) : nil,
      rows: todays.prefix(shown).map { WidgetRow(id: $0.id, title: $0.title) }
    )
  }

  /// Rows of [rowHeight] that fit below a header of [headerHeight]. Never
  /// less than one, so a tiny widget still shows something.
  static func rowsThatFit(height: CGFloat, headerHeight: CGFloat, rowHeight: CGFloat) -> Int {
    guard rowHeight > 0 else { return 1 }
    return max(Int((height - headerHeight) / rowHeight), 1)
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
