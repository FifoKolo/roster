# Data Export & HTTPS Endpoint Integration Guide

## Overview

The Roster App now includes comprehensive data export functionality that:
- Exports all roster data to JSON format
- Automatically downloads JSON files
- Integrates with HTTPS endpoints for remote processing
- Generates PDF reports from exported data
- Supports batch exports and API integration

## Features

### 1. **JSON Data Export**
Exports complete roster data including:
- Employee information (names, emails, departments, positions)
- Shift schedules (start/end times, roles, comments)
- Calculated hours (scheduled, breaks, paid, holiday)
- Payroll estimates and summaries
- Bank holiday data
- Metadata and timestamps

### 2. **Automatic Downloading**
- Web: Downloads to default downloads folder
- Mobile: Saves to device storage
- Desktop: Custom file location support

### 3. **HTTPS Endpoint Integration**
- Send data securely to backend servers
- Automatic JWT authentication
- HMAC signature generation for verification
- Webhook URL support for notifications
- Request ID tracking and logging

### 4. **PDF Generation from JSON**
- Automatically generates PDF from exported data
- Includes all roster information and summaries
- Management and staff report versions

## Implementation

### Basic Usage

#### 1. Simple JSON Export with Download

```dart
import 'package:roster/services/data_export_service.dart';

// Export and download JSON
final jsonData = await DataExportService.exportRosterDataToJson(
  employees,
  weekDates,
  rosterName: 'Week 1 Roster',
);

await DataExportService.downloadJsonFile(jsonData);
```

#### 2. Export with PDF Generation

```dart
import 'package:roster/utils/export_integration_helper.dart';

// Complete workflow: JSON → Download → PDF
await ExportIntegrationHelper.exportWithPdfWorkflow(
  context,
  employees,
  weekDates,
  rosterName: 'Week 1 Roster',
);
```

#### 3. Export to HTTPS Endpoint

```dart
// Send data to backend server
final success = await DataExportService.sendToHttpsEndpoint(
  jsonData,
  endpointUrl: 'https://api.example.com/export',
  apiKey: 'your-api-key',
);
```

#### 4. Using the API Service

```dart
import 'package:roster/services/https_export_api_service.dart';

// Create API service
final apiService = HttpsExportApiService(
  apiBaseUrl: 'https://api.example.com',
  apiKey: 'your-api-key',
  webhookUrl: 'https://example.com/webhook',
);

// Export and generate PDF on server
final result = await apiService.exportAndGeneratePdf(
  jsonData,
  generatePdf: true,
  downloadJson: true,
);
```

### UI Integration

Add export buttons to your roster page:

```dart
// Add to PopupMenuButton in roster_page.dart
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
  value: 'export_to_server',
  child: Row(
    children: [
      Icon(Icons.cloud_upload, size: 20, color: Colors.purple),
      SizedBox(width: 12),
      Text('Send to Server'),
    ],
  ),
),

// Handle in menu action:
case 'export_json':
  await ExportIntegrationHelper.quickExportJson(
    context, 
    employees, 
    weekDates,
  );
  break;

case 'export_to_server':
  await ExportIntegrationHelper.exportToHttpsEndpoint(
    context,
    employees,
    weekDates,
    endpointUrl: 'https://api.example.com/export',
    apiKey: 'your-api-key',
  );
  break;
```

## Backend Integration

### HTTPS Endpoint Requirements

Your backend should implement these endpoints:

#### 1. POST /export
- **Description**: Submit roster data for processing
- **Request**:
  ```json
  {
    "data": { /* full JSON data */ },
    "options": {
      "generatePdf": true,
      "downloadJson": true,
      "pdfFilename": "roster_2024.pdf"
    },
    "timestamp": "2024-01-23T10:30:00.000Z",
    "webhookUrl": "https://your-app.com/webhook"
  }
  ```
- **Response**:
  ```json
  {
    "status": "success",
    "exportId": "exp_123456789",
    "message": "Export processed successfully",
    "downloadUrl": "https://api.example.com/export/exp_123456789/download",
    "processingTime": 1234
  }
  ```

#### 2. GET /export/:id/status
- **Description**: Check export processing status
- **Response**:
  ```json
  {
    "status": "completed",
    "progress": 100,
    "files": {
      "json": "https://api.example.com/download/exp_123/roster.json",
      "pdf": "https://api.example.com/download/exp_123/roster.pdf"
    },
    "completedAt": "2024-01-23T10:31:00.000Z"
  }
  ```

#### 3. GET /export/:id/download?type=pdf|json
- **Description**: Download the generated file
- **Headers**: Content-Disposition: attachment; filename="roster.pdf"

#### 4. GET /export?limit=10&offset=0
- **Description**: List all exports for user
- **Response**:
  ```json
  {
    "exports": [
      {
        "id": "exp_123",
        "rosterName": "Week 1",
        "createdAt": "2024-01-23T10:30:00.000Z",
        "status": "completed"
      }
    ],
    "total": 5
  }
  ```

#### 5. DELETE /export/:id
- **Description**: Delete an export

#### 6. POST /export/batch
- **Description**: Submit multiple rosters at once

### Security Requirements

1. **API Key Authentication**
   ```
   Authorization: Bearer YOUR_API_KEY
   ```

2. **HMAC Signature Validation**
   - All requests include signature for verification
   - Verify using the same API key

3. **HTTPS Only**
   - All endpoints must use HTTPS
   - Reject HTTP connections

4. **Rate Limiting**
   - Recommended: 100 requests per minute per API key
   - Return 429 Too Many Requests when exceeded

## Configuration

### Environment Setup

Create a `.env` file (for development):
```
HTTPS_API_URL=https://api.example.com
HTTPS_API_KEY=your-secure-api-key
WEBHOOK_URL=https://your-app.com/webhook
ENABLE_LOGGING=true
```

Load in your app:
```dart
final config = HttpsExportConfig.fromEnv();
```

### pubspec.yaml Dependencies

Ensure you have these dependencies:
```yaml
dependencies:
  http: ^1.1.0
  universal_html: ^2.2.0
  intl: ^0.19.0
```

## JSON Data Structure

The exported JSON includes:

```json
{
  "exportMetadata": {
    "exportDate": "2024-01-23T10:30:00.000Z",
    "exportTimestamp": 1705941000000,
    "rosterName": "Week 1 Roster",
    "dataVersion": "1.0"
  },
  "weekInformation": {
    "weekStart": "2024-01-22T00:00:00.000Z",
    "weekEnd": "2024-01-28T00:00:00.000Z",
    "weekNumber": 1
  },
  "employees": [
    {
      "id": "emp_001",
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+353 1 234 5678",
      "department": "Engineering",
      "position": "Senior Developer",
      "contractType": "Full-Time",
      "salaryPerHour": 25.50,
      "shifts": {
        "Mon": {
          "startTime": "09:00",
          "endTime": "17:00",
          "role": "Backend",
          "comment": null,
          "isHoliday": false,
          "customHolidayHours": null,
          "enablePaidBreak": null,
          "customBreakMinutes": null
        },
        "Tue": null,
        "Wed": null,
        "Thu": null,
        "Fri": null,
        "Sat": null,
        "Sun": null
      },
      "hours": {
        "scheduledHours": 8.0,
        "mondayToSaturdayBreakHours": 0.5,
        "sundayBreakHours": 0.0,
        "totalBreakHours": 0.5,
        "paidHours": 7.5,
        "mondayToSaturdayPaidHours": 7.5,
        "sundayPaidHours": 0.0,
        "holidayHoursUsed": 0.0,
        "accumulatedWorkedHours": 32.5,
        "accumulatedHolidayHours": 16.0
      },
      "payroll": {
        "basePay": 191.25,
        "holidayPay": 0.0,
        "totalPayrollCost": 191.25
      },
      "metadata": {
        "notes": "High performer",
        "contractPdfPath": "/path/to/contract.pdf",
        "lastModified": "2024-01-23T10:30:00.000Z"
      }
    }
  ],
  "summary": {
    "totalEmployees": 5,
    "totalScheduledHours": 160.0,
    "totalBreakHours": 8.5,
    "totalPaidHours": 151.5,
    "totalHolidayHours": 5.0,
    "estimatedPayroll": 3828.75,
    "averageSalaryPerHour": 25.30,
    "highestScheduledHours": 40.0,
    "lowestScheduledHours": 28.0
  },
  "bankHolidayData": [
    {
      "date": "2024-01-22T00:00:00.000Z",
      "day": "Mon",
      "employeeName": "Jane Smith",
      "employeeId": "emp_002",
      "hoursWorked": 8.0,
      "customHolidayHours": null
    }
  ]
}
```

## Error Handling

The services include comprehensive error handling:

```dart
try {
  final result = await ExportIntegrationHelper.exportWithPdfWorkflow(
    context,
    employees,
    weekDates,
  );
  
  if (result['status'] == 'success') {
    print('✅ Export successful');
  } else {
    print('❌ Error: ${result['message']}');
  }
} catch (e) {
  print('❌ Export failed: $e');
}
```

## Troubleshooting

### JSON Export Issues
- **Empty data**: Ensure employees list is not empty
- **Invalid dates**: Check weekDates map has all days (Mon-Sun)
- **File not downloading**: Check browser download settings

### HTTPS Endpoint Issues
- **Connection refused**: Verify API URL is correct and server is running
- **401 Unauthorized**: Check API key is valid
- **400 Bad Request**: Validate JSON data structure
- **CORS errors**: Ensure backend has CORS headers configured

### PDF Generation Issues
- **Memory issues with large files**: Increase device memory or reduce employee count
- **Missing fonts**: Ensure PDF dependencies are properly installed

## Best Practices

1. **Always validate data before export**
   ```dart
   if (DataExportService.validateJsonData(jsonData)) {
     // Proceed with export
   }
   ```

2. **Use loading indicators during export**
   - Show progress dialog while processing
   - Disable user interactions during export

3. **Implement retry logic for API calls**
   ```dart
   int retries = 3;
   bool success = false;
   while (!success && retries > 0) {
     success = await apiService.validateConnection();
     if (!success) await Future.delayed(Duration(seconds: 2));
     retries--;
   }
   ```

4. **Log exports for audit trail**
   - Store export timestamps
   - Track which user initiated export
   - Log file sizes and completion status

5. **Secure API keys**
   - Never commit API keys to version control
   - Use environment variables
   - Rotate keys regularly

## Example Backend Implementation

### Node.js / Express Example

```javascript
app.post('/export', authenticateApiKey, async (req, res) => {
  const { data, options } = req.body;
  
  try {
    // Validate data
    if (!data.employees || !Array.isArray(data.employees)) {
      return res.status(400).json({ error: 'Invalid data structure' });
    }
    
    // Generate PDF
    const pdfBuffer = await generatePdfFromJson(data);
    
    // Save to storage
    const exportId = await saveExport(data, pdfBuffer);
    
    // Trigger webhook if provided
    if (req.body.webhookUrl) {
      triggerWebhook(req.body.webhookUrl, {
        exportId,
        status: 'completed',
      });
    }
    
    res.json({
      status: 'success',
      exportId,
      downloadUrl: `/export/${exportId}/download`,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Support & Documentation

For more information or issues, refer to:
- [Flutter HTTP Package](https://pub.dev/packages/http)
- [PDF Package](https://pub.dev/packages/pdf)
- [Universal HTML](https://pub.dev/packages/universal_html)
