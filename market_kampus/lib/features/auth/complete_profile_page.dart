import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/ocr_api_service.dart';
import '../../data/services/firebase_notification_service.dart';
import '../catalog/home_page.dart';
import 'login_page.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _nimController = TextEditingController();
  final _phoneController = TextEditingController();
  final _campusController = TextEditingController(text: 'UNUGIRI');
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final OcrApiService _ocrApiService = OcrApiService();

  File? _ktmImage;
  bool _isLoading = false;
  bool _isOcrProcessing = false;
  String? _ocrStatusBadge;
  bool _isAutoVerified = false;

  @override
  void dispose() {
    _nimController.dispose();
    _phoneController.dispose();
    _campusController.dispose();
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
              if (result.campusName != null && _campusController.text.isEmpty) {
                _campusController.text = result.campusName!;
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

  Future<void> _submitCompletion() async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi tidak valid, silakan masuk ulang')),
      );
      return;
    }

    final nim = _nimController.text.trim();
    final phone = _phoneController.text.trim();
    final campus = _campusController.text.trim();

    if (nim.isEmpty || phone.isEmpty || _ktmImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi NIM, No. WhatsApp & Foto KTM')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload KTM to Supabase Storage & Update Verification Status
      await _profileService.submitKtmVerification(
        userId: currentUserId,
        ktmFile: _ktmImage!,
        studentNim: nim,
        campusName: campus.isNotEmpty ? campus : null,
        isAutoVerified: _isAutoVerified,
      );

      // 2. Update Phone & Profile Info
      await _profileService.updateProfile(
        userId: currentUserId,
        phone: phone,
        nim: nim,
        campusName: campus.isNotEmpty ? campus : null,
      );

      // 3. Sync FCM Token
      await FirebaseNotificationService().syncTokenToProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil berhasil dilengkapi!')),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double scaleW = screenWidth / 412;

    return Scaffold(
      backgroundColor: MpusTheme.primaryColor,
      body: SingleChildScrollView(
        child: SizedBox(
          height: 960 * scaleW,
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
                top: 140 * scaleW,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30 * scaleW),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 336 * scaleW,
                      height: 680 * scaleW,
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
                            "Lengkapi Data",
                            style: TextStyle(
                              fontSize: 32 * scaleW,
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.w700,
                              color: MpusTheme.textSecondaryColor,
                            ),
                          ),
                          SizedBox(height: 25 * scaleW),

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

                          // Campus
                          SizedBox(
                            width: 250 * scaleW,
                            height: 36 * scaleW,
                            child: TextField(
                              controller: _campusController,
                              style: TextStyle(
                                color: MpusTheme.textPrimaryColor,
                                fontSize: 14 * scaleW,
                                fontFamily: "Roboto",
                              ),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: _inputStyle('Nama Kampus', scaleW),
                            ),
                          ),
                          SizedBox(height: 18 * scaleW),

                          // Foto KTM
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
                          SizedBox(height: 20 * scaleW),

                          // Button Simpan
                          SizedBox(
                            width: 140 * scaleW,
                            height: 35 * scaleW,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submitCompletion,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD9D9D9),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30 * scaleW),
                                  side: BorderSide.none,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8F8F8F)),
                                    )
                                  : Text(
                                      "Simpan",
                                      style: TextStyle(
                                        color: const Color(0xFF8F8F8F),
                                        fontSize: 16 * scaleW,
                                        fontFamily: "Roboto",
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          SizedBox(height: 18 * scaleW),

                          // Switch Account / Logout
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Ingin ganti akun? ",
                                style: TextStyle(
                                  color: MpusTheme.textSecondaryColor,
                                  fontFamily: "Roboto",
                                  fontSize: 14 * scaleW,
                                ),
                              ),
                              GestureDetector(
                                onTap: _logout,
                                child: Text(
                                  "Keluar",
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
