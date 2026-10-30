import XCTest

/// The widget's own share of the rule: filter by the local day, cut to what
/// fits, mark overdue. Ordering is the Flutter app's job and is tested there.
final class TodayWidgetTests: XCTestCase {
  private let strings = """
    {"header":"Hoje","empty":"Nada para hoje","stale":"Abra o app para atualizar",\
    "signedOut":"Entre no app para ver suas tarefas","overdue":"Atrasada"}
    """

  private func snapshot(
    version: Int = 1,
    signedIn: Bool = true,
    coversUntil: String? = "2026-11-05",
    tasks: [(id: String, dueDate: String)] = []
  ) -> WidgetSnapshot {
    let taskJson = tasks.map {
      #"{"id":"\#($0.id)","title":"Task \#($0.id)","dueDate":"\#($0.dueDate)","createdAt":"2026-10-01T12:00:00.000Z"}"#
    }.joined(separator: ",")
    let covers = coversUntil.map { #","coversUntil":"\#($0)""# } ?? ""
    let json = """
      {"version":\(version),"signedIn":\(signedIn),"generatedAt":"2026-10-29T13:02:00.000Z"\
      \(covers),"tasks":[\(taskJson)],"strings":\(strings)}
      """
    return WidgetSnapshot.decode(json)!
  }

  private func rows(_ content: WidgetContent) -> [String] {
    guard case .tasks(_, let rows) = content else { return [] }
    return rows.map { "\($0.id)\($0.isOverdue ? "!" : "")" }
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

    XCTAssertEqual(rows(content), ["today"])
  }

  func testMarksOverdueTasksAndLabelsThemForScreenReaders() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("today", "2026-10-29"), ("late", "2026-10-28")]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(rows(content), ["today", "late!"])
    guard case .tasks(let header, let found) = content else { return XCTFail() }
    XCTAssertEqual(header, "Hoje")
    XCTAssertEqual(found[1].accessibilityLabel, "Atrasada: Task late")
    XCTAssertEqual(found[0].accessibilityLabel, "Task today")
  }

  func testCutsToCapacityKeepingTheMostRecent() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [
        ("t2", "2026-10-29"), ("t1", "2026-10-29"), ("o1", "2026-10-28"), ("o2", "2026-10-25"),
      ]),
      today: "2026-10-29", capacity: 3)

    XCTAssertEqual(rows(content), ["t2", "t1", "o1!"])
  }

  func testTomorrowsTaskBecomesTodayAndTodaysBecomesOverdue() {
    let data = snapshot(tasks: [("b", "2026-10-30"), ("a", "2026-10-29")])

    XCTAssertEqual(
      rows(WidgetAgenda.content(for: data, today: "2026-10-29", capacity: 3)), ["a"])
    XCTAssertEqual(
      rows(WidgetAgenda.content(for: data, today: "2026-10-30", capacity: 3)), ["b", "a!"])
  }

  func testNothingDueShowsTheEmptyMessage() {
    let content = WidgetAgenda.content(
      for: snapshot(tasks: [("later", "2026-11-02")]), today: "2026-10-29", capacity: 3)

    XCTAssertEqual(content, .message(header: "Hoje", text: "Nada para hoje"))
  }

  func testPastTheHorizonIsStale() {
    let data = snapshot(coversUntil: "2026-11-05", tasks: [("a", "2026-10-29")])

    XCTAssertEqual(rows(WidgetAgenda.content(for: data, today: "2026-11-05", capacity: 3)), ["a!"])
    XCTAssertEqual(
      WidgetAgenda.content(for: data, today: "2026-11-06", capacity: 3),
      .message(header: "Hoje", text: "Abra o app para atualizar"))
  }

  func testNewerFormatIsStale() {
    XCTAssertEqual(
      WidgetAgenda.content(for: snapshot(version: 2), today: "2026-10-29", capacity: 3),
      .message(header: "Hoje", text: "Abra o app para atualizar"))
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
