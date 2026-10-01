class ProductModel {
  final String id;
  final String sellerId;
  final String name;
  final double price;
  final String description;
  final List<String> images;
  final String category;
  final String condition;
  final bool isSold;
  final bool isCodAvailable;
  final bool isQrisAvailable;
  final DateTime? createdAt;
  final Map<String, dynamic>? sellerProfile;

  ProductModel({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.price,
    this.description = '',
    this.images = const [],
    this.category = 'Lainnya',
    this.condition = 'Bekas - Mulus',
    this.isSold = false,
    this.isCodAvailable = true,
    this.isQrisAvailable = true,
    this.createdAt,
    this.sellerProfile,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    double parsedPrice = 0.0;
    if (json['price'] is num) {
      parsedPrice = (json['price'] as num).toDouble();
    } else if (json['price'] is String) {
      parsedPrice = double.tryParse(json['price'].toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }

    List<String> parsedImages = [];
    if (json['images'] is List) {
      parsedImages = List<String>.from(json['images'].map((x) => x.toString()));
    } else if (json['images'] is String && json['images'].isNotEmpty) {
      parsedImages = [json['images'].toString()];
    }

    return ProductModel(
      id: json['id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? json['sellerId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Tanpa Nama',
      price: parsedPrice,
      description: json['description']?.toString() ?? '',
      images: parsedImages,
      category: json['category']?.toString() ?? 'Lainnya',
      condition: json['condition']?.toString() ?? 'Bekas - Mulus',
      isSold: json['is_sold'] == true,
      isCodAvailable: json['is_cod_available'] ?? true,
      isQrisAvailable: json['is_qris_available'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      sellerProfile: json['profiles'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seller_id': sellerId,
      'name': name,
      'price': price,
      'description': description,
      'images': images,
      'category': category,
      'condition': condition,
      'is_sold': isSold,
      'is_cod_available': isCodAvailable,
      'is_qris_available': isQrisAvailable,
    };
  }
}
