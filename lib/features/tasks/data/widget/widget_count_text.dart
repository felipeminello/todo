import 'package:equatable/equatable.dart';

/// A text with a count that only the native widget knows, since the count
/// depends on its current day and on how many rows fit.
final class WidgetCountText extends Equatable {
  const WidgetCountText({required this.one, required this.other});

  /// Replaced by the number in [other]; the native widgets look for it.
  static const countToken = '{count}';

  final String one;
  final String other;

  Map<String, String> toJson() => {'one': one, 'other': other};

  @override
  List<Object> get props => [one, other];
}
