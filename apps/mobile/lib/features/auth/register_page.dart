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
import 'complete_profile_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

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

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isOcrProcessing = false;
  String? _ocrStatusBadge;
  bool _isAutoVerified = false;

  File? _ktmImage;

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
      aspectRatio: const CropAspectRatio(ratioX: 2.0, ratioY: 1.0),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Posisi KTM',
          toolbarColor: MpusTheme.primaryColor,
          toolbarWidgetColor: Colors.black87,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Sesuaikan Posisi KTM',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _ktmImage = File(croppedFile.path);
        _isOcrProcessing = true;
        _ocrStatusBadge = 'Memindai KTM...';
      });

      // Background OCR Auto-fill
      try {
        final result = await _ocrApiService.verifyKtmImage(imageFile: _ktmImage!);
        if (mounted) {
          setState(() {
            _isOcrProcessing = false;
            if (result.success) {
              _isAutoVerified = true;
              _ocrStatusBadge = 'KTM Terverifikasi (${result.campusName ?? "Kampus"})';
              if (result.studentNim != null && _nimController.text.isEmpty) {
                _nimController.text = result.studentNim!;
              }
              if (result.studentName != null && _usernameController.text.isEmpty) {
                _usernameController.text = result.studentName!;
              }
            } else {
              _isAutoVerified = false;
              _ocrStatusBadge = 'KTM Siap Diupload';
            }
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isOcrProcessing = false;
            _ocrStatusBadge = 'KTM Siap Diupload';
          });
        }
      }
    }
  }

  Future<void> _signUp() async {
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

    // Sanitize phone number
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.isNotEmpty && !cleanPhone.startsWith('62')) {
      cleanPhone = '62$cleanPhone';
    }

    setState(() => _isLoading = true);

    try {
      final response = await _authService.signUp(
        email: emailInput,
        password: password,
        name: name,
        phone: cleanPhone,
      );

      // Pastikan ada sesi aktif untuk operasi upload KTM & update profil
      if (_authService.currentUser == null) {
        try {
          await _authService.signIn(email: emailInput, password: password);
        } catch (_) {}
      }

      final currentUid = _authService.currentUserId ?? response.user?.id;
      if (currentUid != null) {
        if (_ktmImage != null) {
          try {
            await _profileService.submitKtmVerification(
              userId: currentUid,
              ktmFile: _ktmImage!,
              studentNim: nim,
              campusName: "Kampus",
              isAutoVerified: _isAutoVerified,
            );
          } catch (uploadErr) {
            debugPrint("KTM upload warning: $uploadErr");
          }
        }

        try {
          await _profileService.updateProfile(
            userId: currentUid,
            name: name,
            email: emailInput,
            phone: cleanPhone,
            nim: nim,
            campusName: "Kampus",
          );
        } catch (profileErr) {
          debugPrint("Profile update warning: $profileErr");
        }

        // Sync FCM token
        await FirebaseNotificationService().syncTokenToProfile();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pendaftaran Berhasil! Silakan Masuk.")),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mendaftar: ${e.toString().replaceAll('AuthException: ', '')}")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final response = await _authService.signInWithGoogle();
      final user = response.user;

      if (user != null) {
        await FirebaseNotificationService().syncTokenToProfile();

        final isComplete = await _profileService.isProfileComplete(user.id);
        if (!mounted) return;
        if (isComplete) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompleteProfilePage()),
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
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleW = screenWidth / 412;
    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: 1000 * scaleW,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned(
                left: 157 * scaleW,
                top: 400 * scaleW,
                child: SvgPicture.asset(
                  'assets/LogoMpus.svg',
                  width: 98 * scaleW,
                  height: 119 * scaleW,
                  colorFilter: const ColorFilter.mode(
                    MpusTheme.textSecondaryColor,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              Positioned(
                left: 38 * scaleW,
                top: 130 * scaleW,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30 * scaleW),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 336 * scaleW,
                      height: 740 * scaleW,
                      padding: EdgeInsets.only(
                        top: 5 * scaleW,
                        left: 25 * scaleW,
                        right: 25 * scaleW,
                        bottom: 5 * scaleW,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30 * scaleW),
                        border: Border.all(
                          color: const Color(0xFFD9D9D9).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Daftar",
                            style: TextStyle(
                              fontSize: 36 * scaleW,
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.w700,
                              color: MpusTheme.textSecondaryColor,
                            ),
                          ),
                          SizedBox(height: 20 * scaleW),
                          // Username
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _usernameController,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle('Username / Nama Toko', scaleW),
                            ),
                          ),
                          SizedBox(height: 14 * scaleW),

                          // Email
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle('Email', scaleW),
                            ),
                          ),
                          SizedBox(height: 14 * scaleW),

                          // NIM
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _nimController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle('NIM', scaleW),
                            ),
                          ),
                          SizedBox(height: 14 * scaleW),

                          // Phone
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle(
                                'No. WhatsApp',
                                scaleW,
                                prefixText: '62 ',
                                prefixStyle: TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 14 * scaleW,
                                  fontFamily: "Roboto",
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 14 * scaleW),

                          // Password
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle('Password', scaleW),
                            ),
                          ),
                          SizedBox(height: 18 * scaleW),

                          GestureDetector(
                            onTap: _pickKTM,
                            child: Container(
                              width: 250 * scaleW,
                              height: 100 * scaleW,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15 * scaleW),
                              ),
                              child: _ktmImage != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(15 * scaleW),
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
                                              borderRadius: BorderRadius.circular(15 * scaleW),
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
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_a_photo,
                                          color: MpusTheme.textSecondaryColor,
                                          size: 32 * scaleW,
                                        ),
                                        SizedBox(height: 6 * scaleW),
                                        Text(
                                          "Upload Foto KTM (Validasi AI)",
                                          style: TextStyle(
                                            color: MpusTheme.textSecondaryColor,
                                            fontFamily: "Roboto",
                                            fontSize: 13 * scaleW,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          SizedBox(height: 16 * scaleW),
                          // Button Daftar
                          SizedBox(
                            width: 140 * scaleW,
                            height: 35 * scaleW,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD9D9D9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30 * scaleW),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8F8F8F)),
                                    )
                                  : Text(
                                      "Daftar",
                                      style: TextStyle(
                                        color: const Color(0xFF8F8F8F),
                                        fontSize: 16 * scaleW,
                                        fontFamily: "Roboto",
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 10 * scaleW),

                          // Google Sign In Shortcut
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: OutlinedButton.icon(
                              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFE0E0E0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25 * scaleW),
                                ),
                              ),
                              icon: _isGoogleLoading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.g_mobiledata_rounded, color: Color(0xFFEA4335), size: 24),
                              label: Text(
                                "Daftar dengan Google",
                                style: TextStyle(
                                  color: MpusTheme.textPrimaryColor,
                                  fontSize: 13 * scaleW,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: "Roboto",
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: 10 * scaleW),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Sudah memiliki akun? ",
                                style: TextStyle(
                                  color: MpusTheme.textSecondaryColor,
                                  fontFamily: "Roboto",
                                  fontSize: 14 * scaleW,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "Masuk",
                                  style: TextStyle(
                                    fontFamily: "Roboto",
                                    color: MpusTheme.accentBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14 * scaleW,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(
    String label,
    double scaleW, {
    String? prefixText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      floatingLabelStyle: TextStyle(
        color: const Color(0xFF8F8F8F),
        fontSize: 14 * scaleW,
        fontFamily: "Roboto",
      ),
      labelStyle: TextStyle(
        color: MpusTheme.textSecondaryColor,
        fontSize: 14 * scaleW,
        fontFamily: "Roboto",
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 18 * scaleW,
        vertical: 6 * scaleW,
      ),
      prefixText: prefixText,
      prefixStyle: prefixStyle,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25 * scaleW),
        borderSide: BorderSide.none,
      ),
    );
  }
}
