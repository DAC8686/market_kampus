import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/profile_model.dart';
import 'storage_service.dart';

class ProfileService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();

  // Get current user profile as Map
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return response;
  }

  // Get current user profile as typed ProfileModel
  Future<ProfileModel?> getProfileModel(String userId) async {
    final data = await getProfile(userId);
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  // Check if profile is complete with phone and KTM
  Future<bool> isProfileComplete(String userId) async {
    final profile = await getProfile(userId);
    if (profile == null) return false;
    final phone = profile['phone']?.toString().trim() ?? '';
    final ktmUrl = profile['ktm_image_url']?.toString().trim() ?? '';
    final isVerified = profile['is_ktm_verified'] == true;
    return phone.isNotEmpty && (ktmUrl.isNotEmpty || isVerified);
  }

  // Update profile details
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? nim,
    String? campusName,
    String? ewalletName,
    String? ewalletNumber,
  }) async {
    Map<String, dynamic> updates = {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (name != null) updates['name'] = name.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (nim != null) updates['nim'] = nim.trim();
    if (campusName != null) updates['campus_name'] = campusName.trim();
    if (ewalletName != null) updates['ewallet_name'] = ewalletName.trim();
    if (ewalletNumber != null) updates['ewallet_number'] = ewalletNumber.trim();

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  // Upload and submit KTM verification
  Future<String> submitKtmVerification({
    required String userId,
    required File ktmFile,
    String? studentNim,
    String? campusName,
    bool isAutoVerified = false,
  }) async {
    final ktmUrl = await _storageService.uploadKtmImage(ktmFile, userId);

    Map<String, dynamic> updates = {
      'ktm_image_url': ktmUrl,
      'is_ktm_verified': isAutoVerified,
      'verification_status': isAutoVerified ? 'VERIFIED' : 'PENDING_REVIEW',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (studentNim != null && studentNim.trim().isNotEmpty) {
      updates['nim'] = studentNim.trim();
    }
    if (campusName != null && campusName.trim().isNotEmpty) {
      updates['campus_name'] = campusName.trim();
    }

    await _client.from('profiles').update(updates).eq('id', userId);
    return ktmUrl;
  }

  // Upload and update Avatar
  Future<String> updateAvatar(File imageFile, String userId) async {
    final avatarUrl = await _storageService.uploadAvatar(imageFile, userId);
    await _client.from('profiles').update({
      'avatar_url': avatarUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    return avatarUrl;
  }

  // Upload and update Seller QRIS
  Future<String> updateQrisCode(File imageFile, String userId) async {
    final qrisUrl = await _storageService.uploadQrisCode(imageFile, userId);
    await _client.from('profiles').update({
      'qris_image_url': qrisUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    return qrisUrl;
  }

  // Update FCM device token for push notification
  Future<void> updateFcmToken(String userId, String fcmToken) async {
    await _client.from('profiles').update({
      'fcm_token': fcmToken.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
