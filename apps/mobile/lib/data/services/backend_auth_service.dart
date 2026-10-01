import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendAuthResult {
  final bool success;
  final String message;
  final String? campusName;
  final String? studentNim;
  final String? email;

  BackendAuthResult({
    required this.success,
    required this.message,
    this.campusName,
    this.studentNim,
    this.email,
  });

  factory BackendAuthResult.fromJson(Map<String, dynamic> json) {
    return BackendAuthResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? 'Berhasil diproses',
      campusName: json['campus_name']?.toString(),
      studentNim: json['student_nim']?.toString(),
      email: json['email']?.toString(),
    );
  }

  factory BackendAuthResult.failure(String message) {
    return BackendAuthResult(
      success: false,
      message: message,
    );
  }
}

class BackendAuthService {
  final List<String> candidateUrls = [
    'https://mpus.daczdev.id',   // Cloud Production Vercel
    'http://127.0.0.1:8090',     // Golang Gateway via USB ADB Reverse
    'http://127.0.0.1:8000',     // Python Microservice via USB ADB Reverse
    'http://100.64.159.25:8090', // Tailscale
    'http://10.11.111.225:8090', // Local LAN
    'http://10.0.2.2:8090',      // Android Emulator
  ];

  final http.Client _client = http.Client();

  // 1. Registrasi Akun Mahasiswa + AI KTM Validation + Kirim Email OTP Resmi
  Future<BackendAuthResult> registerWithKtm({
    required String name,
    required String email,
    required String password,
    required String nim,
    required String phone,
    required File ktmFile,
  }) async {
    String lastError = "Gagal menghubungi server backend Mpus.";

    for (final host in candidateUrls) {
      try {
        final uri = Uri.parse('$host/api/v1/auth/register-ktm');
        final request = http.MultipartRequest('POST', uri);

        request.fields['name'] = name.trim();
        request.fields['email'] = email.trim();
        request.fields['password'] = password;
        request.fields['nim'] = nim.trim();
        request.fields['phone'] = phone.trim();

        final bytes = await ktmFile.readAsBytes();
        final filename = ktmFile.path.split('/').last;
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

        final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          final errBody = jsonDecode(response.body);
          lastError = errBody['detail']?.toString() ?? "Pendaftaran ditolak oleh server (${response.statusCode})";
        }
      } catch (e) {
        debugPrint("BackendAuthService register attempt to $host failed: $e");
      }
    }

    return BackendAuthResult.failure(lastError);
  }

  // 2. Verifikasi 6-Digit OTP yang Dikirimkan ke Email
  Future<BackendAuthResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    String lastError = "Kode OTP tidak dapat diverifikasi.";

    for (final host in candidateUrls) {
      try {
        final uri = Uri.parse('$host/api/v1/auth/verify-otp');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          final errBody = jsonDecode(response.body);
          lastError = errBody['detail']?.toString() ?? "Kode OTP salah atau kadaluarsa";
        }
      } catch (e) {
        debugPrint("BackendAuthService verifyOtp attempt to $host failed: $e");
      }
    }

    return BackendAuthResult.failure(lastError);
  }

  // 3. Kirim Ulang OTP ke Email
  Future<BackendAuthResult> resendOtp({
    required String email,
  }) async {
    String lastError = "Gagal mengirim ulang kode OTP.";

    for (final host in candidateUrls) {
      try {
        final uri = Uri.parse('$host/api/v1/auth/resend-otp');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          final errBody = jsonDecode(response.body);
          lastError = errBody['detail']?.toString() ?? "Gagal mengirim ulang OTP";
        }
      } catch (e) {
        debugPrint("BackendAuthService resendOtp attempt to $host failed: $e");
      }
    }

    return BackendAuthResult.failure(lastError);
  }
}
