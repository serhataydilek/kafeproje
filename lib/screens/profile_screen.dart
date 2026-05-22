import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../models/async_result.dart' as async_result;
import '../models/index.dart';
import '../models/service_result.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/form_state_mixin.dart';
import '../utils/input_validation.dart';
import '../utils/localized_error.dart';
import '../widgets/ui/app_action_button.dart';
import '../widgets/layout/adaptive_layout.dart';
import '../widgets/ui/profile_avatar_card.dart';
import '../widgets/ui/list_tiles.dart';
import '../widgets/ui/state_views.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with FormStateMixin {
  late final _firstNameCtrl = useTextController();
  late final _lastNameCtrl = useTextController();
  late final _usernameCtrl = useTextController();
  late final _emailCtrl = useTextController();

  bool _pickingAvatar = false;
  bool _showValidation = false;
  String? _success;
  String? _lastHydratedUserId;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarExtension;
  bool _removeAvatarOnSave = false;
  bool _isEditingMode = false;

  void _hydrateFromUser(CurrentUser user) {
    if (_lastHydratedUserId == user.id) {
      return;
    }

    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _usernameCtrl.text = user.username ?? '';
    _emailCtrl.text = user.email;
    _lastHydratedUserId = user.id;
    _pendingAvatarBytes = null;
    _pendingAvatarExtension = null;
    _removeAvatarOnSave = false;
  }

  String? _validate(AppLocalizations l10n) {
    if (_firstNameCtrl.text.trim().isEmpty) {
      return l10n.profileEditFirstNameRequired;
    }
    if (_lastNameCtrl.text.trim().isEmpty) {
      return l10n.profileEditLastNameRequired;
    }
    if (_usernameCtrl.text.trim().isEmpty) {
      return l10n.profileEditUsernameRequired;
    }
    if (!isValidUsername(_usernameCtrl.text)) {
      return l10n.profileEditUsernameInvalid;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      return l10n.profileEditEmailRequired;
    }
    if (!isValidEmail(_emailCtrl.text)) {
      return l10n.profileEditEmailInvalid;
    }
    return null;
  }

  String? _fieldError(
    AppLocalizations l10n,
    TextEditingController controller,
  ) {
    if (!_showValidation) {
      return null;
    }

    if (identical(controller, _firstNameCtrl) &&
        controller.text.trim().isEmpty) {
      return l10n.profileEditFirstNameRequired;
    }
    if (identical(controller, _lastNameCtrl) &&
        controller.text.trim().isEmpty) {
      return l10n.profileEditLastNameRequired;
    }
    if (identical(controller, _usernameCtrl)) {
      final username = controller.text.trim();
      if (username.isEmpty) {
        return l10n.profileEditUsernameRequired;
      }
      if (!isValidUsername(username)) {
        return l10n.profileEditUsernameInvalid;
      }
    }
    if (identical(controller, _emailCtrl)) {
      final email = controller.text.trim();
      if (email.isEmpty) {
        return l10n.profileEditEmailRequired;
      }
      if (!isValidEmail(email)) {
        return l10n.profileEditEmailInvalid;
      }
    }

    return null;
  }

  Future<void> _save(AppLocalizations l10n) async {
    setState(() {
      _success = null;
      _showValidation = true;
    });

    final validationError = _validate(l10n);
    if (validationError != null) {
      setFormError(validationError);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      return;
    }

    await submitWithLoading(() async {
      final normalizedUsername = normalizeUsername(_usernameCtrl.text);
      final result =
          await ref.read(profileUpdateControllerProvider.notifier).saveProfile(
                ProfileUpdatePayload(
                  firstName: _firstNameCtrl.text.trim(),
                  lastName: _lastNameCtrl.text.trim(),
                  username: normalizedUsername,
                  avatarBytes: _pendingAvatarBytes,
                  avatarExtension: _pendingAvatarExtension,
                  removeAvatar: _removeAvatarOnSave,
                ),
              );

      final queuedOffline =
          result.message == ServiceResultMessages.offlineQueued;
      if (!result.ok && !queuedOffline) {
        setFormError(
          localizeServiceMessage(result, l10n,
              fallback: l10n.errorGenericTitle),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _success =
              queuedOffline ? l10n.profileSyncQueued : l10n.profileEditSuccess;
          _pendingAvatarBytes = null;
          _pendingAvatarExtension = null;
          _removeAvatarOnSave = false;
          _isEditingMode = false;
        });
      }
    });
  }

  void _resetToUser(CurrentUser user) {
    _firstNameCtrl.text = user.firstName ?? '';
    _lastNameCtrl.text = user.lastName ?? '';
    _usernameCtrl.text = user.username ?? '';
    _emailCtrl.text = user.email;
    setState(() {
      _showValidation = false;
      setFormError(null);
      _success = null;
      _pendingAvatarBytes = null;
      _pendingAvatarExtension = null;
      _removeAvatarOnSave = false;
    });
  }

  Future<void> _pickAvatarFromGallery() async {
    setState(() {
      setFormError(null);
      _success = null;
      _pickingAvatar = true;
    });

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (picked == null) {
        if (mounted) {
          setState(() => _pickingAvatar = false);
        }
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarExtension = _extensionForPath(picked.path);
        _removeAvatarOnSave = false;
        _pickingAvatar = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setFormError(
        _isTurkish(context)
            ? 'Fotograf secilemedi. Lutfen tekrar dene.'
            : 'Photo selection failed. Please try again.',
      );
      setState(() {
        _pickingAvatar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final profileUpdateState = ref.watch(profileUpdateControllerProvider);
    final user = ref.watch(currentUserProvider);
    final isAuthReady = ref.watch(isAuthReadyProvider);
    final isSigningOut = ref.watch(isSigningOutProvider);
    final pendingSyncCount = ref.watch(offlinePendingCountProvider);
    final deadLetterCount = ref.watch(offlineDeadLetterCountProvider);
    final colors = resolveColors(
      themeMode,
      MediaQuery.platformBrightnessOf(context),
    );
    final l10n = context.l10n;
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final isSavingProfile =
        profileUpdateState is async_result.AsyncLoading<void>;

    if (!isAuthReady) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: LoadingStateView(
            colors: colors,
            label: l10n.commonLoading,
          ),
        ),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: SignInRequiredStateView(
            colors: colors,
            icon: Icons.person_outline,
            onSignIn: () => context.go('/auth'),
          ),
        ),
      );
    }

    _hydrateFromUser(user);

    final avatarUrl = _removeAvatarOnSave ? null : user.avatarUrl;
    final previewImageProvider =
        _pendingAvatarBytes == null ? null : MemoryImage(_pendingAvatarBytes!);
    final fullNamePreview = [
      _firstNameCtrl.text.trim(),
      _lastNameCtrl.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final displayName =
        fullNamePreview.isEmpty ? (user.name ?? user.email) : fullNamePreview;
    final isFormValid = _validate(l10n) == null;

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: AdaptivePage(
          maxWidth: 860,
          child: ListView(
            padding: EdgeInsets.symmetric(
              vertical:
                  AdaptiveLayoutData.fromWidth(MediaQuery.sizeOf(context).width)
                      .sectionSpacing,
            ),
            children: [
              Center(
                child: Column(
                  children: [
                    ProfileAvatarCard(
                      colors: colors,
                      name: displayName,
                      avatarUrl: avatarUrl,
                      avatarImageProvider: previewImageProvider,
                      subtitle: avatarUrl == null
                          ? (_pendingAvatarBytes != null
                              ? (isTr
                                  ? 'Yeni fotograf secildi. Kaydet dediginde profiline yuklenecek.'
                                  : 'A new photo is ready. Save to upload it to your profile.')
                              : (isTr
                                  ? 'Foto ekleyerek profilini daha kolay taninir hale getir.'
                                  : 'Add a photo to make your profile feel more personal.'))
                          : (_pendingAvatarBytes != null
                              ? (isTr
                                  ? 'Yeni fotograf secildi. Kaydet dediginde profiline yuklenecek.'
                                  : 'A new photo is ready. Save to upload it to your profile.')
                              : null),
                      badge: user.isAdmin
                          ? Container(
                              margin: const EdgeInsets.only(top: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primarySoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: colors.primary),
                              ),
                              child: Text(
                                l10n.profileManagerBadge,
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                      actions: _isEditingMode
                          ? [
                              ProfileAvatarActionChip(
                                colors: colors,
                                icon: Icons.photo_library_outlined,
                                label:
                                    isTr ? 'Fotoğrafı düzenle' : 'Edit photo',
                                onTap: _pickingAvatar
                                    ? null
                                    : _pickAvatarFromGallery,
                              ),
                              ProfileAvatarActionChip(
                                colors: colors,
                                icon: Icons.delete_outline,
                                label:
                                    isTr ? 'Fotoğrafı kaldır' : 'Remove photo',
                                destructive: true,
                                onTap: (avatarUrl == null &&
                                        _pendingAvatarBytes == null)
                                    ? null
                                    : () {
                                        setState(() {
                                          _pendingAvatarBytes = null;
                                          _pendingAvatarExtension = null;
                                          _removeAvatarOnSave = true;
                                          _success = null;
                                        });
                                      },
                              ),
                            ]
                          : [
                              ProfileAvatarActionChip(
                                colors: colors,
                                icon: Icons.manage_accounts_outlined,
                                label: l10n.profileEditTitle,
                                onTap: () {
                                  setState(() {
                                    _isEditingMode = true;
                                    _success = null;
                                    setFormError(null);
                                  });
                                },
                              ),
                            ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.text,
                      ),
                    ),
                    if (_usernameCtrl.text.trim().isNotEmpty)
                      Text(
                        '@${normalizeUsername(_usernameCtrl.text)}',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (pendingSyncCount > 0 || deadLetterCount > 0) ...[
                _FeedbackBanner(
                  colors: colors,
                  icon: deadLetterCount > 0
                      ? Icons.warning_amber_rounded
                      : Icons.sync,
                  message: deadLetterCount > 0
                      ? l10n.profileSyncDeadLetters(deadLetterCount)
                      : l10n.profileSyncPending(pendingSyncCount),
                  accentColor:
                      deadLetterCount > 0 ? colors.danger : colors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_isEditingMode) ...[
                AppSectionTitle(colors: colors, title: l10n.profileEditTitle),
                const SizedBox(height: AppSpacing.sm),
                _SectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isTr
                            ? 'Tum profil duzenlemelerini artik burada yapabilirsin.'
                            : 'You can now manage your entire profile from here.',
                        style: TextStyle(
                          color: colors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTr ? 'Profil fotoğrafı' : 'Profile photo',
                              style: TextStyle(
                                color: colors.text,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              _pendingAvatarBytes != null
                                  ? (isTr
                                      ? 'Önizleme hazır. Kaydettiğinde sıkıştırılmış fotoğraf galeriden yüklenecek.'
                                      : 'Preview ready. Saving will upload the compressed photo from your gallery.')
                                  : avatarUrl != null
                                      ? (isTr
                                          ? 'Mevcut fotoğrafını değiştirebilir veya kaldırabilirsin.'
                                          : 'You can replace or remove your current photo.')
                                      : (isTr
                                          ? 'Galeriden fotoğraf seçerek profilinde hemen önizlemesini görebilirsin.'
                                          : 'Pick a photo from your gallery to preview it before saving.'),
                              style: TextStyle(
                                color: colors.mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickingAvatar
                                        ? null
                                        : _pickAvatarFromGallery,
                                    icon: _pickingAvatar
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colors.primary,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.photo_library_outlined),
                                    label: Text(
                                      isTr
                                          ? 'Galeriden sec'
                                          : 'Choose from gallery',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (avatarUrl == null &&
                                            _pendingAvatarBytes == null)
                                        ? null
                                        : () {
                                            setState(() {
                                              _pendingAvatarBytes = null;
                                              _pendingAvatarExtension = null;
                                              _removeAvatarOnSave = true;
                                              _success = null;
                                            });
                                          },
                                    icon: const Icon(Icons.delete_outline),
                                    label: Text(
                                      isTr
                                          ? 'Fotoğrafı kaldır'
                                          : 'Remove photo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _field(
                        colors,
                        l10n.authFirstName,
                        _firstNameCtrl,
                        errorText: _fieldError(l10n, _firstNameCtrl),
                      ),
                      _field(
                        colors,
                        l10n.authLastName,
                        _lastNameCtrl,
                        errorText: _fieldError(l10n, _lastNameCtrl),
                      ),
                      _field(
                        colors,
                        l10n.authUsername,
                        _usernameCtrl,
                        hint: isTr ? '3-24 karakter' : '3-24 characters',
                        errorText: _fieldError(l10n, _usernameCtrl),
                      ),
                      _field(
                        colors,
                        l10n.authEmail,
                        _emailCtrl,
                        hint: l10n.profileEditEmailHint,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _fieldError(l10n, _emailCtrl),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _FeedbackBanner(
                          colors: colors,
                          icon: Icons.error,
                          message: formError!,
                          accentColor: colors.danger,
                        ),
                      ],
                      if (_success != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _FeedbackBanner(
                          colors: colors,
                          icon: Icons.check_circle,
                          message: _success!,
                          accentColor: colors.accent,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      AppActionButton(
                        label: l10n.commonSave,
                        onPressed:
                            isSubmitting || isSavingProfile || !isFormValid
                                ? null
                                : () => _save(l10n),
                        icon: Icons.save_outlined,
                        isLoading: isSubmitting || isSavingProfile,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppActionButton(
                        label: isTr ? 'İptal' : 'Cancel',
                        onPressed: isSubmitting
                            ? null
                            : () {
                                _resetToUser(user);
                                setState(() => _isEditingMode = false);
                              },
                        variant: AppActionButtonVariant.secondary,
                      ),
                    ],
                  ),
                )
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                AppSectionTitle(
                    colors: colors, title: l10n.profileSectionAccount),
                const SizedBox(height: AppSpacing.sm),
                AppActionTile(
                  icon: Icons.settings,
                  label: l10n.commonSettings,
                  colors: colors,
                  onTap: () => context.push('/settings'),
                ),
                if (user.isAdmin)
                  AppActionTile(
                    icon: Icons.admin_panel_settings,
                    label: l10n.profileAdminPanel,
                    colors: colors,
                    onTap: () => context.push('/admin'),
                  ),
                const SizedBox(height: AppSpacing.md),
                _ProfileInfoCard(
                  user: CurrentUser(
                    id: user.id,
                    email: user.email,
                    name: displayName,
                    username: normalizeUsername(_usernameCtrl.text),
                    firstName: _firstNameCtrl.text.trim(),
                    lastName: _lastNameCtrl.text.trim(),
                    avatarUrl: avatarUrl,
                    isAdmin: user.isAdmin,
                  ),
                  colors: colors,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSigningOut
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(appShellProvider.notifier)
                                  .signOut();
                              if (context.mounted) {
                                context.go('/auth');
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.errorGenericTitle),
                                  ),
                                );
                              }
                            }
                          },
                    icon: isSigningOut
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: colors.danger,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.logout_rounded, size: 19),
                    label: Text(l10n.profileSignOut),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.danger,
                      disabledForegroundColor:
                          colors.danger.withValues(alpha: 0.55),
                      side: BorderSide(
                        color: colors.danger.withValues(alpha: 0.55),
                      ),
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl * 2),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    AppColors colors,
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? errorText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.text,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            autocorrect: false,
            onChanged: (value) {
              setState(() {
                if (_showValidation) {
                  setFormError(null);
                }
                _success = null;
              });
              onChanged?.call(value);
            },
            style: TextStyle(color: colors.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.bg,
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: colors.primary),
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(color: colors.mutedText, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

bool _isTurkish(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'tr';
}

String _extensionForPath(String path) {
  final normalized = path.toLowerCase();
  final dotIndex = normalized.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == normalized.length - 1) {
    return 'jpg';
  }

  final extension = normalized.substring(dotIndex + 1);
  switch (extension) {
    case 'png':
    case 'webp':
    case 'gif':
    case 'jpg':
    case 'jpeg':
      return extension == 'jpeg' ? 'jpg' : extension;
    default:
      return 'jpg';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.colors,
    required this.child,
  });

  final AppColors colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.colors,
    required this.icon,
    required this.message,
    required this.accentColor,
  });

  final AppColors colors;
  final IconData icon;
  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accentColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.user,
    required this.colors,
  });

  final CurrentUser user;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: l10n.profileEmail,
            value: user.email,
            colors: colors,
          ),
          if (user.username != null && user.username!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: l10n.profileUsername,
              value: '@${user.username}',
              colors: colors,
            ),
          ],
          if (user.firstName != null || user.lastName != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: l10n.profileFullName,
              value: [
                user.firstName,
                user.lastName,
              ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.mutedText,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
