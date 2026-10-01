import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/profile_model.dart';
import 'gateway_api_client.dart';
import 'storage_service.dart';

class ProfileService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  final GatewayApiClient _gatewayClient = GatewayApiClient();

  // 1. Get current user profile as Map (Gateway REST with Supabase Fallback)
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/profile/me',
        queryParams: {'user_id': userId},
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("ProfileService.getProfile Gateway fallback to Supabase: $e");
    }

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  // 2. Get typed ProfileModel
  Future<ProfileModel?> getProfileModel(String userId) async {
    final data = await getProfile(userId);
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  // 3. Check profile completion
  Future<bool> isProfileComplete(String userId) async {
    final profile = await getProfile(userId);
    if (profile == null) return false;
    final phone = profile['phone']?.toString().trim() ?? '';
    final nim = profile['nim']?.toString().trim() ?? '';
    return phone.isNotEmpty && nim.isNotEmpty;
  }

  // 4. Find profile by NIM
  Future<Map<String, dynamic>?> findProfileByNim(String nim) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/profile/search',
        queryParams: {'nim': nim.trim()},
      );
      if (response is Map<String, dynamic>) return response;
    } catch (_) {}

    final response = await _client
        .from('profiles')
        .select()
        .eq('nim', nim.trim())
        .maybeSingle();
    return response;
  }

  // 5. Update Profile Details via PUT /api/v1/profile/me
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? nim,
    String? campusName,
    String? verificationStatus,
    String? avatarUrl,
    String? qrisImageUrl,
    String? ewalletName,
    String? ewalletNumber,
  }) async {
    final Map<String, dynamic> data = {
      'user_id': userId,
      'id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (name != null && name.trim().isNotEmpty) data['name'] = name.trim();
    if (email != null && email.trim().isNotEmpty) data['email'] = email.trim().toLowerCase();
    if (phone != null && phone.trim().isNotEmpty) data['phone'] = phone.trim();
    if (nim != null && nim.trim().isNotEmpty) data['nim'] = nim.trim();
    if (campusName != null && campusName.trim().isNotEmpty) data['campus_name'] = campusName.trim();
    if (verificationStatus != null && verificationStatus.trim().isNotEmpty) {
      data['verification_status'] = verificationStatus.trim();
    }
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty) data['avatar_url'] = avatarUrl.trim();
    if (qrisImageUrl != null && qrisImageUrl.trim().isNotEmpty) data['qris_image_url'] = qrisImageUrl.trim();
    if (ewalletName != null) data['ewallet_name'] = ewalletName.trim();
    if (ewalletNumber != null) data['ewallet_number'] = ewalletNumber.trim();

    try {
      await _gatewayClient.put('/api/v1/profile/me', body: data);
      debugPrint("ProfileService: Profile updated via Golang Gateway for $userId");
      return;
    } catch (e) {
      debugPrint("ProfileService.updateProfile Gateway fallback to Supabase: $e");
    }

    final dbData = Map<String, dynamic>.from(data)..remove('user_id');
    try {
      await _client.from('profiles').update(dbData).eq('id', userId);
      debugPrint("ProfileService: Updated profile via Supabase for $userId");
    } catch (e) {
      debugPrint("ProfileService update error: $e. Attempting upsert fallback...");
      try {
        dbData['id'] = userId;
        await _client.from('profiles').upsert(dbData);
      } catch (err2) {
        debugPrint("ProfileService upsert fallback error: $err2");
      }
    }
  }

  // 6. Sync Google Profile via POST /api/v1/auth/sync-google
  Future<Map<String, dynamic>?> syncGoogleProfile({
    required String id,
    required String email,
    String? name,
    String? avatarUrl,
  }) async {
    final payload = {
      'id': id,
      'user_id': id,
      'email': email.trim().toLowerCase(),
      'name': (name != null && name.trim().isNotEmpty) ? name.trim() : 'Pengguna Mpus',
      'avatar_url': avatarUrl?.trim() ?? '',
    };

    try {
      final response = await _gatewayClient.post(
        '/api/v1/auth/sync-google',
        body: payload,
      );
      debugPrint("ProfileService: Synced Google profile via Gateway for $id");
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("ProfileService.syncGoogleProfile Gateway fallback to Supabase: $e");
    }

    try {
      final res = await _client.from('profiles').upsert({
        'id': id,
        'email': email.trim().toLowerCase(),
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : 'Pengguna Mpus',
        'avatar_url': avatarUrl?.trim() ?? '',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).select().maybeSingle();
      return res;
    } catch (err) {
      debugPrint("ProfileService direct Supabase sync error: $err");
      return null;
    }
  }

  // 7. Submit KTM Verification
  Future<String> submitKtmVerification({
    required String userId,
    required File ktmFile,
    String? studentNim,
    String? campusName,
    bool isAutoVerified = false,
  }) async {
    final ktmUrl = await _storageService.uploadKtmImage(ktmFile, userId);

    await updateProfile(
      userId: userId,
      nim: studentNim,
      campusName: campusName,
      verificationStatus: isAutoVerified ? 'VERIFIED' : 'PENDING_REVIEW',
    );

    return ktmUrl;
  }

  // 8. Update Avatar
  Future<String> updateAvatar(File imageFile, String userId) async {
    final avatarUrl = await _storageService.uploadAvatar(imageFile, userId);
    await updateProfile(userId: userId, avatarUrl: avatarUrl);
    return avatarUrl;
  }

  // 9. Update QRIS Code
  Future<String> updateQrisCode(File imageFile, String userId) async {
    final qrisUrl = await _storageService.uploadQrisCode(imageFile, userId);
    await updateProfile(userId: userId, qrisImageUrl: qrisUrl);
    return qrisUrl;
  }

  // 10. Update FCM Device Token
  Future<void> updateFcmToken(String userId, String fcmToken) async {
    try {
      await _gatewayClient.put(
        '/api/v1/profile/fcm-token',
        body: {'user_id': userId, 'fcm_token': fcmToken.trim()},
      );
      return;
    } catch (_) {}

    await _client.from('profiles').update({
      'fcm_token': fcmToken.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
