import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/supabase_config.dart';
import '../models/order_model.dart';
import 'gateway_api_client.dart';

class OrderService {
  final SupabaseClient _client = SupabaseConfig.client;
  final GatewayApiClient _gatewayClient = GatewayApiClient();

  // 1. Create a new COD/QRIS Order via Gateway -> Supabase Fallback
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
    final payload = {
      'product_id': productId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'payment_method': paymentMethod,
      'status': 'MENUNGGU_KONFIRMASI',
      'cod_location': codLocation.trim(),
      'cod_meeting_time': codMeetingTime.trim(),
      'total_price': totalPrice,
      'notes': notes?.trim() ?? '',
    };

    try {
      final response = await _gatewayClient.post('/api/v1/orders', body: payload);
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("OrderService.createOrder Gateway fallback to Supabase: $e");
    }

    final response = await _client.from('orders').insert(payload).select().single();
    return response;
  }

  // 2. Update existing Order
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

    try {
      await _gatewayClient.put('/api/v1/orders/$orderId', body: updates);
      return;
    } catch (e) {
      debugPrint("OrderService.updateOrder Gateway fallback to Supabase: $e");
    }

    await _client.from('orders').update(updates).eq('id', orderId);
  }

  // 3. Update Order Status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _gatewayClient.patch(
        '/api/v1/orders/$orderId/status',
        body: {'status': status},
      );
      return;
    } catch (e) {
      debugPrint("OrderService.updateOrderStatus Gateway fallback to Supabase: $e");
    }

    await _client.from('orders').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  // 4. Get active order for product
  Future<Map<String, dynamic>?> getActiveOrderForProduct({
    required String productId,
    required String userId,
    required bool isSeller,
  }) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/orders/active',
        queryParams: {
          'product_id': productId,
          'user_id': userId,
          'is_seller': isSeller,
        },
      );
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("OrderService.getActiveOrderForProduct Gateway fallback to Supabase: $e");
    }

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

  // 5. Get single order by ID
  Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final response = await _gatewayClient.get('/api/v1/orders/$orderId');
      if (response is Map<String, dynamic>) {
        return response;
      }
    } catch (e) {
      debugPrint("OrderService.getOrderById Gateway fallback to Supabase: $e");
    }

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

  // 6. Get orders where current user is buyer
  Future<List<Map<String, dynamic>>> getMyPurchases(String buyerId) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/orders/purchases',
        queryParams: {'buyer_id': buyerId},
      );
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (e) {
      debugPrint("OrderService.getMyPurchases Gateway fallback to Supabase: $e");
    }

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

  // 7. Get typed purchases
  Future<List<OrderModel>> getMyPurchaseModels(String buyerId) async {
    final raw = await getMyPurchases(buyerId);
    return raw.map((e) => OrderModel.fromJson(e)).toList();
  }

  // 8. Get orders received by seller
  Future<List<Map<String, dynamic>>> getMyIncomingOrders(String sellerId) async {
    try {
      final response = await _gatewayClient.get(
        '/api/v1/orders/incoming',
        queryParams: {'seller_id': sellerId},
      );
      if (response is List) {
        return List<Map<String, dynamic>>.from(
          response.map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (e) {
      debugPrint("OrderService.getMyIncomingOrders Gateway fallback to Supabase: $e");
    }

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

  // 9. Get typed incoming orders
  Future<List<OrderModel>> getMyIncomingOrderModels(String sellerId) async {
    final raw = await getMyIncomingOrders(sellerId);
    return raw.map((e) => OrderModel.fromJson(e)).toList();
  }

  // 10. Submit Rating & Review
  Future<void> submitReview({
    required String orderId,
    required String productId,
    required String reviewerId,
    required String sellerId,
    required int rating,
    String? comment,
  }) async {
    final payload = {
      'order_id': orderId,
      'product_id': productId,
      'reviewer_id': reviewerId,
      'seller_id': sellerId,
      'rating': rating,
      'comment': comment?.trim() ?? '',
    };

    try {
      await _gatewayClient.post('/api/v1/reviews', body: payload);
      return;
    } catch (e) {
      debugPrint("OrderService.submitReview Gateway fallback to Supabase: $e");
    }

    await _client.from('reviews').insert(payload);
  }

  // 11. Delete order
  Future<void> deleteOrder(String orderId) async {
    try {
      await _gatewayClient.delete('/api/v1/orders/$orderId');
      return;
    } catch (e) {
      debugPrint("OrderService.deleteOrder Gateway fallback to Supabase: $e");
    }
    await _client.from('orders').delete().eq('id', orderId);
  }
}
