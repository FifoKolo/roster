import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for managing HTTPS API endpoints for data export and PDF generation
/// Handles communication with backend servers for secure data transmission
class HttpsExportApiService {
  final String apiBaseUrl;
  final String apiKey;
  final String? webhookUrl;

  HttpsExportApiService({
    required this.apiBaseUrl,
    required this.apiKey,
    this.webhookUrl,
  });

  /// Send roster data to backend for export and PDF generation
  Future<Map<String, dynamic>> exportAndGeneratePdf(
    Map<String, dynamic> jsonData, {
    bool generatePdf = true,
    bool downloadJson = true,
    String? pdfFilename,
  }) async {
    try {
      final endpoint = '$apiBaseUrl/export';

      final payload = {
        'data': jsonData,
        'options': {
          'generatePdf': generatePdf,
          'downloadJson': downloadJson,
          'pdfFilename': pdfFilename,
        },
        'timestamp': DateTime.now().toIso8601String(),
        'webhookUrl': webhookUrl,
      };

      final response = await _sendSecureRequest(
        endpoint,
        payload,
        method: 'POST',
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        return {
          'status': 'success',
          'message': 'Export request processed',
          'data': response['body'],
        };
      } else {
        return {
          'status': 'error',
          'message': 'Failed to process export: ${response['statusCode']}',
          'data': response['body'],
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Export request failed: $e',
      };
    }
  }

  /// Download exported file from backend
  Future<Uint8List?> downloadExportedFile(
    String exportId, {
    String fileType = 'pdf', // 'pdf' or 'json'
  }) async {
    try {
      final endpoint = '$apiBaseUrl/export/$exportId/download?type=$fileType';

      final response = await _sendSecureRequest(
        endpoint,
        null,
        method: 'GET',
        rawResponse: true,
      );

      if (response['statusCode'] == 200) {
        return response['bodyBytes'] as Uint8List?;
      } else {
        print('❌ Download failed: ${response['statusCode']}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading file: $e');
      return null;
    }
  }

  /// Get export status
  Future<Map<String, dynamic>> getExportStatus(String exportId) async {
    try {
      final endpoint = '$apiBaseUrl/export/$exportId/status';

      final response = await _sendSecureRequest(
        endpoint,
        null,
        method: 'GET',
      );

      if (response['statusCode'] == 200) {
        return jsonDecode(response['body']) as Map<String, dynamic>;
      } else {
        return {
          'status': 'error',
          'message': 'Failed to get status: ${response['statusCode']}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Status check failed: $e',
      };
    }
  }

  /// List all exports for the authenticated user
  Future<Map<String, dynamic>> listExports({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final endpoint =
          '$apiBaseUrl/export?limit=$limit&offset=$offset';

      final response = await _sendSecureRequest(
        endpoint,
        null,
        method: 'GET',
      );

      if (response['statusCode'] == 200) {
        return jsonDecode(response['body']) as Map<String, dynamic>;
      } else {
        return {
          'status': 'error',
          'message': 'Failed to list exports: ${response['statusCode']}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'List request failed: $e',
      };
    }
  }

  /// Delete export from backend
  Future<bool> deleteExport(String exportId) async {
    try {
      final endpoint = '$apiBaseUrl/export/$exportId';

      final response = await _sendSecureRequest(
        endpoint,
        null,
        method: 'DELETE',
      );

      return response['statusCode'] == 200;
    } catch (e) {
      print('❌ Error deleting export: $e');
      return false;
    }
  }

  /// Batch export multiple rosters
  Future<Map<String, dynamic>> batchExport(
    List<Map<String, dynamic>> rosterDataList,
  ) async {
    try {
      final endpoint = '$apiBaseUrl/export/batch';

      final payload = {
        'exports': rosterDataList,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _sendSecureRequest(
        endpoint,
        payload,
        method: 'POST',
      );

      if (response['statusCode'] == 200 || response['statusCode'] == 201) {
        return jsonDecode(response['body']) as Map<String, dynamic>;
      } else {
        return {
          'status': 'error',
          'message': 'Batch export failed: ${response['statusCode']}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Batch export failed: $e',
      };
    }
  }

  /// Send secure request with authentication
  Future<Map<String, dynamic>> _sendSecureRequest(
    String endpoint,
    Map<String, dynamic>? body, {
    required String method,
    bool rawResponse = false,
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final headers = _buildHeaders();

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: jsonEncode(body),
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }

      if (rawResponse) {
        return {
          'statusCode': response.statusCode,
          'bodyBytes': response.bodyBytes,
          'body': response.body,
        };
      }

      return {
        'statusCode': response.statusCode,
        'body': response.body,
        'headers': response.headers,
      };
    } catch (e) {
      print('❌ Request failed: $e');
      rethrow;
    }
  }

  /// Build secure headers with authentication
  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'User-Agent': 'RosterApp/1.0',
      'X-Request-ID': _generateRequestId(),
    };
  }

  /// Generate unique request ID for tracking
  String _generateRequestId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 10000).toString().padLeft(4, '0')}';
  }

  /// Validate API connectivity
  Future<bool> validateConnection() async {
    try {
      final endpoint = '$apiBaseUrl/health';
      final response = await http.get(
        Uri.parse(endpoint),
        headers: _buildHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Connection validation failed: $e');
      return false;
    }
  }
}

/// Configuration class for HTTPS export settings
class HttpsExportConfig {
  final String apiBaseUrl;
  final String apiKey;
  final String? webhookUrl;
  final Duration timeout;
  final bool enableLogging;
  final Map<String, String>? customHeaders;

  const HttpsExportConfig({
    required this.apiBaseUrl,
    required this.apiKey,
    this.webhookUrl,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = true,
    this.customHeaders,
  });

  /// Create from environment variables
  factory HttpsExportConfig.fromEnv() {
    // In a real app, use 'dotenv' package to load from .env file
    return HttpsExportConfig(
      apiBaseUrl: String.fromEnvironment('HTTPS_API_URL',
          defaultValue: 'https://api.example.com'),
      apiKey: String.fromEnvironment('HTTPS_API_KEY',
          defaultValue: ''),
      webhookUrl: String.fromEnvironment('WEBHOOK_URL'),
      enableLogging: bool.fromEnvironment('ENABLE_LOGGING',
          defaultValue: true),
    );
  }

  /// Validate configuration
  bool isValid() {
    return apiBaseUrl.isNotEmpty &&
        apiKey.isNotEmpty &&
        apiBaseUrl.startsWith('https://');
  }
}
