import 'package:equatable/equatable.dart';
import 'package:todo/core/error/failure.dart';

final class Credentials extends Equatable {
  const Credentials({required this.email, required this.password});

  final String email;
  final String password;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String email) =>
      _emailPattern.hasMatch(email.trim());

  /// Returns these credentials with the email trimmed, or throws an
  /// [AuthFailure] when they cannot be sent to the provider.
  Credentials validated() {
    final trimmedEmail = email.trim();
    if (!isValidEmail(trimmedEmail)) {
      throw const AuthFailure(AuthFailureReason.invalidEmail);
    }
    if (password.isEmpty) {
      throw const AuthFailure(AuthFailureReason.missingPassword);
    }
    return Credentials(email: trimmedEmail, password: password);
  }

  @override
  List<Object> get props => [email, password];

  @override
  String toString() => 'Credentials($email)';
}
