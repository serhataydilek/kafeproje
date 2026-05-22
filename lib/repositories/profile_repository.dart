import '../models/index.dart';
import '../services/supabase_service.dart';

/// Remote profile data access only.
///
/// This repository does not hold UI state; `profileProvider` and
/// `appShellProvider` project profile/session data into the widget layer.
class ProfileRepository {
  const ProfileRepository(this._service);

  final ProfilesService? _service;

  bool get isRemoteEnabled => _service != null;

  Future<UserProfile?> fetchCurrentProfile(String userId) async {
    final service = _service;
    if (service == null) {
      return null;
    }

    final result = await service.fetchProfileById(userId);
    return result.data;
  }
}
