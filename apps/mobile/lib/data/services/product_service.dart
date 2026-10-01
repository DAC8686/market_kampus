import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/product_model.dart';
import 'storage_service.dart';

class ProductService {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();

  // Fetch all active products with seller profile details (raw Map list)
  Future<List<Map<String, dynamic>>> getProducts({
    String? category,
    String? searchQuery,
    String sortBy = 'created_at',
    bool ascending = false,
  }) async {
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

  // Fetch all active products typed as ProductModel list
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

  // Fetch seller's own products
  Future<List<Map<String, dynamic>>> getMyProducts(String sellerId) async {
    final response = await _client
        .from('products')
        .select()
        .eq('seller_id', sellerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Add a new product with images
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

    // Upload images to Supabase Storage
    for (var file in imageFiles) {
      final url = await _storageService.uploadProductImage(file, sellerId);
      imageUrls.add(url);
    }

    final response = await _client.from('products').insert({
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
    }).select().single();

    return response;
  }

  // Update existing product
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

    await _client.from('products').update(updateData).eq('id', productId);
  }

  // Delete product
  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  // Mark product as Sold
  Future<void> toggleProductSold(String productId, bool isSold) async {
    await _client.from('products').update({
      'is_sold': isSold,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', productId);
  }
}
