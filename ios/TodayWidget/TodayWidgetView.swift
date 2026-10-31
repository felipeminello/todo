import SwiftUI
import WidgetKit

struct TodayWidgetView: View {
  let entry: TodayEntry

  /// Fixed line heights that follow Dynamic Type, so the rows that fit can
  /// be counted from the height the system gives the widget.
  @ScaledMetric(relativeTo: .headline) private var headerHeight: CGFloat = 24
  @ScaledMetric(relativeTo: .subheadline) private var rowHeight: CGFloat = 22

  private func content(height: CGFloat) -> WidgetContent {
    WidgetAgenda.content(
      for: entry.snapshot,
      today: WidgetAgenda.isoDay(of: entry.date, calendar: .autoupdatingCurrent),
      capacity: WidgetAgenda.rowsThatFit(
        height: height, headerHeight: headerHeight, rowHeight: rowHeight)
    )
  }

  var body: some View {
    GeometryReader { proxy in
      Group {
        switch content(height: proxy.size.height) {
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
          TodayLayout(header: header, headerHeight: headerHeight) {
            Text(text)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        case .tasks(let header, let overdue, let pending, let rows):
          TodayLayout(header: header, headerHeight: headerHeight) {
            // Oldest at the top, most recent at the bottom.
            if let overdue {
              OverdueGroupView(text: overdue)
                .frame(height: rowHeight)
            }
            if let pending {
              Text(pending)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(height: rowHeight)
            }
            ForEach(rows.reversed(), id: \.id) { row in
              Text(row.title)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(height: rowHeight)
            }
          }
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .widgetBackground()
  }
}

/// Header at the top and the content anchored to the bottom edge.
private struct TodayLayout<Content: View>: View {
  let header: String
  let headerHeight: CGFloat
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(header)
        .font(.headline)
        .lineLimit(1)
        .frame(height: headerHeight, alignment: .topLeading)
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
