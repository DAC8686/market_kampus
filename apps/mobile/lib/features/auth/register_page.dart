import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/firebase_notification_service.dart';
import '../../data/services/ocr_api_service.dart';
import '../catalog/home_page.dart';
import 'validation_waiting_page.dart';

class RegisterPage extends StatefulWidget {
  final String? initialEmail;
  final String? initialName;

  const RegisterPage({
    super.key,
    this.initialEmail,
    this.initialName,
  });

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nimController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final OcrApiService _ocrApiService = OcrApiService();

  bool _isGoogleLoading = false;
  bool _isOcrProcessing = false;
  String? _ocrStatusBadge;
  double? _ktmAspectRatio;

  File? _ktmImage;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _usernameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _nimController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickKTM() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Batas KTM (Portrait / Landscape)',
          toolbarColor: MpusTheme.primaryColor,
          toolbarWidgetColor: Colors.black87,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          hideBottomControls: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.square,
          ],
        ),
        IOSUiSettings(
          title: 'Sesuaikan Batas KTM',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );

    if (croppedFile != null) {
      final file = File(croppedFile.path);
      double aspectRatio = 16 / 9;
      try {
        final bytes = await file.readAsBytes();
        final decoded = await decodeImageFromList(bytes);
        if (decoded.height > 0) {
          aspectRatio = decoded.width / decoded.height;
        }
      } catch (_) {}

      setState(() {
        _ktmImage = file;
        _ktmAspectRatio = aspectRatio;
        _isOcrProcessing = true;
        _ocrStatusBadge = 'Memindai KTM...';
      });

      // Background OCR Auto-fill
      try {
        final result = await _ocrApiService.verifyKtmImage(
          imageFile: _ktmImage!,
          expectedNim: _nimController.text.trim().isNotEmpty ? _nimController.text.trim() : null,
          expectedName: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        );
        if (mounted) {
          setState(() {
            _isOcrProcessing = false;
            if (result.studentNim != null && result.studentNim!.isNotEmpty) {
              _ocrStatusBadge = '✓ KTM Terbaca (${result.campusName ?? "Kampus Mahasiswa"})';
              if (_nimController.text.trim().isEmpty) {
                _nimController.text = result.studentNim!;
              }
              if (result.studentName != null && _usernameController.text.trim().isEmpty) {
                _usernameController.text = result.studentName!;
              }
            } else {
              _ocrStatusBadge = 'Foto KTM Terlampir';
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isOcrProcessing = false;
            _ocrStatusBadge = 'Foto KTM Terlampir';
          });
        }
      }
    }
  }

  void _signUp() {
    final name = _usernameController.text.trim();
    final emailInput = _emailController.text.trim();
    final nim = _nimController.text.trim();
    final password = _passwordController.text.trim();
    final rawPhone = _phoneController.text.trim();

    if (name.isEmpty || emailInput.isEmpty || nim.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi semua kolom wajib (Nama, Email, NIM, Password)")),
      );
      return;
    }

    if (!emailInput.contains('@') || !emailInput.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Format email tidak valid")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password minimal 6 karakter")),
      );
      return;
    }

    if (_ktmImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap upload foto KTM terlebih dahulu untuk verifikasi identitas")),
      );
      return;
    }

    // Sanitize phone number
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    // Pindahkan ke ValidationWaitingPage untuk proses validasi AI terpadu
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ValidationWaitingPage(
          name: name,
          email: emailInput,
          nim: nim,
          phone: cleanPhone,
          password: password,
          ktmFile: _ktmImage!,
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final response = await _authService.signInWithGoogle();
      final user = response.user;

      if (user != null) {
        final profile = await _profileService.getProfile(user.id);
        final isRegistered = profile != null &&
            (profile['phone']?.toString().trim().isNotEmpty == true ||
                profile['nim']?.toString().trim().isNotEmpty == true);

        if (!mounted) return;
        if (isRegistered) {
          await FirebaseNotificationService().syncTokenToProfile();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        } else {
          // Isi kolom email & username otomatis dari data Google
          setState(() {
            _emailController.text = user.email ?? '';
            final googleName = user.userMetadata?['name']?.toString() ??
                user.userMetadata?['full_name']?.toString() ??
                '';
            if (googleName.isNotEmpty) {
              _usernameController.text = googleName;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Akun Google terhubung! Silakan lengkapi NIM, No. WhatsApp, Password, dan upload KTM."),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In: ${e.toString().replaceAll('Exception: ', '')}")),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double ktmBoxHeight = 110;

    if (_ktmAspectRatio != null && _ktmAspectRatio! > 0) {
      // Clamped between 0.55 (portrait 9:16) to 2.2 (ultra-wide landscape)
      final clampedRatio = _ktmAspectRatio!.clamp(0.55, 2.2);
      ktmBoxHeight = 280 / clampedRatio;
      if (ktmBoxHeight > 340) ktmBoxHeight = 340;
      if (ktmBoxHeight < 95) ktmBoxHeight = 95;
    }

    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/LogoMpus.svg',
                    width: 98,
                    height: 119,
                    colorFilter: const ColorFilter.mode(
                      MpusTheme.textSecondaryColor,
                      BlendMode.srcIn,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9D9D9).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFD9D9D9).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Daftar",
                              style: TextStyle(
                                fontSize: 32,
                                fontFamily: "Roboto",
                                fontWeight: FontWeight.w700,
                                color: MpusTheme.textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Username
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _usernameController,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: _inputStyle('Username / Nama Toko'),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: _inputStyle('Email'),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // NIM
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _nimController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: _inputStyle('NIM'),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Phone
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: _inputStyle(
                                  'No. WhatsApp',
                                  prefixText: '62 ',
                                  prefixStyle: const TextStyle(
                                    color: MpusTheme.textPrimaryColor,
                                    fontSize: 14,
                                    fontFamily: "Roboto",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Password
                            SizedBox(
                              height: 42,
                              child: TextField(
                                controller: _passwordController,
                                obscureText: true,
                                style: const TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14,
                                  fontFamily: "Roboto",
                                ),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: _inputStyle('Password'),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Preview & Upload KTM
                            GestureDetector(
                              onTap: _pickKTM,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                width: double.infinity,
                                height: ktmBoxHeight,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _ktmImage != null
                                        ? MpusTheme.accentBlue.withValues(alpha: 0.6)
                                        : const Color(0xFFE0E0E0),
                                    width: _ktmImage != null ? 1.5 : 1.0,
                                  ),
                                ),
                                child: _ktmImage != null
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.file(
                                              _ktmImage!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                            ),
                                          ),
                                          if (_isOcrProcessing)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: CircularProgressIndicator(color: Colors.white),
                                              ),
                                            ),
                                          if (_ocrStatusBadge != null)
                                            Positioned(
                                              bottom: 6,
                                              left: 6,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.black87,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  _ocrStatusBadge!,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo,
                                            color: MpusTheme.textSecondaryColor,
                                            size: 28,
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            "Upload Foto KTM (Validasi AI)",
                                            style: TextStyle(
                                              color: MpusTheme.textSecondaryColor,
                                              fontFamily: "Roboto",
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Button Daftar
                            SizedBox(
                              width: 150,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD9D9D9),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text(
                                  "Daftar",
                                  style: TextStyle(
                                    color: Color(0xFF8F8F8F),
                                    fontSize: 15,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Google Sign In Shortcut
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Color(0xFFE0E0E0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: _isGoogleLoading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 24),
                                label: const Text(
                                  "Daftar dengan Google",
                                  style: TextStyle(
                                    color: MpusTheme.textPrimaryColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: "Roboto",
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Sudah memiliki akun? ",
                                  style: TextStyle(
                                    color: MpusTheme.textSecondaryColor,
                                    fontFamily: "Roboto",
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Masuk",
                                    style: TextStyle(
                                      fontFamily: "Roboto",
                                      color: MpusTheme.accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(
    String label, {
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF8F8F8F),
        fontSize: 14,
        fontFamily: "Roboto",
      ),
      labelStyle: const TextStyle(
        color: MpusTheme.textSecondaryColor,
        fontSize: 14,
        fontFamily: "Roboto",
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 8,
      ),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
    );
  }
}
