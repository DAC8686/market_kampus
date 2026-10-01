import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/mpus_theme.dart';
import '../../data/services/auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _passBaruController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _passBaruController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _prosesGantiPassword() async {
    final passBaru = _passBaruController.text.trim();
    final confirmPass = _confirmPassController.text.trim();

    if (passBaru.isEmpty || confirmPass.isEmpty) {
      _showSnackBar("Semua kolom harus diisi");
      return;
    }

    if (passBaru.length < 6) {
      _showSnackBar("Kata sandi baru minimal 6 karakter");
      return;
    }

    if (passBaru != confirmPass) {
      _showSnackBar("Konfirmasi kata sandi baru tidak cocok");
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updatePassword(passBaru);

      if (mounted) {
        _showSnackBar("Kata sandi berhasil diperbarui!");
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar("Gagal mengganti kata sandi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String pesan) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  Widget _buildField(String label, TextEditingController controller, bool isPass) {
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
              obscureText: isPass,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          "Ganti Kata Sandi",
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
            _buildField("Kata Sandi Baru", _passBaruController, true),
            _buildField("Konfirmasi Kata Sandi Baru", _confirmPassController, true),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MpusTheme.tealDark,
                      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _prosesGantiPassword,
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
