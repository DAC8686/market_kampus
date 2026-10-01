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
  static const String baseUrl = 'https://mpus.daczdev.id';
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
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/register-ktm');
      final request = http.MultipartRequest('POST', uri);

      request.fields['name'] = name.trim();
      request.fields['email'] = email.trim();
      request.fields['password'] = password;
      request.fields['nim'] = nim.trim();
      request.fields['phone'] = phone.trim();

      final bytes = await ktmFile.readAsBytes();
      final filename = ktmFile.path.split('/').last;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await _client.send(request).timeout(const Duration(seconds: 40));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BackendAuthResult.fromJson(data);
      } else {
        try {
          final errBody = jsonDecode(response.body);
          final errorMsg = errBody['detail']?.toString() ?? "Pendaftaran ditolak oleh server (${response.statusCode})";
          return BackendAuthResult.failure(errorMsg);
        } catch (_) {
          return BackendAuthResult.failure("Pendaftaran gagal (${response.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("BackendAuthService register failed: $e");
      return BackendAuthResult.failure("Gagal terhubung ke Cloud API Mpus ($e)");
    }
  }

  // 2. Verifikasi 6-Digit OTP yang Dikirimkan ke Email
  Future<BackendAuthResult> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/verify-otp');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BackendAuthResult.fromJson(data);
      } else {
        try {
          final errBody = jsonDecode(response.body);
          final errorMsg = errBody['detail']?.toString() ?? "Kode OTP salah atau kadaluarsa";
          return BackendAuthResult.failure(errorMsg);
        } catch (_) {
          return BackendAuthResult.failure("Verifikasi OTP gagal (${response.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("BackendAuthService verifyOtp failed: $e");
      return BackendAuthResult.failure("Gagal menghubungi server verifikasi ($e)");
    }
  }

  // 3. Kirim Ulang OTP ke Email
  Future<BackendAuthResult> resendOtp({
    required String email,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/resend-otp');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return BackendAuthResult.fromJson(data);
      } else {
        try {
          final errBody = jsonDecode(response.body);
          final errorMsg = errBody['detail']?.toString() ?? "Gagal mengirim ulang OTP";
          return BackendAuthResult.failure(errorMsg);
        } catch (_) {
          return BackendAuthResult.failure("Gagal mengirim ulang OTP (${response.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("BackendAuthService resendOtp failed: $e");
      return BackendAuthResult.failure("Gagal menghubungi server untuk kirim ulang OTP ($e)");
    }
  }
}
