import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/config/supabase_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException(code: $statusCode, message: $message)';
}

class GatewayApiClient {
  static final GatewayApiClient _instance = GatewayApiClient._internal();
  factory GatewayApiClient() => _instance;
  GatewayApiClient._internal();

  final http.Client _client = http.Client();

  // Candidate Base URLs:
  // 1. Localhost via ADB reverse (127.0.0.1:8090)
  // 2. Android Emulator (10.0.2.2:8090)
  // 3. Production Cloud Gateway (mpus.daczdev.id)
  static const List<String> candidateBaseUrls = [
    'http://127.0.0.1:8090',
    'http://10.0.2.2:8090',
    'https://mpus.daczdev.id',
  ];

  String? _activeBaseUrl;
  final Duration _defaultTimeout = const Duration(seconds: 20);

  String get activeBaseUrl => _activeBaseUrl ?? candidateBaseUrls.first;

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    try {
      final token = SupabaseConfig.client.auth.currentSession?.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {}

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<dynamic> _requestWithFallback({
    required String method,
    required String path,
    Map<String, dynamic>? queryParams,
    dynamic body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) async {
    final timeoutDuration = timeout ?? _defaultTimeout;
    final headers = _buildHeaders(extraHeaders: extraHeaders);
    final String? bodyJson = body != null ? jsonEncode(body) : null;

    final hostsToTry = <String>[];
    if (_activeBaseUrl != null) {
      hostsToTry.add(_activeBaseUrl!);
    }
    for (final host in candidateBaseUrls) {
      if (!hostsToTry.contains(host)) {
        hostsToTry.add(host);
      }
    }

    String lastErrorMessage = 'Unknown network error';
    int lastStatusCode = 500;

    for (final base in hostsToTry) {
      try {
        final uri = _buildUri(base, path, queryParams);
        http.Response response;

        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(uri, headers: headers).timeout(timeoutDuration);
            break;
          case 'POST':
            response = await _client.post(uri, headers: headers, body: bodyJson).timeout(timeoutDuration);
            break;
          case 'PUT':
            response = await _client.put(uri, headers: headers, body: bodyJson).timeout(timeoutDuration);
            break;
          case 'PATCH':
            response = await _client.patch(uri, headers: headers, body: bodyJson).timeout(timeoutDuration);
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: headers, body: bodyJson).timeout(timeoutDuration);
            break;
          default:
            throw UnsupportedError('Unsupported HTTP method: $method');
        }

        _activeBaseUrl = base;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (response.body.isEmpty) return null;
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
                return decoded['data'];
              }
              if (decoded.containsKey('data') && decoded['data'] is List) {
                return decoded['data'];
              }
            }
            return decoded;
          } catch (_) {
            return response.body;
          }
        } else {
          lastStatusCode = response.statusCode;
          try {
            final errBody = jsonDecode(response.body);
            lastErrorMessage = errBody['error']?.toString() ??
                errBody['message']?.toString() ??
                errBody['detail']?.toString() ??
                'HTTP $lastStatusCode';
          } catch (_) {
            lastErrorMessage = response.body.isNotEmpty ? response.body : 'HTTP $lastStatusCode';
          }

          if (response.statusCode >= 400 && response.statusCode < 500) {
            throw ApiException(
              statusCode: response.statusCode,
              message: lastErrorMessage,
            );
          }
        }
      } on SocketException catch (e) {
        lastErrorMessage = 'Connection refused to $base: ${e.message}';
      } on TimeoutException {
        lastErrorMessage = 'Request timed out on $base';
      } on ApiException {
        rethrow;
      } catch (e) {
        lastErrorMessage = 'Request failed on $base: $e';
      }
    }

    throw ApiException(
      statusCode: lastStatusCode,
      message: 'Gateway unreachable. Last error: $lastErrorMessage',
    );
  }

  Uri _buildUri(String base, String path, Map<String, dynamic>? queryParams) {
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParams == null || queryParams.isEmpty) {
      return Uri.parse(fullUrl);
    }

    final queryMap = <String, String>{};
    queryParams.forEach((key, value) {
      if (value != null) {
        queryMap[key] = value.toString();
      }
    });

    return Uri.parse(fullUrl).replace(queryParameters: queryMap);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _requestWithFallback(
        method: 'GET',
        path: path,
        queryParams: queryParams,
        extraHeaders: extraHeaders,
        timeout: timeout,
      );

  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _requestWithFallback(
        method: 'POST',
        path: path,
        body: body,
        queryParams: queryParams,
        extraHeaders: extraHeaders,
        timeout: timeout,
      );

  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _requestWithFallback(
        method: 'PUT',
        path: path,
        body: body,
        queryParams: queryParams,
        extraHeaders: extraHeaders,
        timeout: timeout,
      );

  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _requestWithFallback(
        method: 'PATCH',
        path: path,
        body: body,
        queryParams: queryParams,
        extraHeaders: extraHeaders,
        timeout: timeout,
      );

  Future<dynamic> delete(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) =>
      _requestWithFallback(
        method: 'DELETE',
        path: path,
        body: body,
        queryParams: queryParams,
        extraHeaders: extraHeaders,
        timeout: timeout,
      );
}
