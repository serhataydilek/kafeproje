import '../constants/error_codes.dart';
import '../l10n/app_localizations.dart';
import '../models/service_result.dart';

String localizeError(AppErrorCode code, AppLocalizations l10n) {
  return switch (code) {
    AppErrorCode.unknown => l10n.authGenericError,
    AppErrorCode.permissionDenied => l10n.errorPermissionDenied,
    AppErrorCode.requestTimedOut => l10n.errorRequestTimedOut,
    AppErrorCode.networkError => l10n.errorNetworkUnavailable,
    AppErrorCode.dataConflict => l10n.errorDataConflict,
    AppErrorCode.validationFailed => l10n.errorValidationFailed,
    AppErrorCode.recordNotFound => l10n.errorRecordNotFound,
    AppErrorCode.parseFailed => l10n.errorParseFailed,
    AppErrorCode.serviceUnavailable => l10n.errorServiceUnavailable,
    AppErrorCode.authInvalidCredentials => l10n.errorAuthInvalidCredentials,
    AppErrorCode.authRateLimited => l10n.errorAuthRateLimited,
    AppErrorCode.authEmailRegistered => l10n.errorAuthEmailRegistered,
    AppErrorCode.authPasswordResetFailed => l10n.errorAuthPasswordResetFailed,
    AppErrorCode.cafeListFailed => l10n.errorCafeListLoadFailed,
    AppErrorCode.cafeDetailFailed => l10n.errorCafeDetailLoadFailed,
    AppErrorCode.cafeUpdateFailed => l10n.errorCafeUpdateFailed,
    AppErrorCode.cafeAddFailed => l10n.errorCafeAddFailed,
    AppErrorCode.cafeNameRequired => l10n.errorCafeNameRequired,
    AppErrorCode.cafeNameInvalid => l10n.errorCafeNameInvalid,
    AppErrorCode.neighborhoodInvalid => l10n.errorNeighborhoodInvalid,
    AppErrorCode.addressInvalid => l10n.errorAddressInvalid,
    AppErrorCode.descriptionInvalid => l10n.errorDescriptionInvalid,
    AppErrorCode.profileListFailed => l10n.errorUserListLoadFailed,
    AppErrorCode.roleChangeFailed => l10n.errorRoleChangeFailedNoPermissions,
    AppErrorCode.usernameInvalid => l10n.errorUsernameInvalid,
    AppErrorCode.usernameTaken => l10n.errorUsernameTaken,
    AppErrorCode.profileUpdateFailed => l10n.errorProfileUpdateFailed,
    AppErrorCode.avatarEmpty => l10n.errorAvatarEmpty,
    AppErrorCode.avatarUploadFailed => l10n.errorAvatarUploadFailed,
    AppErrorCode.profileLoadFailed => l10n.errorProfileLoadFailed,
    AppErrorCode.reviewLoadFailed => l10n.reviewsLoadError,
    AppErrorCode.reviewSubmitFailed => l10n.errorReviewSubmitFailed,
    AppErrorCode.reviewDeleteFailed => l10n.reviewsDeleteError,
    AppErrorCode.reviewAuthRequired => l10n.reviewsAuthRequired,
    AppErrorCode.ratingOutOfRange => l10n.errorReviewRatingOutOfRange,
    AppErrorCode.reviewProfanityBlocked => l10n.errorReviewProfanityBlocked,
    AppErrorCode.reviewTextTooLong => l10n.errorReviewTextTooLong,
    AppErrorCode.reviewDuplicateText => l10n.errorReviewDuplicateText,
    AppErrorCode.reviewSubmissionRateLimited =>
      l10n.errorReviewSubmissionRateLimited,
    AppErrorCode.notReviewOwner => l10n.errorReviewNotOwner,
    AppErrorCode.reviewProfileMissing => l10n.errorReviewProfileMissing,
    AppErrorCode.reviewFieldMissing => l10n.errorReviewFieldMissing,
  };
}

String localizeServiceMessage<T>(
  ServiceResult<T> result,
  AppLocalizations l10n, {
  String? fallback,
}) {
  final errorCode = result.errorCode;
  if (errorCode != null) {
    return localizeError(errorCode, l10n);
  }

  final message = result.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }

  return fallback ?? l10n.authGenericError;
}
