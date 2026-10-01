import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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
  // 1. USB ADB Reverse (Fast local dev) -> 2. Cloud Production Vercel
  static const List<String> candidateUrls = [
    'http://127.0.0.1:8000',
    'https://mpus.daczdev.id',
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
    String lastError = "Gagal menghubungi server backend.";

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
        final isPng = filename.toLowerCase().endsWith('.png');
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: MediaType('image', isPng ? 'png' : 'jpeg'),
        ));

        final streamed = await _client.send(request).timeout(const Duration(seconds: 20));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          try {
            final errBody = jsonDecode(response.body);
            lastError = errBody['detail']?.toString() ?? "Pendaftaran ditolak (${response.statusCode})";
            return BackendAuthResult.failure(lastError);
          } catch (_) {
            lastError = "Pendaftaran gagal (${response.statusCode})";
          }
        }
      } catch (e) {
        debugPrint("BackendAuthService attempt to $host failed: $e");
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
          body: jsonEncode({'email': email.trim().toLowerCase(), 'otp': otp.trim().replaceAll(' ', '')}),
        ).timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          try {
            final errBody = jsonDecode(response.body);
            lastError = errBody['detail']?.toString() ?? "Kode OTP salah atau kadaluarsa";
            return BackendAuthResult.failure(lastError);
          } catch (_) {
            lastError = "Verifikasi OTP gagal (${response.statusCode})";
          }
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
          body: jsonEncode({'email': email.trim().toLowerCase()}),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return BackendAuthResult.fromJson(data);
        } else {
          try {
            final errBody = jsonDecode(response.body);
            lastError = errBody['detail']?.toString() ?? "Gagal mengirim ulang OTP";
            return BackendAuthResult.failure(lastError);
          } catch (_) {
            lastError = "Gagal mengirim ulang OTP (${response.statusCode})";
          }
        }
      } catch (e) {
        debugPrint("BackendAuthService resendOtp attempt to $host failed: $e");
      }
    }

    return BackendAuthResult.failure(lastError);
  }
}
