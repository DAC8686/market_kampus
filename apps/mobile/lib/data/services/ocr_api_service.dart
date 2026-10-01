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
    final extracted = json['extracted_data'] is Map<String, dynamic>
        ? json['extracted_data'] as Map<String, dynamic>
        : null;
    final bool isSuccess = json['success'] == true ||
        json['is_valid'] == true ||
        json['status'] == 'SUCCESS' ||
        json['status'] == 'VERIFIED' ||
        json['status'] == 'REVIEW';

    String? foundNim = json['student_nim']?.toString() ??
        extracted?['detected_nim']?.toString() ??
        json['detected_nim']?.toString();
    if (foundNim != null && (foundNim == 'null' || foundNim.trim().isEmpty)) {
      foundNim = null;
    }

    String? foundName = json['student_name']?.toString() ??
        extracted?['detected_name']?.toString() ??
        json['detected_name']?.toString();
    if (foundName != null && (foundName == 'null' || foundName.trim().isEmpty)) {
      foundName = null;
    }

    String? foundCampus = json['campus_name']?.toString() ??
        extracted?['detected_university']?.toString() ??
        json['detected_university']?.toString();
    if (foundCampus != null && (foundCampus == 'null' || foundCampus.trim().isEmpty)) {
      foundCampus = null;
    }

    return KTMVerificationResult(
      success: isSuccess,
      status: json['status']?.toString() ?? 'SUCCESS',
      studentName: foundName,
      studentNim: foundNim,
      campusName: foundCampus,
      confidenceScore: (json['confidence_score'] ?? extracted?['confidence_score'] as num?)?.toDouble() ?? 0.95,
      rawText: json['raw_text']?.toString() ?? extracted?['raw_text']?.toString() ?? '',
      errorMessage: json['error_message']?.toString() ?? json['message']?.toString(),
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
    String? expectedNim,
    String? expectedName,
    String? expectedCampus,
  }) async {
    // List candidate URLs: Production Vercel cloud domain first, followed by fallbacks
    final candidateUrls = <String>{
      'https://mpus.daczdev.id', // Production Vercel Serverless
      baseUrl,
      'http://100.64.159.25:8000', // Tailscale Dev Host
      'http://10.11.111.225:8000', // Local LAN Dev Host
      'http://10.0.2.2:8000',
      'http://127.0.0.1:8000',
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

        if (expectedNim != null && expectedNim.isNotEmpty) {
          request.fields['expected_nim'] = expectedNim;
        }
        if (expectedName != null && expectedName.isNotEmpty) {
          request.fields['expected_name'] = expectedName;
        }
        if (expectedCampus != null && expectedCampus.isNotEmpty) {
          request.fields['expected_campus'] = expectedCampus;
        }

        final streamedResponse = await _httpClient.send(request).timeout(
          const Duration(seconds: 25),
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
    for (final host in [baseUrl, 'https://mpus.daczdev.id', 'http://10.0.2.2:8000', 'http://127.0.0.1:8000']) {
      try {
        final uri = Uri.parse('$host/health');
        final response = await _httpClient.get(uri).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) return true;
      } catch (_) {}
    }
    return false;
  }
}
