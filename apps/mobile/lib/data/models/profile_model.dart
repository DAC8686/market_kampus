class ProfileModel {
  final String id;
  final String email;
  final String nim;
  final String name;
  final String phone;
  final String avatarUrl;
  final String ktmImageUrl;
  final bool isKtmVerified;
  final String verificationStatus; // 'UNVERIFIED', 'PENDING_REVIEW', 'VERIFIED', 'REJECTED'
  final String qrisImageUrl;
  final String ewalletName;
  final String ewalletNumber;
  final String campusName;
  final String fcmToken;
  final double ratingTotal;
  final int ratingCount;

  ProfileModel({
    required this.id,
    this.email = '',
    this.nim = '',
    this.name = 'Pengguna Mpus',
    this.phone = '',
    this.avatarUrl = '',
    this.ktmImageUrl = '',
    this.isKtmVerified = false,
    this.verificationStatus = 'UNVERIFIED',
    this.qrisImageUrl = '',
    this.ewalletName = 'DANA / GoPay / OVO',
    this.ewalletNumber = '',
    this.campusName = 'Kampus',
    this.fcmToken = '',
    this.ratingTotal = 0.0,
    this.ratingCount = 0,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      nim: json['nim']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pengguna Mpus',
      phone: json['phone']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString() ?? '',
      ktmImageUrl: json['ktm_image_url']?.toString() ?? '',
      isKtmVerified: json['is_ktm_verified'] == true || json['verification_status'] == 'VERIFIED',
      verificationStatus: json['verification_status']?.toString() ?? 'UNVERIFIED',
      qrisImageUrl: json['qris_image_url']?.toString() ?? '',
      ewalletName: json['ewallet_name']?.toString() ?? 'DANA / GoPay / OVO',
      ewalletNumber: json['ewallet_number']?.toString() ?? '',
      campusName: json['campus_name']?.toString() ?? 'Kampus',
      fcmToken: json['fcm_token']?.toString() ?? '',
      ratingTotal: (json['rating_total'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isProfileComplete => phone.trim().isNotEmpty && (ktmImageUrl.trim().isNotEmpty || isKtmVerified);

  String get formattedRating {
    if (ratingCount == 0) return 'Belum dinilai';
    return '${ratingTotal.toStringAsFixed(1)} ($ratingCount ulasan)';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nim': nim,
      'name': name,
      'phone': phone,
      'avatar_url': avatarUrl,
      'ktm_image_url': ktmImageUrl,
      'is_ktm_verified': isKtmVerified,
      'verification_status': verificationStatus,
      'qris_image_url': qrisImageUrl,
      'ewallet_name': ewalletName,
      'ewallet_number': ewalletNumber,
      'campus_name': campusName,
      'fcm_token': fcmToken,
    };
  }
}
