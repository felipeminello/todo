import 'package:equatable/equatable.dart';
import 'package:todo/features/tasks/data/widget/widget_count_text.dart';

/// Texts shown inside the home screen widget, already localized by the app
/// so the ARB file stays their only source.
final class WidgetStrings extends Equatable {
  const WidgetStrings({
    required this.header,
    required this.empty,
    required this.stale,
    required this.signedOut,
    required this.pendingCount,
    required this.overdueCount,
  });

  final String header;
  final String empty;
  final String stale;
  final String signedOut;

  /// Groups the oldest of today's tasks when they do not all fit.
  final WidgetCountText pendingCount;

  /// Groups every overdue task: the widget never lists them one by one.
  final WidgetCountText overdueCount;

  Map<String, Object> toJson() => {
    'header': header,
    'empty': empty,
    'stale': stale,
    'signedOut': signedOut,
    'pendingCount': pendingCount.toJson(),
    'overdueCount': overdueCount.toJson(),
  };

  @override
  List<Object> get props => [
    header,
    empty,
    stale,
    signedOut,
    pendingCount,
    overdueCount,
  ];
}
