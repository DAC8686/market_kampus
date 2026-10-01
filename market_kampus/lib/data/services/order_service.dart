import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/order_model.dart';

class OrderService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Create a new COD/QRIS Order
  Future<Map<String, dynamic>> createOrder({
    required String productId,
    required String buyerId,
    required String sellerId,
    String paymentMethod = 'COD',
    required String codLocation,
    required String codMeetingTime,
    required double totalPrice,
    String? notes,
  }) async {
    final response = await _client.from('orders').insert({
      'product_id': productId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'payment_method': paymentMethod,
      'status': 'MENUNGGU_KONFIRMASI',
      'cod_location': codLocation.trim(),
      'cod_meeting_time': codMeetingTime.trim(),
      'total_price': totalPrice,
      'notes': notes?.trim() ?? '',
    }).select().single();

    return response;
  }

  // Update existing Order
  Future<void> updateOrder({
    required String orderId,
    String? codLocation,
    String? codMeetingTime,
    String? status,
    String? notes,
  }) async {
    Map<String, dynamic> updates = {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (codLocation != null) updates['cod_location'] = codLocation.trim();
    if (codMeetingTime != null) updates['cod_meeting_time'] = codMeetingTime.trim();
    if (status != null) updates['status'] = status;
    if (notes != null) updates['notes'] = notes.trim();

    await _client.from('orders').update(updates).eq('id', orderId);
  }

  // Update Status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _client.from('orders').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  // Get active order for specific product
  Future<Map<String, dynamic>?> getActiveOrderForProduct({
    required String productId,
    required String userId,
    required bool isSeller,
  }) async {
    var query = _client.from('orders').select('''
      id,
      product_id,
      buyer_id,
      seller_id,
      payment_method,
      status,
      cod_location,
      cod_meeting_time,
      total_price,
      notes,
      created_at,
      buyer:buyer_id (
        id,
        name,
        phone,
        avatar_url,
        rating_total,
        rating_count
      ),
      seller:seller_id (
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
    ''').eq('product_id', productId);

    if (isSeller) {
      query = query.eq('seller_id', userId);
    } else {
      query = query.eq('buyer_id', userId);
    }

    final response = await query
        .inFilter('status', ['MENUNGGU_KONFIRMASI', 'DISETUJUI_COD', 'SUDAH_BAYAR_QRIS'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // Get single order with details by Order ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    final response = await _client.from('orders').select('''
      id,
      product_id,
      buyer_id,
      seller_id,
      payment_method,
      status,
      cod_location,
      cod_meeting_time,
      total_price,
      notes,
      created_at,
      product:product_id (
        id,
        name,
        price,
        images,
        category,
        description,
        is_sold
      ),
      buyer:buyer_id (
        id,
        name,
        phone,
        avatar_url,
        rating_total,
        rating_count
      ),
      seller:seller_id (
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
    ''').eq('id', orderId).maybeSingle();

    return response;
  }

  // Get orders where current user is buyer (typed OrderModel)
  Future<List<Map<String, dynamic>>> getMyPurchases(String buyerId) async {
    final response = await _client.from('orders').select('''
      id,
      product_id,
      buyer_id,
      seller_id,
      payment_method,
      status,
      cod_location,
      cod_meeting_time,
      total_price,
      notes,
      created_at,
      product:product_id (
        id,
        name,
        price,
        images,
        category,
        is_sold
      ),
      seller:seller_id (
        id,
        name,
        phone,
        avatar_url
      )
    ''').eq('buyer_id', buyerId).order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get typed purchases
  Future<List<OrderModel>> getMyPurchaseModels(String buyerId) async {
    final raw = await getMyPurchases(buyerId);
    return raw.map((e) => OrderModel.fromJson(e)).toList();
  }

  // Get orders received by seller
  Future<List<Map<String, dynamic>>> getMyIncomingOrders(String sellerId) async {
    final response = await _client.from('orders').select('''
      id,
      product_id,
      buyer_id,
      seller_id,
      payment_method,
      status,
      cod_location,
      cod_meeting_time,
      total_price,
      notes,
      created_at,
      product:product_id (
        id,
        name,
        price,
        images,
        category,
        is_sold
      ),
      buyer:buyer_id (
        id,
        name,
        phone,
        avatar_url
      )
    ''').eq('seller_id', sellerId).order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get typed incoming orders
  Future<List<OrderModel>> getMyIncomingOrderModels(String sellerId) async {
    final raw = await getMyIncomingOrders(sellerId);
    return raw.map((e) => OrderModel.fromJson(e)).toList();
  }

  // Submit Rating & Review
  Future<void> submitReview({
    required String orderId,
    required String productId,
    required String reviewerId,
    required String sellerId,
    required int rating,
    String? comment,
  }) async {
    await _client.from('reviews').insert({
      'order_id': orderId,
      'product_id': productId,
      'reviewer_id': reviewerId,
      'seller_id': sellerId,
      'rating': rating,
      'comment': comment?.trim() ?? '',
    });
  }

  // Delete an order history entry
  Future<void> deleteOrder(String orderId) async {
    await _client.from('orders').delete().eq('id', orderId);
  }
}
