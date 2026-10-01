import 'dart:io';
import 'package:flutter/foundation.dart';
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

  // Find profile by NIM
  Future<Map<String, dynamic>?> findProfileByNim(String nim) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('nim', nim.trim())
        .maybeSingle();
    return response;
  }

  // Update profile details
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
    Map<String, dynamic> data = {
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
      await _client.from('profiles').update(data).eq('id', userId);
      debugPrint("ProfileService: Updated profile successfully for $userId");
    } catch (e) {
      debugPrint("ProfileService update error: $e. Attempting upsert fallback...");
      try {
        data['id'] = userId;
        await _client.from('profiles').upsert(data);
      } catch (err2) {
        debugPrint("ProfileService upsert fallback error: $err2");
      }
    }
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
      'verification_status': isAutoVerified ? 'VERIFIED' : 'PENDING_REVIEW',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (studentNim != null && studentNim.trim().isNotEmpty) {
      updates['nim'] = studentNim.trim();
    }
    if (campusName != null && campusName.trim().isNotEmpty) {
      updates['campus_name'] = campusName.trim();
    }

    try {
      await _client.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      debugPrint("submitKtmVerification update error: $e");
    }
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
