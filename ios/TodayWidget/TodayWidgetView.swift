import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
  let entry: TodayEntry
  @Environment(\.widgetFamily) private var family

  /// Rows that fit with the header, at the default text size.
  private var capacity: Int {
    switch family {
    case .systemLarge: return 8
    default: return 3
    }
  }

  private var content: WidgetContent {
    WidgetAgenda.content(
      for: entry.snapshot,
      today: WidgetAgenda.isoDay(of: entry.date, calendar: .autoupdatingCurrent),
      capacity: capacity
    )
  }

  var body: some View {
    Group {
      switch content {
      case .appIcon:
        Image("AppLogo")
          .resizable()
          .scaledToFit()
          .frame(maxWidth: 64, maxHeight: 64)
          .accessibilityHidden(true)
      case .signedOut(let text):
        Text(text)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      case .message(let header, let text):
        TodayLayout(header: header) {
          Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
      case .tasks(let header, let overdue, let pending, let rows):
        TodayLayout(header: header) {
          // Oldest at the top, most recent at the bottom.
          if let overdue {
            OverdueGroupView(text: overdue)
          }
          if let pending {
            Text(pending)
              .font(.subheadline)
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          ForEach(rows.reversed(), id: \.id) { row in
            Text(row.title)
              .font(.subheadline)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }
      }
    }
    .widgetBackground()
  }
}

/// Header at the top and the content anchored to the bottom edge.
private struct TodayLayout<Content: View>: View {
  let header: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(header)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      Spacer(minLength: 0)
      content
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

private struct OverdueGroupView: View {
  let text: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "exclamationmark.circle")
        .font(.caption)
        .accessibilityHidden(true)
      Text(text)
        .font(.subheadline)
        .lineLimit(1)
    }
    .foregroundColor(Color("OverdueColor"))
  }
}

extension View {
  /// The system background in light and dark, against which the overdue
  /// orange keeps 4.5:1.
  @ViewBuilder
  fileprivate func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      containerBackground(for: .widget) { Color(UIColor.systemBackground) }
    } else {
      padding().background(Color(UIColor.systemBackground))
    }
  }
}
