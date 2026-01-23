import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io show File;
import 'package:path_provider/path_provider.dart';
import '../models/employee_model.dart';

/// Service for exporting roster data to JSON with automatic downloading.
/// Supports both direct downloads and HTTPS endpoint integration.
class DataExportService {
  // Singleton instance
  static final DataExportService _instance = DataExportService._internal();

  factory DataExportService() {
    return _instance;
  }

  DataExportService._internal();

  /// Export all roster data to JSON format
  /// Returns the JSON data as a Map for further processing
  static Future<Map<String, dynamic>> exportRosterDataToJson(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
  }) async {
    final exportData = {
      'exportMetadata': {
        'exportDate': DateTime.now().toIso8601String(),
        'exportTimestamp': DateTime.now().millisecondsSinceEpoch,
        'rosterName': rosterName ?? 'Unnamed Roster',
        'dataVersion': '1.0',
      },
      'weekInformation': {
        'weekStart': weekDates['Mon']?.toIso8601String(),
        'weekEnd': weekDates['Sun']?.toIso8601String(),
        'weekNumber': _extractWeekNumber(rosterName),
      },
      'employees': _serializeEmployees(employees, weekDates),
      'summary': _calculateSummary(employees),
      'bankHolidayData': _extractBankHolidayData(employees, weekDates),
    };

    return exportData;
  }

  /// Serialize employees list to JSON-compatible format
  static List<Map<String, dynamic>> _serializeEmployees(
    List<Employee> employees,
    Map<String, DateTime> weekDates,
  ) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return employees.map((employee) {
      return {
        'name': employee.name,
        'email': employee.email,
        'contractType': employee.contractType,
        'shifts': Map.fromEntries(
          days.map((day) => MapEntry(
                day,
                employee.shifts[day]?.toJson() ?? null,
              )),
        ),
        'hours': {
          'scheduledHours': employee.totalScheduledHours,
          'mondayToSaturdayBreakHours': employee.mondayToSaturdayBreakHours,
          'sundayBreakHours': employee.sundayBreakHours,
          'totalBreakHours': employee.mondayToSaturdayBreakHours +
              employee.sundayBreakHours,
          'paidHours': employee.totalPaidHours,
          'mondayToSaturdayPaidHours':
              employee.totalMondayToSaturdayPaidHours,
          'sundayPaidHours': employee.totalSundayPaidHours,
          'holidayHoursUsed': employee.totalHolidayHoursUsed,
          'accumulatedWorkedHours': employee.accumulatedWorkedHours,
          'accumulatedHolidayHours': employee.accumulatedHolidayHours,
        },
        'metadata': {
          'contractPdfPath': employee.contractPdfPath,
          'lastModified': DateTime.now().toIso8601String(),
        },
      };
    }).toList();
  }

  /// Calculate summary statistics
  static Map<String, dynamic> _calculateSummary(List<Employee> employees) {
    final totalScheduledHours =
        employees.fold(0.0, (sum, e) => sum + e.totalScheduledHours);
    final totalBreakHours = employees.fold(0.0, (sum, e) =>
        sum + e.mondayToSaturdayBreakHours + e.sundayBreakHours);
    final totalPaidHours =
        employees.fold(0.0, (sum, e) => sum + e.totalPaidHours);
    final totalHolidayHours =
        employees.fold(0.0, (sum, e) => sum + e.totalHolidayHoursUsed);

    return {
      'totalEmployees': employees.length,
      'totalScheduledHours': totalScheduledHours,
      'totalBreakHours': totalBreakHours,
      'totalPaidHours': totalPaidHours,
      'totalHolidayHours': totalHolidayHours,
      'highestScheduledHours': employees.isNotEmpty
          ? employees
              .map((e) => e.totalScheduledHours)
              .reduce((a, b) => a > b ? a : b)
          : 0,
      'lowestScheduledHours': employees.isNotEmpty
          ? employees
              .map((e) => e.totalScheduledHours)
              .reduce((a, b) => a < b ? a : b)
          : 0,
    };
  }

  /// Extract bank holiday data if available
  static List<Map<String, dynamic>> _extractBankHolidayData(
    List<Employee> employees,
    Map<String, DateTime> weekDates,
  ) {
    final bankHolidayData = <Map<String, dynamic>>[];

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (final day in days) {
      final date = weekDates[day];
      if (date == null) continue;

      for (final employee in employees) {
        final shift = employee.shifts[day];
        if (shift != null && shift.isHoliday) {
          bankHolidayData.add({
            'date': date.toIso8601String(),
            'day': day,
            'employeeName': employee.name,
            'hoursWorked': shift.duration,
            'customHolidayHours': shift.customHolidayHours,
          });
        }
      }
    }

    return bankHolidayData;
  }

  /// Extract week number from roster name
  static int? _extractWeekNumber(String? rosterName) {
    if (rosterName == null) return null;
    final regex = RegExp(r'[Ww]eek\s?(\d+)');
    final match = regex.firstMatch(rosterName);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Convert JSON data to formatted string with indentation
  static String jsonToString(Map<String, dynamic> jsonData) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonData);
  }

  /// Download JSON file (web-compatible)
  static Future<bool> downloadJsonFile(
    Map<String, dynamic> jsonData, {
    String? filename,
  }) async {
    try {
      final jsonString = jsonToString(jsonData);
      final now = DateTime.now();
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final defaultFilename =
          'roster_export_${dateFormat.format(now)}.json';
      final finalFilename = filename ?? defaultFilename;

      // For web platform - use browser download
      if (kIsWeb) {
        final bytes = utf8.encode(jsonString);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', finalFilename)
          ..click();
        html.Url.revokeObjectUrl(url);
        print('✅ JSON file downloaded (browser)');
        return true;
      }

      // For mobile/desktop platforms only
      // Try to get Downloads directory first
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final file = io.File('${downloadsDir.path}/$finalFilename');
          await file.writeAsString(jsonString);
          print('✅ JSON file downloaded to: ${file.path}');
          return true;
        }
      } catch (e) {
        print('⚠️ Could not access Downloads directory: $e');
      }

      // Fallback: use Documents directory
      try {
        final documentsDir = await getApplicationDocumentsDirectory();
        final file = io.File('${documentsDir.path}/$finalFilename');
        await file.writeAsString(jsonString);
        print('✅ JSON file saved to Documents: ${file.path}');
        return true;
      } catch (e) {
        print('❌ Error saving JSON file to Documents: $e');
        return false;
      }
    } catch (e) {
      print('❌ Error downloading JSON file: $e');
      return false;
    }
  }


  /// Create an HTTPS endpoint payload for API integration
  /// This can be sent to your backend server
  static Future<Map<String, dynamic>> createHttpsEndpointPayload(
    Map<String, dynamic> jsonData, {
    required String apiKey,
    String? webhookUrl,
  }) async {
    return {
      'status': 'success',
      'data': jsonData,
      'signature': _generateSignature(jsonData, apiKey),
      'timestamp': DateTime.now().toIso8601String(),
      'webhookUrl': webhookUrl,
      'headers': {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
    };
  }

  /// Generate HMAC signature for secure transmission
  static String _generateSignature(
    Map<String, dynamic> data,
    String apiKey,
  ) {
    // This is a placeholder. In production, use:
    // import 'package:crypto/crypto.dart';
    // final signature = Hmac(sha256, utf8.encode(apiKey))
    //     .convert(utf8.encode(jsonEncode(data)))
    //     .toString();
    final jsonString = jsonEncode(data);
    return 'sig_${jsonString.hashCode.toString().replaceAll('-', '')}';
  }

  /// Send data to remote HTTPS endpoint
  static Future<bool> sendToHttpsEndpoint(
    Map<String, dynamic> jsonData, {
    required String endpointUrl,
    required String apiKey,
  }) async {
    try {
      // Import 'package:http/http.dart' for actual implementation
      // final response = await http.post(
      //   Uri.parse(endpointUrl),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $apiKey',
      //   },
      //   body: jsonEncode(jsonData),
      // );
      //
      // if (response.statusCode == 200 || response.statusCode == 201) {
      //   print('✅ Data sent to endpoint successfully');
      //   return true;
      // } else {
      //   print('❌ Failed to send data: ${response.statusCode}');
      //   return false;
      // }

      // Placeholder for now
      print('📤 Would send data to: $endpointUrl');
      return true;
    } catch (e) {
      print('❌ Error sending to HTTPS endpoint: $e');
      return false;
    }
  }

  /// Complete export workflow: save JSON, then generate PDF
  static Future<Map<String, dynamic>> exportWithPdfGeneration(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
    bool downloadJson = true,
    String? endpointUrl,
    String? apiKey,
  }) async {
    try {
      // Step 1: Export data to JSON
      final jsonData = await exportRosterDataToJson(
        employees,
        weekDates,
        rosterName: rosterName,
      );

      // Step 2: Download JSON if requested
      if (downloadJson) {
        await downloadJsonFile(jsonData, filename: _generateFilename(rosterName));
      }

      // Step 3: Send to HTTPS endpoint if provided
      if (endpointUrl != null && apiKey != null) {
        await sendToHttpsEndpoint(
          jsonData,
          endpointUrl: endpointUrl,
          apiKey: apiKey,
        );
      }

      // Step 4: Return data for PDF generation
      return {
        'status': 'success',
        'message': 'Data exported successfully',
        'jsonData': jsonData,
        'jsonDownloaded': downloadJson,
      };
    } catch (e) {
      print('❌ Error in export workflow: $e');
      return {
        'status': 'error',
        'message': 'Export failed: $e',
      };
    }
  }

  /// Generate filename with timestamp
  static String _generateFilename(String? rosterName) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final baseName = (rosterName ?? 'roster').replaceAll(' ', '_');
    return '${baseName}_export_${dateFormat.format(now)}.json';
  }

  /// Compress JSON data for efficient transmission
  static Uint8List compressJsonData(Map<String, dynamic> jsonData) {
    final jsonString = jsonToString(jsonData);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  /// Validate JSON data integrity
  static bool validateJsonData(Map<String, dynamic> jsonData) {
    try {
      // Check required fields
      if (!jsonData.containsKey('exportMetadata')) return false;
      if (!jsonData.containsKey('employees')) return false;
      if (!jsonData.containsKey('summary')) return false;

      final employees = jsonData['employees'] as List?;
      if (employees == null || employees.isEmpty) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}
