import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/product_service.dart';
import '../../data/services/profile_service.dart';

class ProductFormPage extends StatefulWidget {
  final Map<String, dynamic>? productToEdit;
  final String? productId;

  const ProductFormPage({super.key, this.productToEdit, this.productId});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

// Backward compatibility alias
typedef AddProductPage = ProductFormPage;

class _ProductFormPageState extends State<ProductFormPage> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();
  final ProfileService _profileService = ProfileService();

  String _selectedCategory = 'Elektronik';
  final List<String> _categories = AppConstants.categories.where((c) => c != 'Semua').toList();

  final List<File> _productImages = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      _nameController.text = widget.productToEdit!['name'] ?? '';
      final rawPrice = widget.productToEdit!['price'];
      if (rawPrice != null) {
        _priceController.text = 'Rp ${rawPrice.toString().replaceAll(RegExp(r'[^0-9]'), '')}';
      }
      _descController.text = widget.productToEdit!['description'] ?? '';
      if (widget.productToEdit!['category'] != null && _categories.contains(widget.productToEdit!['category'])) {
        _selectedCategory = widget.productToEdit!['category'];
      }

      _existingImageUrls = List<String>.from(
        widget.productToEdit!['images'] ?? [],
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitProduct() async {
    final name = _nameController.text.trim();
    final priceStr = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || priceStr.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi semua kolom wajib")),
      );
      return;
    }

    final double price = double.tryParse(priceStr) ?? 0;
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harga barang harus lebih dari Rp 0")),
      );
      return;
    }

    if (_existingImageUrls.isEmpty && _productImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap tambahkan minimal 1 gambar produk")),
      );
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sesi login berakhir, silakan login ulang")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🛡️ Security Guard: Verifikasi data KTM & WhatsApp terlebih dahulu
      final isComplete = await _profileService.isProfileComplete(userId);
      if (!isComplete) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Harap pastikan nomor WhatsApp dan verifikasi KTM sudah aktif di profil sebelum menjual barang."),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }
      if (widget.productId != null) {
        await _productService.updateProduct(
          productId: widget.productId!,
          name: name,
          price: price,
          description: desc,
          category: _selectedCategory,
          existingImages: _existingImageUrls,
          newImageFiles: _productImages,
          sellerId: userId,
        );
      } else {
        await _productService.addProduct(
          sellerId: userId,
          name: name,
          price: price,
          description: desc,
          category: _selectedCategory,
          imageFiles: _productImages,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.productId == null
              ? "Barang berhasil ditambahkan!"
              : "Barang berhasil diperbarui!"),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan barang: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_existingImageUrls.length + _productImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maksimal 3 gambar saja")),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Potong Gambar',
            toolbarColor: MpusTheme.primaryColor,
            toolbarWidgetColor: Colors.black87,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Potong Gambar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _productImages.add(File(croppedFile.path));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.productId == null ? "Tambah Barang" : "Edit Barang",
          style: const TextStyle(
            color: MpusTheme.textDarkColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: MpusTheme.textDarkColor,
            size: 24,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MpusTheme.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: MpusTheme.textDarkColor,
                        ),
                      )
                    : Text(
                        widget.productId == null
                            ? "Tambah Barang"
                            : "Simpan Perubahan",
                        style: const TextStyle(
                          color: MpusTheme.textDarkColor,
                          fontSize: 15,
                          fontFamily: "Roboto",
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TAMBAH GAMBAR (Maks 3)
                _buildLabel("Tambah Gambar (Maks. 3)"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._existingImageUrls.map(
                      (url) => Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => setState(() => _existingImageUrls.remove(url)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._productImages.map(
                      (file) => Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: FileImage(file),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => setState(() => _productImages.remove(file)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_existingImageUrls.length + _productImages.length < 3)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: MpusTheme.textSecondaryColor,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_outlined,
                            color: Color(0xFF8F8F8F),
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. KATEGORI BARANG
                _buildLabel("Kategori Barang"),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isExpanded: true,
                      items: _categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 14,
                              color: MpusTheme.textDarkColor,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. NAMA BARANG
                _buildLabel("Nama Barang"),
                _buildTextField(
                  controller: _nameController,
                  hintText: "misal: Buku Kalkulus Edisi 9 / Keyboard RGB",
                ),
                const SizedBox(height: 16),

                // 4. HARGA
                _buildLabel("Harga"),
                _buildTextField(
                  controller: _priceController,
                  hintText: "Rp 50.000",
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CurrencyInputFormatter(),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. DESKRIPSI
                _buildLabel("Deskripsi"),
                _buildTextField(
                  controller: _descController,
                  hintText: "Jelaskan kondisi barang, kelengkapan, garansi, atau tempat yang cocok untuk COD...",
                  maxLines: 4,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8F8F8F),
          fontFamily: "Roboto",
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          color: MpusTheme.textDarkColor,
          fontSize: 14,
          fontFamily: "Roboto",
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: MpusTheme.textSecondaryColor,
            fontSize: 13,
            fontFamily: "Roboto",
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    int value = int.parse(digits);
    String formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );

    String newText = 'Rp $formatted';

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
