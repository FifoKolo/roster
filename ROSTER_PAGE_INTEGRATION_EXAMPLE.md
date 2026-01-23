// ROSTER PAGE INTEGRATION EXAMPLE
// Add this to lib/screens/roster_page.dart

// Step 1: Add import at the top of the file
import 'package:roster/utils/export_integration_helper.dart';

// Step 2: Add these methods to _RosterPageState class

/// Handle export menu selections
void _handleExportAction(String value) {
  switch (value) {
    case 'export_json':
      _exportJsonOnly();
      break;
    case 'export_json_pdf':
      _exportJsonAndPdf();
      break;
    case 'export_to_server':
      _exportToServer();
      break;
  }
}

/// Export JSON file only
Future<void> _exportJsonOnly() async {
  await ExportIntegrationHelper.quickExportJson(
    context,
    currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
    weekDates,
    rosterName: widget.rosterName,
  );
}

/// Export JSON and auto-generate PDF
Future<void> _exportJsonAndPdf() async {
  await ExportIntegrationHelper.exportWithPdfWorkflow(
    context,
    currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
    weekDates,
    rosterName: widget.rosterName,
    showSuccessMessage: true,
  );
}

/// Export data to HTTPS endpoint
Future<void> _exportToServer() async {
  // TODO: Configure your server details
  const endpointUrl = 'https://api.yourserver.com/export';
  const apiKey = 'your-api-key-here';

  // You could also load from secure storage:
  // final apiKey = await SecureStorage.getApiKey();
  // final endpointUrl = await SecureStorage.getEndpointUrl();

  await ExportIntegrationHelper.exportToHttpsEndpoint(
    context,
    currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
    weekDates,
    rosterName: widget.rosterName,
    endpointUrl: endpointUrl,
    apiKey: apiKey,
  );
}

// Step 3: Add to _buildAppBarActions() method
// Find the existing PopupMenuButton for schedule/PDF options and add this new button:

PopupMenuButton<String>(
  icon: Icon(
    Icons.download,
    color: Colors.white,
    size: ResponsiveHelper.getResponsiveIconSize(context, 24),
  ),
  tooltip: 'Export Options',
  onSelected: _handleExportAction,
  itemBuilder: (BuildContext context) => [
    const PopupMenuItem<String>(
      value: 'export_json',
      child: Row(
        children: [
          Icon(Icons.download_for_offline, size: 20, color: Colors.blue),
          SizedBox(width: 12),
          Text('Download JSON Data'),
        ],
      ),
    ),
    const PopupMenuItem<String>(
      value: 'export_json_pdf',
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
          SizedBox(width: 12),
          Text('Export JSON + PDF'),
        ],
      ),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(
      value: 'export_to_server',
      child: Row(
        children: [
          Icon(Icons.cloud_upload, size: 20, color: Colors.purple),
          SizedBox(width: 12),
          Text('Send to Server'),
        ],
      ),
    ),
  ],
),

// Step 4: (Optional) For responsive design, also add to responsive_roster_page.dart:
// In _buildResponsiveAppBarActions() method, add similar code

// COMPLETE EXAMPLE INTEGRATION
/* 
Place this entire section in _RosterPageState to have full export functionality:

import 'package:roster/utils/export_integration_helper.dart';

class _RosterPageState extends State<RosterPage> {
  // ... existing code ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ... existing appbar code ...
        actions: _buildAppBarActions(),
      ),
      body: // ... existing body ...
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      // ... existing buttons (settings, etc) ...
      
      // EXPORT MENU - Add this new button
      PopupMenuButton<String>(
        icon: Icon(
          Icons.download,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        tooltip: 'Export Options',
        onSelected: _handleExportAction,
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'export_json',
            child: Row(
              children: [
                Icon(Icons.download_for_offline, size: 20, color: Colors.blue),
                SizedBox(width: 12),
                Text('Download JSON Data'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'export_json_pdf',
            child: Row(
              children: [
                Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
                SizedBox(width: 12),
                Text('Export JSON + PDF'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'export_to_server',
            child: Row(
              children: [
                Icon(Icons.cloud_upload, size: 20, color: Colors.purple),
                SizedBox(width: 12),
                Text('Send to Server'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  void _handleExportAction(String value) {
    switch (value) {
      case 'export_json':
        _exportJsonOnly();
        break;
      case 'export_json_pdf':
        _exportJsonAndPdf();
        break;
      case 'export_to_server':
        _exportToServer();
        break;
    }
  }

  Future<void> _exportJsonOnly() async {
    await ExportIntegrationHelper.quickExportJson(
      context,
      currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
      weekDates,
      rosterName: widget.rosterName,
    );
  }

  Future<void> _exportJsonAndPdf() async {
    await ExportIntegrationHelper.exportWithPdfWorkflow(
      context,
      currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
      weekDates,
      rosterName: widget.rosterName,
      showSuccessMessage: true,
    );
  }

  Future<void> _exportToServer() async {
    const endpointUrl = 'https://api.yourserver.com/export';
    const apiKey = 'your-api-key-here';

    await ExportIntegrationHelper.exportToHttpsEndpoint(
      context,
      currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
      weekDates,
      rosterName: widget.rosterName,
      endpointUrl: endpointUrl,
      apiKey: apiKey,
    );
  }

  // ... rest of existing methods ...
}
*/
