import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/order_service.dart';
import '../auth/login_page.dart';
import '../auth/change_phone_page.dart';
import '../auth/change_password_page.dart';
import '../catalog/product_form_page.dart';
import '../catalog/product_detail_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final ProductService _productService = ProductService();
  final OrderService _orderService = OrderService();

  int _selectedTab = 0; // 0 = Barang Saya, 1 = Pesanan Saya
  bool _isUploadingImage = false;
  Map<String, dynamic>? _userProfile;
  bool _isLoadingProfile = true;

  final currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final profile = await _profileService.getProfile(uid);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _pickAndUploadImage() async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return;

    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Potong Foto Profil',
          toolbarColor: MpusTheme.primaryColor,
          toolbarWidgetColor: MpusTheme.textDarkColor,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Potong Foto Profil',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final newAvatarUrl = await _profileService.updateAvatar(
        File(croppedFile.path),
        currentUserId,
      );

      if (mounted) {
        setState(() {
          if (_userProfile != null) {
            _userProfile!['avatar_url'] = newAvatarUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Foto profil berhasil diperbarui!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengunggah foto profil: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showQrisSettingsDialog() {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return;

    final ewalletNameCtrl = TextEditingController(text: _userProfile?['ewallet_name'] ?? 'DANA');
    final ewalletNumberCtrl = TextEditingController(text: _userProfile?['ewallet_number'] ?? '');
    File? selectedQrisFile;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'Pengaturan QRIS & E-Wallet',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unggah kode QRIS atau masukkan nomor transfer E-Wallet untuk menerima pembayaran digital dari pembeli.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (picked != null) {
                          setDialogState(() {
                            selectedQrisFile = File(picked.path);
                          });
                        }
                      },
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MpusTheme.backgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                        ),
                        child: selectedQrisFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(selectedQrisFile!, fit: BoxFit.contain),
                              )
                            : (_userProfile?['qris_image_url'] != null && _userProfile!['qris_image_url'].toString().isNotEmpty)
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(_userProfile!['qris_image_url'].toString(), fit: BoxFit.contain),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.grey),
                                      SizedBox(height: 6),
                                      Text('Ketuk untuk unggah foto QRIS', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: ewalletNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nama E-Wallet / Bank',
                        hintText: 'Contoh: DANA / GoPay / BCA',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ewalletNumberCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nomor Akun / Rekening',
                        hintText: '081234567890',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MpusTheme.tealDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            if (selectedQrisFile != null) {
                              await _profileService.updateQrisCode(selectedQrisFile!, currentUserId);
                            }
                            await _profileService.updateProfile(
                              userId: currentUserId,
                              ewalletName: ewalletNameCtrl.text.trim(),
                              ewalletNumber: ewalletNumberCtrl.text.trim(),
                            );
                            await _loadProfile();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Pengaturan pembayaran digital berhasil disimpan!')),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal menyimpan: $e')),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCustomMenu(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return Stack(
          children: [
            Positioned(
              top: statusBarHeight + 10,
              right: 16,
              child: Container(
                width: 230,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pengaturan Akun',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: MpusTheme.textDarkColor,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      ListTile(
                        leading: const Icon(Icons.qr_code_2_rounded, color: MpusTheme.tealDark, size: 20),
                        title: Text(
                          'QRIS & E-Wallet Toko',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: MpusTheme.textDarkColor,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showQrisSettingsDialog();
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      ListTile(
                        leading: const Icon(Icons.phone_outlined, color: MpusTheme.tealDark, size: 20),
                        title: Text(
                          'Ganti No. WhatsApp',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: MpusTheme.textDarkColor,
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePhonePage()));
                          _loadProfile();
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: MpusTheme.tealDark, size: 20),
                        title: Text(
                          'Ganti Kata Sandi',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: MpusTheme.textDarkColor,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordPage()));
                        },
                      ),
                      const Divider(height: 1, color: Color(0xFFE5E5E5)),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red, size: 20),
                        title: Text(
                          'Keluar Akun',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _signOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _konfirmasiHapusBarang(String productId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Barang?"),
        content: Text("Apakah Anda yakin ingin menghapus '$title' dari katalog toko?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _productService.deleteProduct(productId);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Barang berhasil dihapus")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Gagal menghapus: $e")),
                  );
                }
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getRatingText(Map<String, dynamic>? data) {
    if (data == null) return 'Belum dinilai';
    double total = (data['rating_total'] ?? 0.0).toDouble();
    int count = (data['rating_count'] ?? 0);
    if (count == 0) return 'Belum dinilai';
    return '${total.toStringAsFixed(1)} ($count Ulasan)';
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

  @override
  Widget build(BuildContext context) {
    double statusBarHeight = MediaQuery.of(context).padding.top;

    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final username = _userProfile?['name'] as String? ?? 'Pengguna Mpus';
    final campus = _userProfile?['campus_name'] as String? ?? 'Mahasiswa Kampus';
    final phone = _userProfile?['phone'] as String? ?? '-';

    return Stack(
      children: [
        Column(
          children: [
            // Header Profile Container
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFB4FFF9),
                    Color(0xFFB4FFF9),
                    Color(0xFFF5F5F5),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              padding: EdgeInsets.only(top: statusBarHeight + 10, bottom: 16),
              child: Stack(
                children: [
                  Positioned(
                    right: 16,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz_rounded, size: 28, color: MpusTheme.textDarkColor),
                      onPressed: () => _showCustomMenu(context),
                    ),
                  ),

                  // User Info
                  Align(
                    alignment: Alignment.center,
                    child: _isLoadingProfile
                        ? const SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Column(
                            children: [
                              GestureDetector(
                                onTap: _isUploadingImage ? null : _pickAndUploadImage,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 82,
                                      height: 82,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFFE5E5E5),
                                        border: Border.all(color: Colors.white, width: 3),
                                        image: (avatarUrl != null && avatarUrl.isNotEmpty)
                                            ? DecorationImage(
                                                image: NetworkImage(avatarUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: (avatarUrl == null || avatarUrl.isEmpty) && !_isUploadingImage
                                          ? const Icon(Icons.person, color: Colors.grey, size: 42)
                                          : null,
                                    ),
                                    if (_isUploadingImage)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                    if (!_isUploadingImage)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(
                                            color: MpusTheme.tealDark,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getRatingText(_userProfile),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: MpusTheme.textDarkColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    username,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: MpusTheme.textDarkColor,
                                    ),
                                  ),
                                  if (_userProfile?['is_ktm_verified'] == true) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, color: Color(0xFF00838F), size: 18),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_userProfile?['is_ktm_verified'] == true)
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : (_userProfile?['ktm_image_url'] != null && _userProfile!['ktm_image_url'].toString().isNotEmpty)
                                          ? Colors.orange.withValues(alpha: 0.15)
                                          : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (_userProfile?['is_ktm_verified'] == true)
                                      ? "✓ Mahasiswa Terverifikasi"
                                      : (_userProfile?['ktm_image_url'] != null && _userProfile!['ktm_image_url'].toString().isNotEmpty)
                                          ? "⏳ KTM Dalam Peninjauan"
                                          : "⚠️ Belum Verifikasi KTM",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: (_userProfile?['is_ktm_verified'] == true)
                                        ? Colors.green.shade800
                                        : (_userProfile?['ktm_image_url'] != null && _userProfile!['ktm_image_url'].toString().isNotEmpty)
                                            ? Colors.orange.shade800
                                            : Colors.red.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$campus • $phone',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  color: const Color(0xFF8F8F8F),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            // Tab Buttons
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFFE5E5E5),
              ),
              child: Row(
                children: [
                  _buildTab("Barang Saya", 0),
                  _buildTab("Pesanan COD", 1),
                ],
              ),
            ),

            // Tab Content
            Expanded(
              child: Container(
                color: MpusTheme.backgroundColor,
                child: _selectedTab == 0
                    ? _buildBarangSayaGrid()
                    : _buildPesananSayaList(),
              ),
            ),
          ],
        ),

        // FAB Add Product
        if (_selectedTab == 0)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductFormPage()),
                );
                setState(() {});
              },
              backgroundColor: MpusTheme.primaryColor,
              elevation: 4,
              child: const Icon(Icons.add, color: MpusTheme.textDarkColor, size: 28),
            ),
          ),
      ],
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? MpusTheme.backgroundColor : const Color(0xFFE0E0E0),
            borderRadius: isActive
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.zero,
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? MpusTheme.textDarkColor : const Color(0xFF8F8F8F),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarangSayaGrid() {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null) {
      return const Center(child: Text("Silakan login"));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _productService.getMyProducts(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Gagal memuat barang: ${snapshot.error}"));
        }

        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  "Anda belum mengunggah barang",
                  style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormPage()));
                    setState(() {});
                  },
                  icon: const Icon(Icons.add, color: MpusTheme.textDarkColor),
                  label: const Text('Tambah Barang Pertama', style: TextStyle(color: MpusTheme.textDarkColor, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MpusTheme.primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.74,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final item = products[index];
            final images = item['images'] as List?;
            String? firstImage;
            if (images != null && images.isNotEmpty) {
              firstImage = images[0].toString();
            }
            final isSold = item['is_sold'] == true;

            return GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(
                      productData: item,
                      productId: item['id'].toString(),
                    ),
                  ),
                );
                setState(() {});
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          child: AspectRatio(
                            aspectRatio: 1.15,
                            child: Container(
                              color: const Color(0xFFF0F4F4),
                              child: firstImage != null
                                  ? Image.network(
                                      firstImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) => const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined, size: 44, color: Colors.grey),
                            ),
                          ),
                        ),
                        if (isSold)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.5),
                                alignment: Alignment.center,
                                child: Transform.rotate(
                                  angle: -0.3,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    color: Colors.red,
                                    child: const Text(
                                      "TERJUAL",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name']?.toString() ?? 'Tanpa Nama',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: MpusTheme.textDarkColor,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatPrice(item['price']),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: MpusTheme.tealDark,
                                    ),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductFormPage(
                                            productToEdit: item,
                                            productId: item['id'].toString(),
                                          ),
                                        ),
                                      );
                                      setState(() {});
                                    } else if (value == 'toggle_sold') {
                                      await _productService.toggleProductSold(item['id'].toString(), !isSold);
                                      setState(() {});
                                    } else if (value == 'hapus') {
                                      _konfirmasiHapusBarang(item['id'].toString(), item['name']?.toString() ?? 'barang');
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text('Edit Barang'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'toggle_sold',
                                      child: Row(
                                        children: [
                                          Icon(isSold ? Icons.check_circle_outline : Icons.sell_outlined, size: 18, color: Colors.black87),
                                          SizedBox(width: 8),
                                          Text(isSold ? 'Tandai Tersedia' : 'Tandai Terjual'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'hapus',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Hapus Barang', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPesananSayaList() {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null) {
      return const Center(child: Text("Silakan login"));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _orderService.getMyPurchases(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Gagal memuat pesanan: ${snapshot.error}"));
        }

        final orders = snapshot.data ?? [];
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text("Belum ada riwayat pesanan COD", style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final product = order['product'] as Map<String, dynamic>?;
            final seller = order['seller'] as Map<String, dynamic>?;
            final status = order['status']?.toString() ?? 'MENUNGGU_KONFIRMASI';

            final productImages = product?['images'] as List?;
            final firstImage = (productImages != null && productImages.isNotEmpty) ? productImages[0].toString() : null;

            Color statusColor = Colors.orange;
            String statusText = 'Menunggu Penjual';

            switch (status) {
              case 'DISETUJUI_COD':
                statusColor = Colors.blue;
                statusText = 'COD Disetujui';
                break;
              case 'SUDAH_BAYAR_QRIS':
                statusColor = Colors.teal;
                statusText = 'QRIS Dibayar';
                break;
              case 'SELESAI':
                statusColor = Colors.green;
                statusText = 'Selesai';
                break;
              case 'DIBATALKAN':
                statusColor = Colors.red;
                statusText = 'Dibatalkan';
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.05),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFFE5E5E5),
                    child: firstImage != null
                        ? Image.network(firstImage, fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined, color: Colors.grey),
                  ),
                ),
                title: Text(
                  product?['name']?.toString() ?? 'Produk Mpus',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      _formatPrice(order['total_price']),
                      style: GoogleFonts.plusJakartaSans(color: MpusTheme.tealDark, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(seller?['name']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () async {
                  if (product != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailPage(
                          productData: product,
                          productId: product['id'].toString(),
                          passedOrderId: order['id'].toString(),
                        ),
                      ),
                    );
                    setState(() {});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
