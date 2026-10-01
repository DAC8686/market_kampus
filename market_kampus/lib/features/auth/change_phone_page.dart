import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/profile_service.dart';

class ChangePhonePage extends StatefulWidget {
  const ChangePhonePage({super.key});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final _noHpController = TextEditingController();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPhone();
  }

  @override
  void dispose() {
    _noHpController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPhone() async {
    final userId = _authService.currentUserId;
    if (userId != null) {
      final profile = await _profileService.getProfile(userId);
      if (profile != null && profile['phone'] != null) {
        _noHpController.text = profile['phone'];
      }
    }
  }

  Future<void> _prosesGantiNoHp() async {
    final noHpInput = _noHpController.text.trim();

    if (noHpInput.isEmpty) {
      _showSnackBar("Nomor WhatsApp tidak boleh kosong");
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      _showSnackBar("Sesi pengguna tidak valid, silakan login ulang");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _profileService.updateProfile(
        userId: userId,
        phone: noHpInput,
      );

      if (mounted) {
        _showSnackBar("Nomor WhatsApp berhasil diperbarui!");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Gagal mengupdate nomor WhatsApp: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Widget _buildCustomTextField(String label, TextEditingController controller, {String? hintText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: MpusTheme.textDarkColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: GoogleFonts.roboto(color: Colors.black87, fontSize: 15),
              decoration: InputDecoration(
                hintText: hintText ?? 'Contoh: 081234567890',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MpusTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Ganti No. WhatsApp",
          style: GoogleFonts.plusJakartaSans(
            color: MpusTheme.textDarkColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MpusTheme.textDarkColor, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildCustomTextField("Nomor WhatsApp Baru", _noHpController, hintText: "08xxxxxxxxxx"),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MpusTheme.tealDark,
                      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _prosesGantiNoHp,
                    child: Text(
                      "SIMPAN",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
