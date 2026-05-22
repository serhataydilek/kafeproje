import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/env.dart';
import '../constants/error_codes.dart';
import '../l10n/l10n.dart';
import '../models/index.dart';
import '../models/service_result.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/form_state_mixin.dart';
import '../utils/input_validation.dart';
import '../utils/localized_error.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> with FormStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final _usernameCtrl = useTextController();
  late final _firstNameCtrl = useTextController();
  late final _lastNameCtrl = useTextController();
  late final _emailCtrl = useTextController();
  late final _passwordCtrl = useTextController();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  String _info = '';
  int _secondsLeft = 0;
  Timer? _retryTimer;

  bool get _isIdentifierValid {
    final value = _emailCtrl.text.trim();
    if (value.isEmpty) {
      return false;
    }
    return _isSignUp ? isValidEmail(value) : true;
  }

  bool get _isPasswordValid {
    return _passwordCtrl.text.trim().length >= kPasswordMinLength;
  }

  bool get _isSignUpFieldsValid {
    final username = _usernameCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    return username.isNotEmpty &&
        username.length >= kUsernameMinLength &&
        username.length <= kUsernameMaxLength &&
        isValidUsername(username) &&
        firstName.isNotEmpty &&
        lastName.isNotEmpty;
  }

  bool get _canSubmit {
    if (isSubmitting || _secondsLeft > 0) {
      return false;
    }

    if (!_isIdentifierValid || !_isPasswordValid) {
      return false;
    }

    return !_isSignUp || _isSignUpFieldsValid;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<CurrentUser?>(currentUserProvider, (_, next) {
      if (next != null && mounted) {
        _goAfterAuth();
      }
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _startRetryTimer() {
    _secondsLeft = 60;
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _setAuthMode(bool signUp) {
    setState(() {
      _isSignUp = signUp;
      setFormError(null);
      _info = '';
      _obscurePassword = true;
      _passwordCtrl.clear();
    });
  }

  void _goAfterAuth() {
    final target = GoRouterState.of(context).queryParameters['from'];
    if (target != null && target.isNotEmpty && target != '/auth') {
      context.go(target);
      return;
    }
    context.go('/');
  }

  Future<void> _submit() async {
    final l10n = context.l10n;

    if (_secondsLeft > 0) {
      setFormError(l10n.authTooManyAttempts(_secondsLeft));
      setState(() => _info = '');
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() => _info = '');

    await submitWithLoading(() async {
      final notifier = ref.read(appShellProvider.notifier);
      final result = _isSignUp
          ? await notifier.signUp(
              _usernameCtrl.text,
              _firstNameCtrl.text,
              _lastNameCtrl.text,
              _emailCtrl.text,
              _passwordCtrl.text,
            )
          : await notifier.signIn(_emailCtrl.text, _passwordCtrl.text);

      if (!result.ok) {
        setFormError(_authFailureMessage(result));
        if (result.errorCode == AppErrorCode.authRateLimited) {
          _startRetryTimer();
        }
        return;
      }

      if (_isSignUp) {
        if (mounted) {
          setState(() {
            _info = l10n.authSignUpSuccess;
            _isSignUp = false;
            _passwordCtrl.clear();
            _obscurePassword = true;
          });
        }
        return;
      }

      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null && mounted) {
        _goAfterAuth();
      }
    });
  }

  Future<void> _sendPasswordReset() async {
    final l10n = context.l10n;
    final email = _emailCtrl.text.trim();

    if (email.isEmpty || !looksLikeEmail(email) || !isValidEmail(email)) {
      setFormError(l10n.authResetNeedsEmail);
      setState(() => _info = '');
      return;
    }

    setState(() => _info = '');

    await submitWithLoading(() async {
      final result =
          await ref.read(appShellProvider.notifier).resetPassword(email);
      if (!result.ok) {
        setFormError(_authFailureMessage(result));
        return;
      }

      if (mounted) {
        setState(() => _info = l10n.authResetPasswordSent);
      }
    });
  }

  String? _validateEmailOrUsername(String? value) {
    final l10n = context.l10n;
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return _isSignUp ? l10n.authEmailRequired : l10n.authIdentifierRequired;
    }
    if (_isSignUp && !isValidEmail(text)) {
      return l10n.profileEditEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final l10n = context.l10n;
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return l10n.authPasswordRequired;
    }
    if (text.length < kPasswordMinLength) {
      return l10n.authPasswordTooShort;
    }
    return null;
  }

  String _authFailureMessage(ServiceResult<void> result) {
    if (kDebugMode &&
        !Env.hasSupabaseConfig &&
        result.errorCode == AppErrorCode.serviceUnavailable) {
      return 'Supabase config missing. Add .env locally or run with --dart-define-from-file=.env.local.json';
    }
    return localizeServiceMessage(
      result,
      context.l10n,
      fallback: context.l10n.authGenericError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final title = _isSignUp ? l10n.authSignUpTitle : l10n.authWelcome;
    final subtitle =
        _isSignUp ? l10n.authSignUpSubtitle : l10n.authSignInSubtitle;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 380 || size.height < 700;
    final cardPadding = isCompact ? AppSpacing.md : AppSpacing.lg;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: FocusTraversalGroup(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                right: -40,
                child: _AuthGlow(
                  color: colors.primary.withValues(alpha: 0.18),
                  size: 220,
                ),
              ),
              Positioned(
                top: 120,
                left: -70,
                child: _AuthGlow(
                  color: colors.accent.withValues(alpha: 0.12),
                  size: 180,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: isCompact ? AppSpacing.sm : AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.card.withValues(alpha: 0.97),
                            colors.card.withValues(alpha: 0.94),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg + 8),
                        border: Border.all(color: colors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.09),
                            blurRadius: 34,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _AuthModeTabs(
                                  colors: colors,
                                  isSignUp: _isSignUp,
                                  onChanged: isSubmitting ? null : _setAuthMode,
                                  signInLabel: l10n.authSignIn,
                                  signUpLabel: l10n.authSignUp,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Row(
                                  children: [
                                    Container(
                                      width: isCompact ? 38 : 46,
                                      height: isCompact ? 38 : 46,
                                      decoration: BoxDecoration(
                                        color: colors.primarySoft,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: colors.primary
                                              .withValues(alpha: 0.16),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.local_cafe_rounded,
                                        color: colors.primary,
                                        size: isCompact ? 19 : 23,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Text(
                                        context.l10n.appTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height:
                                      isCompact ? AppSpacing.sm : AppSpacing.md,
                                ),
                                Text(
                                  title,
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: isCompact ? 26 : 31,
                                    fontWeight: FontWeight.w800,
                                    height: 1.08,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: colors.mutedText,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md + 4),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child: _isSignUp
                                      ? Column(
                                          key: const ValueKey(
                                              'auth-sign-up-fields'),
                                          children: [
                                            _AuthField(
                                              controller: _usernameCtrl,
                                              label: l10n.authUsername,
                                              prefixIcon:
                                                  Icons.person_outline_rounded,
                                              textInputAction:
                                                  TextInputAction.next,
                                              textCapitalization:
                                                  TextCapitalization.none,
                                              autofillHints: const [
                                                AutofillHints.username,
                                              ],
                                              onChanged: (_) => setState(() {}),
                                              validator: (value) {
                                                final text =
                                                    value?.trim() ?? '';
                                                if (text.isEmpty) {
                                                  return l10n
                                                      .profileEditUsernameRequired;
                                                }
                                                if (text.length < kUsernameMinLength ||
                                                    text.length >
                                                        kUsernameMaxLength ||
                                                    !isValidUsername(text)) {
                                                  return l10n
                                                      .profileEditUsernameInvalid;
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(
                                                height: AppSpacing.md),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _AuthField(
                                                    controller: _firstNameCtrl,
                                                    label: l10n.authFirstName,
                                                    prefixIcon: Icons
                                                        .person_outline_rounded,
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                    validator: (value) {
                                                      if ((value?.trim() ?? '')
                                                          .isEmpty) {
                                                        return l10n
                                                            .profileEditFirstNameRequired;
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: AppSpacing.md),
                                                Expanded(
                                                  child: _AuthField(
                                                    controller: _lastNameCtrl,
                                                    label: l10n.authLastName,
                                                    prefixIcon:
                                                        Icons.badge_outlined,
                                                    textInputAction:
                                                        TextInputAction.next,
                                                    onChanged: (_) =>
                                                        setState(() {}),
                                                    validator: (value) {
                                                      if ((value?.trim() ?? '')
                                                          .isEmpty) {
                                                        return l10n
                                                            .profileEditLastNameRequired;
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                                height: AppSpacing.md),
                                          ],
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey('auth-sign-in-fields'),
                                        ),
                                ),
                                _AuthField(
                                  controller: _emailCtrl,
                                  label: _isSignUp
                                      ? l10n.authEmail
                                      : l10n.authEmailOrUsername,
                                  prefixIcon: Icons.alternate_email_rounded,
                                  keyboardType: _isSignUp
                                      ? TextInputType.emailAddress
                                      : TextInputType.text,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.none,
                                  autofillHints: _isSignUp
                                      ? const [AutofillHints.email]
                                      : const [
                                          AutofillHints.email,
                                          AutofillHints.username,
                                        ],
                                  onChanged: (_) => setState(() {}),
                                  validator: _validateEmailOrUsername,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _AuthField(
                                  controller: _passwordCtrl,
                                  label: l10n.authPassword,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  validator: _validatePassword,
                                  onChanged: (_) => setState(() {}),
                                  onFieldSubmitted: (_) => _submit(),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    tooltip: _obscurePassword
                                        ? l10n.authShowPassword
                                        : l10n.authHidePassword,
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                if (!_isSignUp) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: isSubmitting
                                          ? null
                                          : _sendPasswordReset,
                                      child: Text(l10n.authForgotPassword),
                                    ),
                                  ),
                                ],
                                if (formError != null || _info.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  _AuthMessageBanner(
                                    color: formError != null
                                        ? colors.danger
                                        : colors.primary,
                                    background: formError != null
                                        ? colors.danger.withValues(alpha: 0.09)
                                        : colors.primarySoft,
                                    message: formError ?? _info,
                                  ),
                                ],
                                const SizedBox(height: AppSpacing.md + 4),
                                FilledButton(
                                  onPressed: _canSubmit ? _submit : null,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(54),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                    ),
                                  ),
                                  child: isSubmitting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            semanticsLabel: l10n.commonLoading,
                                            strokeWidth: 2,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        )
                                      : Text(
                                          _secondsLeft > 0
                                              ? l10n.authRetryIn(_secondsLeft)
                                              : (_isSignUp
                                                  ? l10n.authSignUp
                                                  : l10n.authSignIn),
                                        ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextButton(
                                  onPressed: isSubmitting
                                      ? null
                                      : () => _setAuthMode(!_isSignUp),
                                  child: Text(
                                    _isSignUp
                                        ? l10n.authHasAccount
                                        : l10n.authCreateAccount,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                MergeSemantics(
                                  child: Semantics(
                                    label:
                                        '${l10n.commonTheme}: ${l10n.authDarkMode}',
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          l10n.authDarkMode,
                                          style: TextStyle(
                                            color: colors.mutedText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: themeMode == AppThemeMode.dark,
                                          onChanged: isSubmitting
                                              ? null
                                              : (_) => ref
                                                  .read(
                                                      appShellProvider.notifier)
                                                  .toggleThemeMode(),
                                        ),
                                      ],
                                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeTabs extends StatelessWidget {
  const _AuthModeTabs({
    required this.colors,
    required this.isSignUp,
    required this.onChanged,
    required this.signInLabel,
    required this.signUpLabel,
  });

  final AppColors colors;
  final bool isSignUp;
  final ValueChanged<bool>? onChanged;
  final String signInLabel;
  final String signUpLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.chip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _AuthModeButton(
                label: signInLabel,
                active: !isSignUp,
                colors: colors,
                onTap: onChanged == null ? null : () => onChanged!(false),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _AuthModeButton(
                label: signUpLabel,
                active: isSignUp,
                colors: colors,
                onTap: onChanged == null ? null : () => onChanged!(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  const _AuthModeButton({
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool active;
  final AppColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? onColor(colors.primary) : colors.text;

    return Material(
      color: active ? colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.words,
    this.onFieldSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autocorrect: false,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 20,
              ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surface.withValues(alpha: 0.92),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 6,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.78),
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Reusable auth text field. The parent widget owns the controller lifecycle.
class _AuthMessageBanner extends StatelessWidget {
  const _AuthMessageBanner({
    required this.color,
    required this.background,
    required this.message,
  });

  final Color color;
  final Color background;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: message,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            message,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({
    required this.color,
    required this.size,
  });

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
