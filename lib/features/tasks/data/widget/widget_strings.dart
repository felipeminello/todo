import 'package:equatable/equatable.dart';

/// Texts shown inside the home screen widget, already localized by the app
/// so the ARB file stays their only source.
final class WidgetStrings extends Equatable {
  const WidgetStrings({
    required this.header,
    required this.empty,
    required this.stale,
    required this.signedOut,
    required this.overdue,
  });

  final String header;
  final String empty;
  final String stale;
  final String signedOut;

  /// Spoken before an overdue task's title by screen readers.
  final String overdue;

  Map<String, String> toJson() => {
    'header': header,
    'empty': empty,
    'stale': stale,
    'signedOut': signedOut,
    'overdue': overdue,
  };

  @override
  List<Object> get props => [header, empty, stale, signedOut, overdue];
}
