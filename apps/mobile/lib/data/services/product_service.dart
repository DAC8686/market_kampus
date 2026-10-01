import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/product_model.dart';
import 'gateway_api_client.dart';
import 'storage_service.dart';

class ProductService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  final GatewayApiClient _gatewayClient = GatewayApiClient();

  // 1. Fetch active products with Gateway REST -> Supabase Fallback
  Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    String? searchQuery,
    String sortBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/products',
        queryParams: {
          if (category != null && category != 'Semua' && category.isNotEmpty) 'category': category,
          if (searchQuery != null && searchQuery.trim().isNotEmpty) 'search': searchQuery.trim(),
          'sort_by': sortBy,
          'ascending': ascending,
        },
      );

      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (e) {
      debugPrint("ProductService.getProducts Gateway fallback to Supabase: $e");
    }

    var query = _client.from('products').select('''
      id,
      seller_id,
      name,
      price,
      description,
      images,
      category,
      condition,
      is_sold,
      is_cod_available,
      is_qris_available,
      created_at,
      profiles:seller_id (
        id,
        name,
        phone,
        avatar_url,
        qris_image_url,
        ewallet_name,
        ewallet_number,
        rating_total,
        rating_count
      )
    ''').eq('is_sold', false);

    if (category != null && category != 'Semua' && category.isNotEmpty) {
      query = query.eq('category', category);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('name', '%${searchQuery.trim()}%');
    }

    final response = await query.order(sortBy, ascending: ascending);
    return List<Map<String, dynamic>>.from(response);
  }

  // 2. Fetch all active products as ProductModel list
  Future<List<ProductModel>> getProductModels({
    String? category,
    String? searchQuery,
    String sortBy = 'created_at',
    bool ascending = false,
  }) async {
    final rawList = await getProducts(
      category: category,
      searchQuery: searchQuery,
      sortBy: sortBy,
      ascending: ascending,
    );
    return rawList.map((e) => ProductModel.fromJson(e)).toList();
  }

  // 3. Fetch seller's own products
  Future<List<Map<String, dynamic>>> getMyProducts(String sellerId) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/products',
        queryParams: {'seller_id': sellerId},
      );
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (e) {
      debugPrint("ProductService.getMyProducts Gateway fallback to Supabase: $e");
    }

    final response = await _client
        .from('products')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // 4. Add new product with images
  Future<Map<String, dynamic>> addProduct({
    required String sellerId,
    required String name,
    required double price,
    required String description,
    required String category,
    String condition = 'Bekas - Mulus',
    bool isCodAvailable = true,
    bool isQrisAvailable = true,
    required List<File> imageFiles,
  }) async {
    List<String> imageUrls = [];
    for (var file in imageFiles) {
      final url = await _storageService.uploadProductImage(file, sellerId);
      imageUrls.add(url);
    }

    final productPayload = {
      'seller_id': sellerId,
      'name': name.trim(),
      'price': price,
      'description': description.trim(),
      'category': category,
      'condition': condition,
      'is_cod_available': isCodAvailable,
      'is_qris_available': isQrisAvailable,
      'images': imageUrls,
      'is_sold': false,
    };

    try {
      final response = await _gatewayClient.post(
        '/api/v1/products',
        body: productPayload,
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("ProductService.addProduct Gateway fallback to Supabase: $e");
    }

    final response = await _client.from('products').insert(productPayload).select().single();
    return response;
  }

  // 5. Update existing product
  Future<void> updateProduct({
    required String productId,
    required String name,
    required double price,
    required String description,
    required String category,
    required List<String> existingImages,
    List<File>? newImageFiles,
    required String sellerId,
    bool? isSold,
  }) async {
    List<String> finalImages = List.from(existingImages);

    if (newImageFiles != null && newImageFiles.isNotEmpty) {
      for (var file in newImageFiles) {
        final url = await _storageService.uploadProductImage(file, sellerId);
        finalImages.add(url);
      }
    }

    Map<String, dynamic> updateData = {
      'name': name.trim(),
      'price': price,
      'description': description.trim(),
      'category': category,
      'images': finalImages,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (isSold != null) {
      updateData['is_sold'] = isSold;
    }

    try {
      await _gatewayClient.put('/api/v1/products/$productId', body: updateData);
      return;
    } catch (e) {
      debugPrint("ProductService.updateProduct Gateway fallback to Supabase: $e");
    }

    await _client.from('products').update(updateData).eq('id', productId);
  }

  // 6. Delete product
  Future<void> deleteProduct(String productId) async {
    try {
      await _gatewayClient.delete('/api/v1/products/$productId');
      return;
    } catch (e) {
      debugPrint("ProductService.deleteProduct Gateway fallback to Supabase: $e");
    }
    await _client.from('products').delete().eq('id', productId);
  }

  // 7. Toggle product sold state
  Future<void> toggleProductSold(String productId, bool isSold) async {
    try {
      await _gatewayClient.patch(
        '/api/v1/products/$productId/status',
        body: {'is_sold': isSold},
      );
      return;
    } catch (e) {
      debugPrint("ProductService.toggleProductSold Gateway fallback to Supabase: $e");
    }

    await _client.from('products').update({
      'is_sold': isSold,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);
  }
}
