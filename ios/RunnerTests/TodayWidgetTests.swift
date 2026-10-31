import XCTest

/// The widget's own share of the rule: split by the local day, cut to what
/// fits, group the rest. Ordering is the Flutter app's job and is tested there.
final class TodayWidgetTests: XCTestCase {
  private let strings = """
    {"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",\
    "signedOut":"Entre no app para ver suas tarefas",\
    "pendingCount":{"one":"1 tarefa pendente","other":"{count} tarefas pendentes"},\
    "overdueCount":{"one":"1 tarefa atrasada","other":"{count} tarefas atrasadas"}}
    """

  private func snapshot(
    version: Int = 2,
    signedIn: Bool = true,
    coversUntil: String? = "2026-11-05",
    tasks: [(id: String, dueDate: String)] = [],
    strings: String? = nil
  ) -> WidgetSnapshot {
    let taskJson = tasks.map {
      #"{"id":"\#($0.id)","title":"Task \#($0.id)","dueDate":"\#($0.dueDate)","createdAt":"2026-10-01T12:00:00.000Z"}"#
    }.joined(separator: ",")
    let covers = coversUntil.map { #","coversUntil":"\#($0)""# } ?? ""
    let json = """
      {"version":\(version),"signedIn":\(signedIn),"generatedAt":"2026-10-29T13:02:00.000Z"\
      \(covers),"tasks":[\(taskJson)],"strings":\(strings ?? self.strings)}
      """
    return WidgetSnapshot.decode(json)!
  }

  /// Rows top to bottom, as drawn: overdue group, pending group, then
  /// today's tasks from the oldest to the most recent.
  private func lines(_ content: WidgetContent) -> [String] {
    guard case .tasks(_, let overdue, let pending, let rows) = content else { return [] }
    return [overdue, pending].compactMap { $0 } + rows.reversed().map(\.id)
  }

  func testNoSnapshotShowsOnlyTheIcon() {
    XCTAssertEqual(
      WidgetAgenda.content(for: nil, today: "2026-10-29", capacity: 3), .appIcon)
  }

  func testMalformedJsonIsNoSnapshot() {
    XCTAssertNil(WidgetSnapshot.decode("{\"version\":1}"))
    XCTAssertNil(WidgetSnapshot.decode("not json"))
  }

  func testSignedOutShowsTheSignInMessage() {
    let content = WidgetAgenda.content(
      for: snapshot(signedIn: false, coversUntil: nil), today: "2026-10-29", capacity: 3)

    XCTAssertEqual(content, .signedOut(text: "Entre no app para ver suas tarefas"))
  }

  func testDropsTasksDueAfterToday() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("tomorrow", "2026-10-30"), ("today", "2026-10-29")]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(lines(content), ["today"])
  }

  func testGroupsOverdueTasksInsteadOfListingThem() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [
        ("today", "2026-10-29"), ("late", "2026-10-28"), ("later", "2026-10-20"),
      ]),
      today: "2026-10-29", capacity: 8)

    XCTAssertEqual(
      content,
      .tasks(
        header: "Hoje", overdue: "2 tarefas atrasadas", pending: nil,
        rows: [WidgetRow(id: "today", title: "Task today")]))
  }

  func testSingleOverdueTaskUsesTheSingular() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("late", "2026-10-28")]), today: "2026-10-29", capacity: 3)

    XCTAssertEqual(lines(content), ["1 tarefa atrasada"])
  }

  func testEverythingFitsWithoutPendingGroup() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("t3", "2026-10-29"), ("t2", "2026-10-29"), ("t1", "2026-10-29")]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(lines(content), ["t1", "t2", "t3"])
  }

  func testGroupsTheOldestOfTodayWhenTheyDoNotFit() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [
        ("t4", "2026-10-29"), ("t3", "2026-10-29"), ("t2", "2026-10-29"), ("t1", "2026-10-29"),
      ]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(lines(content), ["2 tarefas pendentes", "t3", "t4"])
  }

  func testOverdueGroupTakesARowBeforeThePendingOne() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [
        ("t3", "2026-10-29"), ("t2", "2026-10-29"), ("t1", "2026-10-29"), ("o1", "2026-10-28"),
      ]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(lines(content), ["1 tarefa atrasada", "2 tarefas pendentes", "t3"])
  }

  func testTomorrowsTaskBecomesTodayAndTodaysBecomesOverdue() {
    let data = snapshot(tasks: [("b", "2026-10-30"), ("a", "2026-10-29")])

    XCTAssertEqual(
      lines(WidgetAgenda.content(for: data, today: "2026-10-29", capacity: 3)), ["a"])
    XCTAssertEqual(
      lines(WidgetAgenda.content(for: data, today: "2026-10-30", capacity: 3)),
      ["1 tarefa atrasada", "b"])
  }

  func testNothingDueShowsTheEmptyMessage() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("later", "2026-11-02")]), today: "2026-10-29", capacity: 3)

    XCTAssertEqual(content, .message(header: "Hoje", text: "Nada para hoje"))
  }

  func testPastTheHorizonIsStale() {
    let data = snapshot(coversUntil: "2026-11-05", tasks: [("a", "2026-10-29")])

    XCTAssertEqual(
      lines(WidgetAgenda.content(for: data, today: "2026-11-05", capacity: 3)),
      ["1 tarefa atrasada"])
    XCTAssertEqual(
      WidgetAgenda.content(for: data, today: "2026-11-06", capacity: 3),
      .message(header: "Hoje", text: "Abra o app para atualizar"))
  }

  func testNewerFormatIsStale() {
    XCTAssertEqual(
      WidgetAgenda.content(for: snapshot(version: 3), today: "2026-10-29", capacity: 3),
      .message(header: "Hoje", text: "Abra o app para atualizar"))
  }

  func testOlderFormatWithoutGroupTextsIsStale() {
    let v1Strings = """
      {"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",\
      "signedOut":"Entre no app para ver suas tarefas","overdue":"Atrasada"}
      """
    let data = snapshot(version: 1, tasks: [("a", "2026-10-29")], strings: v1Strings)

    XCTAssertEqual(
      WidgetAgenda.content(for: data, today: "2026-10-29", capacity: 3),
      .message(header: "Hoje", text: "Abra o app para atualizar"))
  }

  func testRowsThatFitGrowWithTheHeightAndNeverDropBelowOne() {
    // Small and large widgets of a 6.1" iPhone, after the content margins.
    XCTAssertEqual(WidgetAgenda.rowsThatFit(height: 126, headerHeight: 24, rowHeight: 22), 4)
    XCTAssertEqual(WidgetAgenda.rowsThatFit(height: 322, headerHeight: 24, rowHeight: 22), 13)
    XCTAssertEqual(WidgetAgenda.rowsThatFit(height: 30, headerHeight: 24, rowHeight: 22), 1)
  }

  func testMidnightsRunUntilTheDayAfterTheHorizon() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 15))!

    let days = WidgetAgenda.midnights(after: now, through: "2026-11-02", calendar: calendar)
      .map { WidgetAgenda.isoDay(of: $0, calendar: calendar) }

    XCTAssertEqual(days, ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02", "2026-11-03"])
  }

  func testMidnightsSurviveDaylightSavingChanges() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    // Clocks go back on 2026-11-01 in New York.
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 20))!

    let midnights = WidgetAgenda.midnights(after: now, through: "2026-11-02", calendar: calendar)

    XCTAssertEqual(
      midnights.map { WidgetAgenda.isoDay(of: $0, calendar: calendar) },
      ["2026-11-01", "2026-11-02", "2026-11-03"])
    for midnight in midnights {
      XCTAssertEqual(calendar.component(.hour, from: midnight), 0)
    }
  }

  func testMidnightsAreCappedForMalformedDates() {
    let midnights = WidgetAgenda.midnights(
      after: Date(), through: "9999-12-31", calendar: Calendar(identifier: .gregorian))

    XCTAssertEqual(midnights.count, 16)
  }
}
