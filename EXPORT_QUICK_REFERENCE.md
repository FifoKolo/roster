# Export Function Quick Reference

## Files Created

1. **lib/services/data_export_service.dart** - Core JSON export functionality
2. **lib/services/https_export_api_service.dart** - HTTPS API integration
3. **lib/utils/export_integration_helper.dart** - UI integration helper
4. **EXPORT_FUNCTIONALITY_GUIDE.md** - Complete documentation

## Quick Start

### 1. Export JSON Data Only

```dart
// In your rostter page or screen
import 'package:roster/utils/export_integration_helper.dart';

// Simple button action
await ExportIntegrationHelper.quickExportJson(
  context,
  employees,
  weekDates,
  rosterName: 'Week 1',
);
```

**Result**: JSON file automatically downloads to user's device

---

### 2. Export JSON + Auto-Generate PDF

```dart
// Complete workflow
await ExportIntegrationHelper.exportWithPdfWorkflow(
  context,
  employees,
  weekDates,
  rosterName: 'Week 1 Roster',
);
```

**Result**: 
- JSON file downloads
- PDF is generated automatically
- Both files ready for use

---

### 3. Send Data to HTTPS Endpoint

```dart
// Send to your backend server
await ExportIntegrationHelper.exportToHttpsEndpoint(
  context,
  employees,
  weekDates,
  rosterName: 'Week 1',
  endpointUrl: 'https://api.yourserver.com/export',
  apiKey: 'your-secret-api-key',
);
```

**Result**: Data sent securely to server, server generates PDF and handles storage

---

### 4. Using the Full API Service

```dart
import 'package:roster/services/https_export_api_service.dart';

// Create service with credentials
final apiService = HttpsExportApiService(
  apiBaseUrl: 'https://api.yourserver.com',
  apiKey: 'your-secret-api-key',
  webhookUrl: 'https://yourserver.com/webhook', // optional
);

// Export data
final jsonData = await DataExportService.exportRosterDataToJson(
  employees,
  weekDates,
  rosterName: 'Week 1',
);

// Send to server
final result = await apiService.exportAndGeneratePdf(
  jsonData,
  generatePdf: true,
  downloadJson: true,
  pdfFilename: 'roster_week1.pdf',
);

if (result['status'] == 'success') {
  print('✅ Export successful: ${result['data']}');
} else {
  print('❌ Error: ${result['message']}');
}
```

---

## Menu Button Integration

Add these options to your roster page's PopupMenuButton:

```dart
PopupMenuButton<String>(
  icon: Icon(Icons.download),
  onSelected: (String value) {
    switch (value) {
      case 'export_json':
        // Option 1: JSON only
        ExportIntegrationHelper.quickExportJson(
          context, 
          employees, 
          weekDates,
        );
        break;
        
      case 'export_pdf_with_json':
        // Option 2: JSON + PDF
        ExportIntegrationHelper.exportWithPdfWorkflow(
          context,
          employees,
          weekDates,
        );
        break;
        
      case 'send_to_server':
        // Option 3: Send to backend
        ExportIntegrationHelper.exportToHttpsEndpoint(
          context,
          employees,
          weekDates,
          endpointUrl: 'https://api.yourserver.com/export',
          apiKey: 'your-api-key',
        );
        break;
    }
  },
  itemBuilder: (BuildContext context) => [
    const PopupMenuItem<String>(
      value: 'export_json',
      child: Row(
        children: [
          Icon(Icons.download_for_offline, size: 20, color: Colors.blue),
          SizedBox(width: 12),
          Text('Export JSON Data'),
        ],
      ),
    ),
    const PopupMenuItem<String>(
      value: 'export_pdf_with_json',
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
          SizedBox(width: 12),
          Text('Export JSON + PDF'),
        ],
      ),
    ),
    const PopupMenuItem<String>(
      value: 'send_to_server',
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
```

---

## Example: Add to Existing Roster Page

### In `lib/screens/roster_page.dart`, add to `_buildAppBarActions()`:

```dart
List<Widget> _buildAppBarActions() {
  return [
    // ... existing buttons ...
    
    // Export Menu
    PopupMenuButton<String>(
      icon: Icon(
        Icons.file_download,
        color: Colors.white,
        size: 24,
      ),
      tooltip: 'Export Options',
      onSelected: (String value) {
        if (value == 'export_json') {
          ExportIntegrationHelper.quickExportJson(
            context,
            currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
            weekDates,
            rosterName: widget.rosterName,
          );
        } else if (value == 'export_with_pdf') {
          ExportIntegrationHelper.exportWithPdfWorkflow(
            context,
            currentWeekEmployees.isNotEmpty ? currentWeekEmployees : employees,
            weekDates,
            rosterName: widget.rosterName,
          );
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'export_json',
          child: Row(
            children: [
              Icon(Icons.download_for_offline, size: 20, color: Colors.blue),
              SizedBox(width: 12),
              Text('Download JSON'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'export_with_pdf',
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Export + PDF'),
            ],
          ),
        ),
      ],
    ),
  ];
}
```

---

## What Gets Exported

The JSON export includes:

✅ **Metadata**
- Export date & timestamp
- Roster name & week number
- Data version

✅ **Employee Data**
- Names, emails, phones
- Departments & positions
- Contract types & hourly rates

✅ **Shift Information**
- Start/end times for each day
- Roles & comments
- Holiday flags
- Custom break minutes

✅ **Calculated Hours**
- Scheduled hours
- Break deductions (Mon-Sat, Sunday)
- Paid hours
- Holiday hours used
- Accumulated totals

✅ **Payroll Data**
- Base pay calculations
- Holiday pay
- Total payroll costs
- Cost per employee

✅ **Summary Statistics**
- Total employees
- Total hours (scheduled, breaks, paid)
- Payroll estimates
- Min/max scheduled hours
- Average salary per hour

✅ **Bank Holiday Data**
- Employees working on holidays
- Holiday hours & pay adjustments

---

## Customization

### Change Export Filename Format

```dart
// In export_integration_helper.dart, modify _generateFilename()
static String _generateFilename(String? rosterName) {
  final now = DateTime.now();
  final dateFormat = DateFormat('dd-MMM-yyyy'); // Change format here
  final baseName = (rosterName ?? 'roster').replaceAll(' ', '_');
  return '${baseName}_${dateFormat.format(now)}.json';
}
```

### Add Custom Fields to Export

```dart
// In data_export_service.dart, add to _serializeEmployees()
return employees.map((employee) {
  return {
    // ... existing fields ...
    'customFields': {
      'manager': employee.manager,
      'department': employee.department,
      'certifications': employee.certifications,
    },
  };
}).toList();
```

### Modify Summary Calculations

```dart
// In data_export_service.dart, update _calculateSummary()
static Map<String, dynamic> _calculateSummary(List<Employee> employees) {
  // Add custom logic here
  return {
    'totalEmployees': employees.length,
    'customMetric': _calculateCustomMetric(employees),
    // ... other fields ...
  };
}
```

---

## Testing

### Test JSON Export

```dart
test('JSON export includes all employees', () async {
  final jsonData = await DataExportService.exportRosterDataToJson(
    testEmployees,
    testWeekDates,
  );
  
  expect(jsonData['employees'].length, equals(testEmployees.length));
  expect(jsonData['summary']['totalEmployees'], equals(testEmployees.length));
});

test('Exported data is valid JSON', () async {
  final jsonData = await DataExportService.exportRosterDataToJson(
    testEmployees,
    testWeekDates,
  );
  
  expect(DataExportService.validateJsonData(jsonData), isTrue);
});
```

---

## Troubleshooting

**JSON file doesn't download:**
- Check browser permissions
- Ensure web platform detected correctly
- Check console for errors

**HTTPS endpoint returns 401:**
- Verify API key is correct
- Check Authorization header format
- Ensure token isn't expired

**PDF not generating:**
- Check employees list is not empty
- Verify weekDates map has all days
- Check available device memory

---

## Features Summary

| Feature | JSON Export | HTTPS Endpoint | Auto PDF |
|---------|:-----------:|:--------------:|:--------:|
| Download JSON | ✅ | ✅ | ✅ |
| Secure transmission | ✅ | ✅ | ✅ |
| Generate PDF | ❌ | ✅ | ✅ |
| Server storage | ❌ | ✅ | ❌ |
| Automatic retry | ❌ | ✅ | ❌ |
| Batch export | ❌ | ✅ | ❌ |
| Webhook support | ❌ | ✅ | ❌ |
| Local only | ✅ | ❌ | ✅ |

---

## Next Steps

1. **For Local Use Only**
   - Use `quickExportJson()` for JSON downloads
   - Use `exportWithPdfWorkflow()` for JSON + PDF

2. **With Backend Server**
   - Set up HTTPS endpoint (see guide)
   - Use `exportToHttpsEndpoint()` or `HttpsExportApiService`
   - Configure API credentials

3. **Advanced Integration**
   - Implement custom backend endpoints
   - Add webhook notifications
   - Create admin dashboard for exports
   - Set up automated scheduled exports

---

For more detailed information, see **EXPORT_FUNCTIONALITY_GUIDE.md**
