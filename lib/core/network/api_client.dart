import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client() {
    final uri = Uri.parse(baseUrl);
    final isLocalDevHost =
        uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '10.0.2.2';

    if (!isLocalDevHost && uri.scheme != 'https') {
      if (kReleaseMode) {
        throw ApiException(
          message: 'Base URL insegura. En produccion debe usarse HTTPS.',
          statusCode: 0,
        );
      }
    }
  }

  final String baseUrl;
  final http.Client _httpClient;
  static const Duration _requestTimeout = Duration(seconds: 12);

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient
          .get(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw mapNetworkError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw mapNetworkError(error);
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient
          .patch(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw mapNetworkError(error);
    }
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final response = await _httpClient
          .delete(
            uri,
            headers: {'Content-Type': 'application/json', ...headers},
          )
          .timeout(_requestTimeout);

      return _handleResponse(response);
    } catch (error) {
      if (error is ApiException) {
        rethrow;
      }
      throw mapNetworkError(error);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> payload;
    try {
      payload = _decodeAsMap(response.body);
    } catch (_) {
      throw ApiException(
        message: 'Respuesta invalida del servidor (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final errorObj = payload['error'];
    final backendMessage = errorObj is Map<String, dynamic>
        ? errorObj['message']?.toString()
        : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message:
            backendMessage ??
            payload['message']?.toString() ??
            'Error de comunicacion',
        statusCode: response.statusCode,
      );
    }

    return payload;
  }

  ApiException mapNetworkError(Object error) {
    if (error is TimeoutException) {
      return ApiException(
        message: 'La solicitud excedio el tiempo de espera.',
        statusCode: 408,
      );
    }

    return ApiException(
      message: 'No fue posible conectar con el servidor.',
      statusCode: 0,
    );
  }

  Map<String, dynamic> _decodeAsMap(String body) {
    if (body.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return {};
  }
}

class ApiException implements Exception {
  ApiException({required this.message, required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }
}
