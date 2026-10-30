import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:todo/core/ui/widgets/brand_background.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/core/ui/widgets/task_stack_illustration.dart';
import 'package:todo/features/auth/domain/entities/credentials.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/auth/presentation/widgets/auth_failure_message.dart';
import 'package:todo/l10n/app_localizations.dart';

/// Sign in and sign up on one screen, switched by a link below the form.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bloc = context.read<AuthBloc>();
    bloc.add(
      _isSignUp
          ? AuthSignUpRequested(email: _email.text, password: _password.text)
          : AuthSignInRequested(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = _isSignUp ? l10n.authSignUpTitle : l10n.authSignInTitle;
    final theme = Theme.of(context);

    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) => Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: TaskStackIllustration(),
                          ),
                          const SizedBox(height: 28),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.appTitle,
                              style: theme.textTheme.headlineLarge,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            key: const Key('auth-email'),
                            controller: _email,
                            decoration: InputDecoration(
                              labelText: l10n.authEmailLabel,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            enabled: !state.isSubmitting,
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.isEmpty) return l10n.authEmailRequired;
                              if (!Credentials.isValidEmail(email)) {
                                return l10n.authEmailInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('auth-password'),
                            controller: _password,
                            decoration: InputDecoration(
                              labelText: l10n.authPasswordLabel,
                              suffixIcon: _PasswordVisibilityButton(
                                isObscured: _obscurePassword,
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            autofillHints: [
                              _isSignUp
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: TextInputAction.done,
                            enabled: !state.isSubmitting,
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) => (value ?? '').isEmpty
                                ? l10n.authPasswordRequired
                                : null,
                          ),
                          if (state.failure case final failure?) ...[
                            const SizedBox(height: 16),
                            _AuthError(
                              message: authFailureMessage(l10n, failure),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _SubmitButton(
                            label: _isSignUp
                                ? l10n.authSignUpButton
                                : l10n.authSignInButton,
                            isSubmitting: state.isSubmitting,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: state.isSubmitting
                                ? null
                                : () => setState(() => _isSignUp = !_isSignUp),
                            child: Text(
                              _isSignUp
                                  ? l10n.authSwitchToSignIn
                                  : l10n.authSwitchToSignUp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.isObscured,
    required this.onPressed,
  });

  final bool isObscured;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('auth-password-visibility'),
      tooltip: isObscured ? l10n.authShowPassword : l10n.authHidePassword,
      icon: Icon(
        isObscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
      onPressed: onPressed,
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: colors.onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String label;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BrandButton(
      onPressed: isSubmitting ? null : onPressed,
      child: isSubmitting
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                semanticsLabel: AppLocalizations.of(context).loadingLabel,
              ),
            )
          : Text(label),
    );
  }
}
