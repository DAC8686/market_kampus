import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/order_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/product_service.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> productData;
  final String productId;
  final String? passedOrderId;

  const ProductDetailPage({
    super.key,
    required this.productData,
    required this.productId,
    this.passedOrderId,
  });

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

// Backward compatibility typedef
typedef ProductBuyPage = ProductDetailPage;

class _ProductDetailPageState extends State<ProductDetailPage> {
  final OrderService _orderService = OrderService();
  final ProfileService _profileService = ProfileService();
  final ProductService _productService = ProductService();

  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  Map<String, dynamic>? _sellerData;
  Map<String, dynamic>? _existingOrder;
  String? _existingOrderId;
  Map<String, dynamic>? _buyerData;

  bool _isLoadingBuyer = false;
  bool _isCurrentUserSeller = false;
  bool _isLoadingSeller = true;
  bool _isLoadingOrder = true;

  final TextEditingController _waktuCtrl = TextEditingController();
  final TextEditingController _tempatCtrl = TextEditingController();
  final TextEditingController _catatanCtrl = TextEditingController();
  DateTime? _selectedDate;
  final String _selectedPaymentMethod = 'COD';

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _checkUserRoleAndLoad();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _waktuCtrl.dispose();
    _tempatCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUserRoleAndLoad() async {
    final currentUserId = SupabaseConfig.currentUserId;
    final sellerId = widget.productData['seller_id'] ?? widget.productData['sellerId'] ?? widget.productData['userId'];

    if (currentUserId != null && sellerId != null && currentUserId == sellerId) {
      _isCurrentUserSeller = true;
    }

    await Future.wait([
      _loadSellerData(sellerId?.toString()),
      _loadExistingOrder(),
    ]);
  }

  Future<void> _loadSellerData(String? sellerId) async {
    if (sellerId == null || sellerId.isEmpty) {
      setState(() => _isLoadingSeller = false);
      return;
    }

    try {
      final profile = await _profileService.getProfile(sellerId);
      if (mounted) {
        setState(() {
          _sellerData = profile;
        });
      }
    } catch (e) {
      debugPrint("Error loading seller profile: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingSeller = false);
      }
    }
  }

  Future<void> _loadExistingOrder() async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) {
      setState(() => _isLoadingOrder = false);
      return;
    }

    try {
      Map<String, dynamic>? order;

      if (widget.passedOrderId != null) {
        order = await _orderService.getOrderById(widget.passedOrderId!);
      } else {
        order = await _orderService.getActiveOrderForProduct(
          productId: widget.productId,
          userId: currentUserId,
          isSeller: _isCurrentUserSeller,
        );
      }

      if (order != null && mounted) {
        setState(() {
          _existingOrder = order;
          _existingOrderId = order!['id']?.toString();
          _waktuCtrl.text = order['cod_meeting_time'] ?? order['waktu'] ?? '';
          _tempatCtrl.text = order['cod_location'] ?? order['tempat'] ?? '';
          _catatanCtrl.text = order['notes'] ?? '';

          // Extract date
          final dateStr = order['cod_meeting_time'] ?? '';
          if (dateStr.isNotEmpty) {
            try {
              final parts = dateStr.split(' ')[0].split('/');
              if (parts.length == 3) {
                _selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {}
          }
        });

        // Load buyer data if seller viewing
        final buyerId = order['buyer_id']?.toString();
        if (_isCurrentUserSeller && buyerId != null) {
          setState(() => _isLoadingBuyer = true);
          final buyerProfile = await _profileService.getProfile(buyerId);
          if (mounted) {
            setState(() {
              _buyerData = buyerProfile;
              _isLoadingBuyer = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading existing order: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingOrder = false);
      }
    }
  }

  Future<void> _submitOrder() async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu')),
      );
      return;
    }

    if (_selectedDate == null || _tempatCtrl.text.trim().isEmpty || _waktuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi tanggal, tempat, dan jam pertemuan COD')),
      );
      return;
    }

    try {
      final formattedDate = '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year} ${_waktuCtrl.text.trim()}';
      final sellerId = widget.productData['seller_id'] ?? widget.productData['sellerId'] ?? widget.productData['userId'];

      final rawPrice = widget.productData['price'];
      double numPrice = 0.0;
      if (rawPrice is num) {
        numPrice = rawPrice.toDouble();
      } else if (rawPrice is String) {
        numPrice = double.tryParse(rawPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      }

      if (_existingOrderId != null) {
        await _orderService.updateOrder(
          orderId: _existingOrderId!,
          codLocation: _tempatCtrl.text.trim(),
          codMeetingTime: formattedDate,
          notes: _catatanCtrl.text.trim(),
          status: 'MENUNGGU_KONFIRMASI',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengajuan COD berhasil diperbarui!')),
          );
        }
      } else {
        await _orderService.createOrder(
          productId: widget.productId,
          buyerId: currentUserId,
          sellerId: sellerId.toString(),
          paymentMethod: _selectedPaymentMethod,
          codLocation: _tempatCtrl.text.trim(),
          codMeetingTime: formattedDate,
          totalPrice: numPrice,
          notes: _catatanCtrl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengajuan COD berhasil dikirim ke penjual!')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        _loadExistingOrder();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim pengajuan: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    if (_existingOrderId == null) return;
    try {
      await _orderService.updateOrderStatus(_existingOrderId!, newStatus);

      if (newStatus == 'SELESAI') {
        await _productService.toggleProductSold(widget.productId, true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status pesanan berhasil diubah: ${newStatus.replaceAll('_', ' ')}')),
        );
        Navigator.pop(context);
        _loadExistingOrder();
      }

      // Show rating dialog for buyer if completed
      if (newStatus == 'SELESAI' && !_isCurrentUserSeller) {
        final sellerId = widget.productData['seller_id']?.toString() ?? '';
        if (mounted) {
          _showRatingDialog(context, sellerId, widget.productId, _existingOrderId!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    }
  }

  Future<void> _openWhatsApp(String? phone, String productName, String productPrice) async {
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor WhatsApp tidak tersedia')),
      );
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('8')) {
      cleanPhone = '62$cleanPhone';
    }

    String senderName = "Pengguna Mpus";
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId != null) {
      final myProfile = await _profileService.getProfile(currentUserId);
      if (myProfile != null && myProfile['name'] != null) {
        senderName = myProfile['name'].toString();
      }
    }

    String message;
    if (_isCurrentUserSeller) {
      message = "Halo, saya $senderName (Penjual) dari Market Kampus. Terkait pengajuan COD untuk produk *$productName* seharga $productPrice, apakah kita bisa janjian sekarang?";
    } else {
      message = "Halo, saya $senderName dari Market Kampus. Saya berminat dengan produk *$productName* seharga $productPrice, apakah masih ada dan bisa COD?";
    }

    final Uri url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membuka WhatsApp')),
        );
      }
    }
  }

  void _showQrisModal() {
    final qrisUrl = _sellerData?['qris_image_url'] as String?;
    final ewalletName = _sellerData?['ewallet_name'] as String? ?? 'E-Wallet';
    final ewalletNumber = _sellerData?['ewallet_number'] as String? ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Pembayaran Digital Penjual',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MpusTheme.textDarkColor,
                ),
              ),
              const SizedBox(height: 16),
              if (qrisUrl != null && qrisUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    qrisUrl,
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Scan QRIS toko di atas menggunakan aplikasi Bank / E-Wallet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MpusTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('Penjual belum mengunggah kode QRIS', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              if (ewalletNumber.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MpusTheme.primaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00C4B4).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: MpusTheme.tealDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ewalletName, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(ewalletNumber, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: MpusTheme.textDarkColor)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: MpusTheme.tealDark),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: ewalletNumber));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nomor e-wallet disalin ke clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showCODBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final status = _existingOrder?['status'] ?? 'MENUNGGU_KONFIRMASI';
            final bool isFormEditable = !_isCurrentUserSeller &&
                (_existingOrder == null || status == 'MENUNGGU_KONFIRMASI');

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F5F5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MpusTheme.textSecondaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isCurrentUserSeller ? 'Pengajuan Transaksi COD' : 'Atur Janjian COD',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: MpusTheme.textDarkColor,
                                ),
                              ),
                              if (_existingOrder != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _getStatusColor(status)),
                                  ),
                                  child: Text(
                                    status.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Tanggal Pertemuan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8F8F8F))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: isFormEditable
                                ? () async {
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: _selectedDate ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(const Duration(days: 60)),
                                    );
                                    if (picked != null) {
                                      setModalState(() => _selectedDate = picked);
                                      setState(() => _selectedDate = picked);
                                    }
                                  }
                                : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                hintText: 'Pilih tanggal pertemuan',
                                hintStyle: const TextStyle(color: Colors.grey),
                                suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF8F8F8F)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                filled: true,
                                fillColor: isFormEditable ? Colors.white : Colors.grey.shade200,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              ),
                              child: Text(
                                _selectedDate != null
                                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                    : '',
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Jam Pertemuan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8F8F8F))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _waktuCtrl,
                            readOnly: !isFormEditable,
                            decoration: InputDecoration(
                              hintText: 'Contoh: 15.30 WIB / Setelah jam kuliah',
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isFormEditable ? Colors.white : Colors.grey.shade200,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text('Lokasi / Tempat COD Kampus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8F8F8F))),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _tempatCtrl,
                            readOnly: !isFormEditable,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Contoh: Kantin Fakultas Teknik / Depan Perpustakaan Utama',
                              hintStyle: const TextStyle(color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              filled: true,
                              fillColor: isFormEditable ? Colors.white : Colors.grey.shade200,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            ),
                          ),

                          // Profile Pembeli jika Penjual yang melihat
                          if (_isCurrentUserSeller && _existingOrder != null) ...[
                            const SizedBox(height: 20),
                            const Text('Profil Calon Pembeli', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF8F8F8F))),
                            const SizedBox(height: 8),
                            _isLoadingBuyer
                                ? const Center(child: CircularProgressIndicator())
                                : Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: const Color(0xFFE5E5E5),
                                          backgroundImage: _buyerData?['avatar_url'] != null && _buyerData!['avatar_url'].toString().isNotEmpty
                                              ? NetworkImage(_buyerData!['avatar_url'].toString())
                                              : null,
                                          child: (_buyerData?['avatar_url'] == null || _buyerData!['avatar_url'].toString().isEmpty)
                                              ? const Icon(Icons.person, color: Colors.grey, size: 28)
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _buyerData?['name']?.toString() ?? 'Calon Pembeli',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: MpusTheme.textDarkColor),
                                              ),
                                              Text(
                                                _buyerData?['campus_name']?.toString() ?? _buyerData?['phone']?.toString() ?? '',
                                                style: const TextStyle(fontSize: 12, color: MpusTheme.textSecondaryColor),
                                              ),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _openWhatsApp(
                                            _buyerData?['phone']?.toString(),
                                            widget.productData['name']?.toString() ?? 'Produk',
                                            _formatPrice(widget.productData['price']),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.chat, color: Colors.green, size: 22),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // Actions Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Builder(
                      builder: (context) {
                        if (_isCurrentUserSeller && _existingOrder != null) {
                          if (status == 'MENUNGGU_KONFIRMASI') {
                            return Row(
                              children: [
                                Expanded(child: _buildStatusBtn('Tolak Tawaran', false, () => _updateOrderStatus('DIBATALKAN'))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatusBtn('Setujui COD', true, () => _updateOrderStatus('DISETUJUI_COD'))),
                              ],
                            );
                          } else if (status == 'DISETUJUI_COD' || status == 'SUDAH_BAYAR_QRIS') {
                            return Row(
                              children: [
                                Expanded(child: _buildStatusBtn('Batalkan', false, () => _updateOrderStatus('DIBATALKAN'))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatusBtn('Transaksi Selesai', true, () => _updateOrderStatus('SELESAI'))),
                              ],
                            );
                          } else {
                            return _buildStatusBtn('Pesanan Selesai / Arsip', true, null);
                          }
                        } else {
                          if (_existingOrder == null) {
                            final isSold = widget.productData['is_sold'] == true;
                            return GestureDetector(
                              onTap: isSold ? null : _submitOrder,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSold ? Colors.grey.shade300 : MpusTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isSold ? 'Barang Sudah Terjual' : 'Ajukan Jadwal COD Sekarang',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSold ? Colors.grey.shade600 : MpusTheme.textDarkColor,
                                  ),
                                ),
                              ),
                            );
                          } else if (status == 'MENUNGGU_KONFIRMASI') {
                            return Row(
                              children: [
                                Expanded(child: _buildStatusBtn('Batalkan', false, () => _updateOrderStatus('DIBATALKAN'))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatusBtn('Perbarui Jadwal', true, _submitOrder)),
                              ],
                            );
                          } else if (status == 'DISETUJUI_COD' || status == 'SUDAH_BAYAR_QRIS') {
                            return Row(
                              children: [
                                Expanded(child: _buildStatusBtn('Batalkan', false, () => _updateOrderStatus('DIBATALKAN'))),
                                const SizedBox(width: 12),
                                Expanded(child: _buildStatusBtn('Konfirmasi Selesai', true, () => _updateOrderStatus('SELESAI'))),
                              ],
                            );
                          } else {
                            return _buildStatusBtn('Pesanan ${status.replaceAll('_', ' ')}', true, null);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'MENUNGGU_KONFIRMASI':
        return Colors.orange;
      case 'DISETUJUI_COD':
      case 'SUDAH_BAYAR_QRIS':
        return Colors.blue;
      case 'SELESAI':
        return Colors.green;
      case 'DIBATALKAN':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBtn(String text, bool isPrimary, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? MpusTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(color: Colors.red, width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isPrimary ? MpusTheme.textDarkColor : Colors.red,
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, String sellerId, String productId, String orderId) {
    double rating = 5.0;
    final commentCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: const Color(0xFFF5F5F5),
              title: Text(
                "Beri Nilai Penjual",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: MpusTheme.textDarkColor, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Bagaimana pengalaman transaksi COD Anda dengan penjual ini?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  RatingBar.builder(
                    initialRating: 5,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: false,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                    onRatingUpdate: (val) => rating = val,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Tulis ulasan singkat (opsional)',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text("Nanti Saja", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MpusTheme.tealDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() => isSubmitting = true);
                          final currentUserId = SupabaseConfig.currentUserId;
                          if (currentUserId != null) {
                            try {
                              await _orderService.submitReview(
                                orderId: orderId,
                                productId: productId,
                                reviewerId: currentUserId,
                                sellerId: sellerId,
                                rating: rating.toInt(),
                                comment: commentCtrl.text,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Terima kasih atas ulasan Anda!")),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Gagal mengirim ulasan: $e")),
                                );
                              }
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("KIRIM ULASAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    if (price is num) return currencyFormatter.format(price);
    if (price is String) {
      final parsed = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), ''));
      if (parsed != null) return currencyFormatter.format(parsed);
      return price;
    }
    return price.toString();
  }

  String _getRatingText(Map<String, dynamic>? userData) {
    if (userData == null) return 'Belum dinilai';
    double total = (userData['rating_total'] ?? 0.0).toDouble();
    int count = (userData['rating_count'] ?? 0);
    if (count == 0) return 'Belum dinilai';
    return '${total.toStringAsFixed(1)} ($count ulasan)';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleW = screenWidth / 412;
    double statusBarHeight = MediaQuery.of(context).padding.top;

    final dynamic rawImages = widget.productData['images'];
    List<dynamic> images = [];
    if (rawImages is List) {
      images = rawImages;
    } else if (rawImages is String && rawImages.isNotEmpty) {
      images = [rawImages];
    }

    final isSold = widget.productData['is_sold'] == true;

    return Scaffold(
      backgroundColor: MpusTheme.backgroundColor,
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: _showCODBottomSheet,
            child: Container(
              height: 52 * scaleW,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSold ? Colors.grey.shade300 : MpusTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: _isLoadingOrder
                  ? SizedBox(width: 20 * scaleW, height: 20 * scaleW, child: const CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      _isCurrentUserSeller
                          ? (_existingOrderId != null ? 'Ada Pengajuan COD (Lihat Status)' : 'Kelola Penjualan Ini')
                          : (_existingOrderId != null ? 'Lihat Detail Janjian COD' : (isSold ? 'Barang Sudah Terjual' : 'Atur COD / Chat Penjual')),
                      style: TextStyle(
                        fontSize: 15 * scaleW,
                        fontWeight: FontWeight.bold,
                        color: isSold ? Colors.grey.shade600 : MpusTheme.textDarkColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        MpusTheme.primaryColor,
                        MpusTheme.primaryColor.withValues(alpha: 0.7),
                        MpusTheme.backgroundColor,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24 * scaleW),
                      bottomRight: Radius.circular(24 * scaleW),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: statusBarHeight + 16 * scaleW,
                              bottom: 8 * scaleW,
                              left: 16 * scaleW,
                              right: 16 * scaleW,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16 * scaleW),
                              child: SizedBox(
                                height: 280 * scaleW,
                                width: double.infinity,
                                child: images.isNotEmpty
                                    ? PageView.builder(
                                        controller: _pageController,
                                        itemCount: images.length,
                                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                                        itemBuilder: (_, i) => Image.network(
                                          images[i].toString(),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      )
                                    : Container(
                                        color: const Color(0xFFE5E5E5),
                                        child: Icon(Icons.image_outlined, size: 80 * scaleW, color: Colors.grey),
                                      ),
                              ),
                            ),
                          ),
                          if (images.length > 1)
                            Positioned(
                              bottom: 16 * scaleW,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  images.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: EdgeInsets.symmetric(horizontal: 3 * scaleW),
                                    width: _currentImageIndex == i ? 12 * scaleW : 6 * scaleW,
                                    height: 6 * scaleW,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == i ? Colors.white : Colors.white60,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      Padding(
                        padding: EdgeInsets.fromLTRB(16 * scaleW, 8 * scaleW, 16 * scaleW, 16 * scaleW),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatPrice(widget.productData['price']),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22 * scaleW,
                                    fontWeight: FontWeight.bold,
                                    color: MpusTheme.tealDark,
                                  ),
                                ),
                                if (isSold)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('TERJUAL', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                              ],
                            ),
                            SizedBox(height: 6 * scaleW),
                            Text(
                              widget.productData['name']?.toString() ?? 'Nama Produk',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18 * scaleW,
                                fontWeight: FontWeight.bold,
                                color: MpusTheme.textDarkColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Seller Card
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16 * scaleW),
                        child: Container(
                          padding: EdgeInsets.all(14 * scaleW),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16 * scaleW),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))
                            ],
                          ),
                          child: _isLoadingSeller
                              ? const LinearProgressIndicator()
                              : Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26 * scaleW,
                                      backgroundColor: const Color(0xFFE5E5E5),
                                      backgroundImage: _sellerData?['avatar_url'] != null && _sellerData!['avatar_url'].toString().isNotEmpty
                                          ? NetworkImage(_sellerData!['avatar_url'].toString())
                                          : null,
                                      child: (_sellerData?['avatar_url'] == null || _sellerData!['avatar_url'].toString().isEmpty)
                                          ? Icon(Icons.person, color: Colors.grey, size: 28 * scaleW)
                                          : null,
                                    ),
                                    SizedBox(width: 12 * scaleW),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _sellerData?['name']?.toString() ?? 'Penjual Mpus',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 15 * scaleW,
                                              fontWeight: FontWeight.bold,
                                              color: MpusTheme.textDarkColor,
                                            ),
                                          ),
                                          Text(
                                            _sellerData?['campus_name']?.toString() ?? 'Kampus Mahasiswa',
                                            style: GoogleFonts.roboto(
                                              fontSize: 12 * scaleW,
                                              color: const Color(0xFF8F8F8F),
                                            ),
                                          ),
                                          SizedBox(height: 2 * scaleW),
                                          Row(
                                            children: [
                                              Icon(Icons.star_rounded, color: Colors.amber, size: 16 * scaleW),
                                              SizedBox(width: 3 * scaleW),
                                              Text(
                                                _getRatingText(_sellerData),
                                                style: TextStyle(
                                                  fontSize: 11 * scaleW,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF8F8F8F),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _openWhatsApp(
                                        _sellerData?['phone']?.toString(),
                                        widget.productData['name']?.toString() ?? 'Produk',
                                        _formatPrice(widget.productData['price']),
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(8 * scaleW),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.chat_outlined, color: Colors.green, size: 22 * scaleW),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      SizedBox(height: 14 * scaleW),
                    ],
                  ),
                ),

                // Digital Payment Options (QRIS / E-Wallet)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * scaleW, vertical: 8 * scaleW),
                  child: InkWell(
                    onTap: _showQrisModal,
                    borderRadius: BorderRadius.circular(14 * scaleW),
                    child: Container(
                      padding: EdgeInsets.all(14 * scaleW),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14 * scaleW),
                        border: Border.all(color: const Color(0xFF00C4B4).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MpusTheme.primaryColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_2_rounded, color: MpusTheme.tealDark, size: 24),
                          ),
                          SizedBox(width: 12 * scaleW),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Opsi Pembayaran QRIS / E-Wallet', style: GoogleFonts.plusJakartaSans(fontSize: 13 * scaleW, fontWeight: FontWeight.bold, color: MpusTheme.textDarkColor)),
                                Text('Lihat kode QRIS atau nomor transfer toko', style: TextStyle(fontSize: 11 * scaleW, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),

                // Product Description
                Padding(
                  padding: EdgeInsets.all(16 * scaleW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi Barang',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16 * scaleW,
                          fontWeight: FontWeight.bold,
                          color: MpusTheme.textDarkColor,
                        ),
                      ),
                      SizedBox(height: 8 * scaleW),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14 * scaleW),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14 * scaleW),
                        ),
                        child: Text(
                          widget.productData['description']?.toString() ?? 'Tidak ada deskripsi rinci untuk produk ini.',
                          style: GoogleFonts.roboto(
                            fontSize: 14 * scaleW,
                            color: const Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 40 * scaleW),
              ],
            ),
          ),

          Positioned(
            top: statusBarHeight + 12 * scaleW,
            left: 16 * scaleW,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38 * scaleW,
                height: 38 * scaleW,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                ),
                child: Icon(Icons.arrow_back_rounded, color: MpusTheme.textDarkColor, size: 20 * scaleW),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
