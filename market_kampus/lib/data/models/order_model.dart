class OrderModel {
  final String id;
  final String productId;
  final String buyerId;
  final String sellerId;
  final String paymentMethod;
  final String status;
  final String codLocation;
  final String codMeetingTime;
  final double totalPrice;
  final String notes;
  final DateTime? createdAt;
  final Map<String, dynamic>? productData;
  final Map<String, dynamic>? buyerProfile;
  final Map<String, dynamic>? sellerProfile;

  OrderModel({
    required this.id,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    this.paymentMethod = 'COD',
    this.status = 'MENUNGGU_KONFIRMASI',
    this.codLocation = '',
    this.codMeetingTime = '',
    this.totalPrice = 0.0,
    this.notes = '',
    this.createdAt,
    this.productData,
    this.buyerProfile,
    this.sellerProfile,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? 'COD',
      status: json['status']?.toString() ?? 'MENUNGGU_KONFIRMASI',
      codLocation: json['cod_location']?.toString() ?? '',
      codMeetingTime: json['cod_meeting_time']?.toString() ?? '',
      totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      productData: json['product'] as Map<String, dynamic>?,
      buyerProfile: json['buyer'] as Map<String, dynamic>?,
      sellerProfile: json['seller'] as Map<String, dynamic>?,
    );
  }
}
