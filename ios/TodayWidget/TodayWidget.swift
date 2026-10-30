import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshot?
}

/// One entry now and one per local midnight until the snapshot runs out, so
/// the day changes without the app. WidgetKit's own refresh of `.atEnd`
/// timelines is the periodic safety net; nothing here touches the network.
struct TodayProvider: TimelineProvider {
  func placeholder(in context: Context) -> TodayEntry {
    TodayEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
    completion(TodayEntry(date: Date(), snapshot: WidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetSnapshot.load()
    var entries = [TodayEntry(date: now, snapshot: snapshot)]
    guard let snapshot, snapshot.signedIn, let coversUntil = snapshot.coversUntil else {
      // Only the app can change these states, and it reloads the timeline.
      completion(Timeline(entries: entries, policy: .never))
      return
    }
    for midnight in WidgetAgenda.midnights(
      after: now, through: coversUntil, calendar: .autoupdatingCurrent)
    {
      entries.append(TodayEntry(date: midnight, snapshot: snapshot))
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

@main
struct TodayWidget: Widget {
  /// Must match `HomeWidgetStorage.iOSWidgetKind` in Dart.
  let kind = "TodayWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TodayProvider()) { entry in
      TodayWidgetView(entry: entry)
    }
    .configurationDisplayName("widget.name")
    .description("widget.description")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
