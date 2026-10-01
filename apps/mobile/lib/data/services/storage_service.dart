import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_constants.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Upload Product Image to 'product-images' bucket
  Future<String> uploadProductImage(File imageFile, String sellerId) async {
    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${sellerId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'products/$fileName';

    await _client.storage.from(AppConstants.productImagesBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl = _client.storage.from(AppConstants.productImagesBucket).getPublicUrl(filePath);
    return publicUrl;
  }

  // Upload Avatar to 'avatars' bucket
  Future<String> uploadAvatar(File imageFile, String userId) async {
    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${userId}_avatar.$fileExt';
    final filePath = 'users/$fileName';

    await _client.storage.from(AppConstants.avatarsBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl = _client.storage.from(AppConstants.avatarsBucket).getPublicUrl(filePath);
    return publicUrl;
  }

  // Upload QRIS Code to 'qris-codes' bucket
  Future<String> uploadQrisCode(File imageFile, String sellerId) async {
    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${sellerId}_qris.$fileExt';
    final filePath = 'sellers/$fileName';

    await _client.storage.from(AppConstants.qrisCodesBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl = _client.storage.from(AppConstants.qrisCodesBucket).getPublicUrl(filePath);
    return publicUrl;
  }

  // Upload KTM Card to 'ktm-documents' bucket
  Future<String> uploadKtmImage(File imageFile, String userId) async {
    final bytes = await imageFile.readAsBytes();
    final fileExt = imageFile.path.split('.').last.toLowerCase();
    final fileName = '${userId}_ktm_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final filePath = 'ktms/$fileName';

    await _client.storage.from(AppConstants.ktmDocumentsBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl = _client.storage.from(AppConstants.ktmDocumentsBucket).getPublicUrl(filePath);
    return publicUrl;
  }
}
