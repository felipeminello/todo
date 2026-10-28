import 'package:todo/core/error/failure.dart';
import 'package:todo/l10n/app_localizations.dart';

String authFailureMessage(AppLocalizations l10n, AuthFailureReason reason) {
  return switch (reason) {
    AuthFailureReason.invalidCredentials => l10n.authErrorInvalidCredentials,
    AuthFailureReason.emailAlreadyInUse => l10n.authErrorEmailInUse,
    AuthFailureReason.weakPassword => l10n.authErrorWeakPassword,
    AuthFailureReason.invalidEmail => l10n.authErrorInvalidEmail,
    AuthFailureReason.missingPassword => l10n.authPasswordRequired,
    AuthFailureReason.network => l10n.authErrorNetwork,
    AuthFailureReason.unknown => l10n.authErrorUnknown,
  };
}
