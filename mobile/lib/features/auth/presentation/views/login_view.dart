import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/theme/app_spacing.dart';
import 'package:mobile/app/theme/tally_colors.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/core/widgets/failure_message.dart';
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Login screen: e-mail, password, and the reason when it did not work.
///
/// It creates its own ViewModel, so every visit starts clean (no old error).
class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    required this.createViewModel,
    required this.session,
  });

  final LoginViewModel Function() createViewModel;
  final SessionController session;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final LoginViewModel _viewModel = widget.createViewModel();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _viewModel.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() =>
      _viewModel.submit(email: _email.text, password: _password.text);

  String? _errorText(AppLocalizations l10n) {
    if (_viewModel.missingFields) return l10n.loginMissingFields;
    final failure = _viewModel.failure;
    if (failure == null) return null;
    // On login a 401 means wrong e-mail or password, not an expired session.
    if (failure is UnauthorizedFailure) return l10n.loginWrongCredentials;
    return failureMessage(l10n, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = TallyColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([_viewModel, widget.session]),
          builder: (context, _) {
            final error = _errorText(l10n);
            final busy = _viewModel.busy;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.trending_up_rounded,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          l10n.appName,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.loginTitle,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.loginSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (widget.session.sessionExpired && error == null) ...[
                      _Note(
                        icon: Icons.schedule_rounded,
                        text: l10n.loginSessionExpired,
                        background: colors.warningContainer,
                        foreground: colors.warning,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (error != null) ...[
                      _Note(
                        icon: Icons.warning_amber_rounded,
                        text: error,
                        background: colors.expenseContainer,
                        foreground: colors.expense,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      onChanged: (_) => _viewModel.clearError(),
                      decoration: InputDecoration(labelText: l10n.loginEmail),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onChanged: (_) => _viewModel.clearError(),
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.loginPassword,
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? l10n.loginHidePassword
                              : l10n.loginShowPassword,
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: busy ? null : _submit,
                        child: Text(
                          busy ? l10n.loginSubmitting : l10n.loginSubmit,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.loginAdminNote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A short colored notice (warning or error) above the form.
class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
