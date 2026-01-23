import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/data_export_service.dart';
import '../services/https_export_api_service.dart';
import '../services/pdf_service.dart';

/// Utility class to integrate export functionality with PDF generation
/// Provides easy-to-use methods for the UI layer
class ExportIntegrationHelper {
  /// Complete workflow: Export JSON → Download → Generate PDF
  static Future<Map<String, dynamic>> exportWithPdfWorkflow(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
    String? endpointUrl,
    String? apiKey,
    bool showSuccessMessage = true,
  }) async {
    try {
      // Show loading dialog
      _showExportProgress(context);

      // Step 1: Export data to JSON and download
      final result = await DataExportService.exportWithPdfGeneration(
        employees,
        weekDates,
        rosterName: rosterName,
        downloadJson: true,
        endpointUrl: endpointUrl,
        apiKey: apiKey,
      );

      if (!context.mounted) return result;

      // Close loading dialog
      Navigator.of(context).pop();

      // Step 2: Generate and show PDF
      if (result['status'] == 'success' && result['jsonData'] != null) {
        await _generateAndShowPdf(
          context,
          employees,
          weekDates,
          rosterName: rosterName,
        );
      }

      if (showSuccessMessage && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Export completed successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return result;
    } catch (e) {
      if (!context.mounted) return {'status': 'error', 'message': '$e'};

      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );

      return {
        'status': 'error',
        'message': 'Export failed: $e',
      };
    }
  }

  /// Export to HTTPS endpoint only (no local download)
  static Future<bool> exportToHttpsEndpoint(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
    required String endpointUrl,
    required String apiKey,
  }) async {
    try {
      _showExportProgress(context);

      // Export data to JSON
      final jsonData = await DataExportService.exportRosterDataToJson(
        employees,
        weekDates,
        rosterName: rosterName,
      );

      // Validate JSON data
      if (!DataExportService.validateJsonData(jsonData)) {
        throw Exception('Invalid JSON data structure');
      }

      // Send to HTTPS endpoint
      final success = await DataExportService.sendToHttpsEndpoint(
        jsonData,
        endpointUrl: endpointUrl,
        apiKey: apiKey,
      );

      if (!context.mounted) return success;
      Navigator.of(context).pop();

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data sent to server successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      return success;
    } catch (e) {
      if (!context.mounted) return false;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send data: $e'),
          backgroundColor: Colors.red,
        ),
      );

      return false;
    }
  }

  /// Export using the API service
  static Future<Map<String, dynamic>> exportViaApiService(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
    required HttpsExportConfig config,
    bool generatePdf = true,
  }) async {
    try {
      // Validate config
      if (!config.isValid()) {
        throw Exception('Invalid API configuration');
      }

      _showExportProgress(context);

      // Create API service
      final apiService = HttpsExportApiService(
        apiBaseUrl: config.apiBaseUrl,
        apiKey: config.apiKey,
        webhookUrl: config.webhookUrl,
      );

      // Validate connection
      final isConnected = await apiService.validateConnection();
      if (!isConnected) {
        throw Exception('Cannot connect to API server');
      }

      // Export data
      final jsonData = await DataExportService.exportRosterDataToJson(
        employees,
        weekDates,
        rosterName: rosterName,
      );

      // Send to API
      final result = await apiService.exportAndGeneratePdf(
        jsonData,
        generatePdf: generatePdf,
        downloadJson: true,
      );

      if (!context.mounted) return result;
      Navigator.of(context).pop();

      if (context.mounted) {
        final message = result['status'] == 'success'
            ? '✅ Export processed successfully'
            : '❌ Export failed: ${result['message']}';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: result['status'] == 'success'
                ? Colors.green
                : Colors.red,
          ),
        );
      }

      return result;
    } catch (e) {
      if (!context.mounted) return {'status': 'error', 'message': '$e'};
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );

      return {
        'status': 'error',
        'message': '$e',
      };
    }
  }

  /// Show export progress dialog
  static void _showExportProgress(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Exporting roster data...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saving JSON and preparing PDF',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generate and display PDF after JSON export
  static Future<void> _generateAndShowPdf(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
  }) async {
    try {
      // Generate private PDF for management
      final pdfBytes = await PdfService.buildPrivateRosterPdf(
        employees,
        weekDates,
        rosterName: rosterName,
      );

      if (!context.mounted) return;

      // Show PDF preview
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf, color: Colors.red),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'PDF Export Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: Text(
                        'PDF Preview would display here\n(${(pdfBytes.length / 1024).toStringAsFixed(1)} KB)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Trigger download via PdfService
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('❌ Error generating PDF: $e');
    }
  }

  /// Quick export button action
  static Future<void> quickExportJson(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    String? rosterName,
  }) async {
    try {
      final jsonData = await DataExportService.exportRosterDataToJson(
        employees,
        weekDates,
        rosterName: rosterName,
      );

      await DataExportService.downloadJsonFile(jsonData);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ JSON file downloaded'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
