class AppConstants {
  // App Info
  static const String appName = 'Mpus';
  static const String appTagline = 'Marketplace Kampus Terpercaya';

  // Microservices API Endpoints
  // Default to 127.0.0.1:8000 (Physical Android device via adb reverse tcp:8000 tcp:8000 & desktop)
  static const String ocrServiceBaseUrl = String.fromEnvironment(
    'OCR_SERVICE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // Storage Bucket Names
  static const String productImagesBucket = 'product-images';
  static const String avatarsBucket = 'avatars';
  static const String qrisCodesBucket = 'qris-codes';
  static const String ktmDocumentsBucket = 'ktm-documents';

  // Categories
  static const List<String> categories = [
    'Semua',
    'Buku',
    'Elektronik',
    'Fashion',
    'Makanan',
    'Alat Tulis',
    'Jasa',
    'Lainnya',
  ];

  // Product Conditions
  static const List<String> productConditions = [
    'Baru',
    'Bekas - Mulus',
    'Bekas - Normal',
    'Bekas - Perlu Servis',
  ];

  // Order Statuses
  static const String statusMenungguKonfirmasi = 'MENUNGGU_KONFIRMASI';
  static const String statusDisetujuiCod = 'DISETUJUI_COD';
  static const String statusSudahBayarQris = 'SUDAH_BAYAR_QRIS';
  static const String statusSelesai = 'SELESAI';
  static const String statusDibatalkan = 'DIBATALKAN';
}
