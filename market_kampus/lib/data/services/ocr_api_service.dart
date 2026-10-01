import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';

class KTMVerificationResult {
  final bool success;
  final String status;
  final String? studentName;
  final String? studentNim;
  final String? campusName;
  final double confidenceScore;
  final String rawText;
  final String? errorMessage;

  KTMVerificationResult({
    required this.success,
    required this.status,
    this.studentName,
    this.studentNim,
    this.campusName,
    this.confidenceScore = 0.0,
    this.rawText = '',
    this.errorMessage,
  });

  factory KTMVerificationResult.fromJson(Map<String, dynamic> json) {
    return KTMVerificationResult(
      success: json['success'] ?? false,
      status: json['status'] ?? 'UNKNOWN',
      studentName: json['student_name'],
      studentNim: json['student_nim'],
      campusName: json['campus_name'],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      rawText: json['raw_text'] ?? '',
      errorMessage: json['error_message'],
    );
  }

  factory KTMVerificationResult.failure(String message) {
    return KTMVerificationResult(
      success: false,
      status: 'REJECTED',
      errorMessage: message,
    );
  }
}

class OcrApiService {
  final String baseUrl;
  final http.Client _httpClient;

  OcrApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.ocrServiceBaseUrl,
        _httpClient = client ?? http.Client();

  // Verify KTM by uploading an image file directly to the Python OCR Microservice
  Future<KTMVerificationResult> verifyKtmImage({
    required File imageFile,
    String? expectedName,
    String? expectedCampus,
  }) async {
    // List candidate URLs: default base, plus emulator / localhost fallbacks
    final candidateUrls = <String>{
      baseUrl,
      'http://127.0.0.1:8000',
      'http://10.0.2.2:8000',
    }.toList();

    for (final host in candidateUrls) {
      try {
        final uri = Uri.parse('$host/api/v1/verify-upload');
        final request = http.MultipartRequest('POST', uri);

        final bytes = await imageFile.readAsBytes();
        final filename = imageFile.path.split('/').last;

        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: filename),
        );

        if (expectedName != null && expectedName.isNotEmpty) {
          request.fields['expected_name'] = expectedName;
        }
        if (expectedCampus != null && expectedCampus.isNotEmpty) {
          request.fields['expected_campus'] = expectedCampus;
        }

        final streamedResponse = await _httpClient.send(request).timeout(
          const Duration(seconds: 6),
        );

        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          return KTMVerificationResult.fromJson(data);
        }
      } catch (e) {
        debugPrint('OcrApiService attempt to $host failed: $e');
        // Continue to next candidate URL
      }
    }

    // Graceful fallback if OCR service is offline or unreachable
    return KTMVerificationResult(
      success: false,
      status: 'PENDING_REVIEW',
      errorMessage: 'Microservice OCR tidak dapat dijangkau. KTM akan ditinjau secara manual.',
    );
  }

  // Check health of OCR service
  Future<bool> checkHealth() async {
    for (final host in [baseUrl, 'http://127.0.0.1:8000', 'http://10.0.2.2:8000']) {
      try {
        final uri = Uri.parse('$host/health');
        final response = await _httpClient.get(uri).timeout(const Duration(seconds: 2));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }
}
