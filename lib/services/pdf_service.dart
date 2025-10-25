import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/employee_model.dart';

class PdfService {
  /// Build a PUBLIC roster PDF for staff viewing (basic schedule only)
  static Future<Uint8List> buildPublicRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('EEE dd MMM yyyy');

    final headerBg = _pdfC(style?['headerColor'], PdfColors.blueGrey100);
    final headerFg = _pdfC(style?['headerTextColor'], PdfColors.black);
    final borderC = _pdfC(style?['cellBorderColor'], PdfColors.grey300);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2),
    };
    for (var i = 1; i <= 7; i++) {
      columnWidths[i] = pw.FlexColumnWidth(1.2);
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(24),
        ),
        build: (ctx) => [
          pw.Text('Weekly Schedule - Staff Copy', 
                   style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            '${dateFmt.format(weekDates[days.first] ?? DateTime.now())} - ${dateFmt.format(weekDates[days.last] ?? DateTime.now())}',
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: borderC),
            columnWidths: columnWidths,
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  pw.Padding(
                    padding: pw.EdgeInsets.all(6),
                    child: pw.Text('Employee', style: pw.TextStyle(color: headerFg, fontWeight: pw.FontWeight.bold)),
                  ),
                  for (final d in days)
                    pw.Padding(
                      padding: pw.EdgeInsets.all(6),
                      child: pw.Text(d, style: pw.TextStyle(color: headerFg, fontWeight: pw.FontWeight.bold)),
                    ),
                ],
              ),
              // Employee rows with shift information
              for (final e in employees)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(6),
                      child: pw.Text(e.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    for (final day in days)
                      pw.Padding(
                        padding: pw.EdgeInsets.all(6),
                        child: pw.Text(_getShiftDisplay(e, day)),
                      ),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                   style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build a PRIVATE roster PDF for management (includes all hours and accumulated data)
  static Future<Uint8List> buildPrivateRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('EEE dd MMM yyyy');

    final headerBg = _pdfC(style?['headerColor'], PdfColors.blueGrey100);
    final headerFg = _pdfC(style?['headerTextColor'], PdfColors.black);
    final borderC = _pdfC(style?['cellBorderColor'], PdfColors.grey300);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(20),
        ),
        build: (ctx) => [
          pw.Text('Weekly Roster - Management Report (CONFIDENTIAL)', 
                   style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
          pw.SizedBox(height: 8),
          pw.Text(
            '${dateFmt.format(weekDates[days.first] ?? DateTime.now())} - ${dateFmt.format(weekDates[days.last] ?? DateTime.now())}',
            style: pw.TextStyle(fontSize: 14),
          ),
          pw.SizedBox(height: 16),
          
          // Schedule Table
          pw.Text('WEEKLY SCHEDULE:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: borderC),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              for (var i = 1; i <= 7; i++) i: pw.FlexColumnWidth(1.2),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  _buildTableCell('Employee', headerFg, bold: true),
                  for (final d in days) _buildTableCell(d, headerFg, bold: true),
                ],
              ),
              // Employee schedule rows
              for (final e in employees)
                pw.TableRow(
                  children: [
                    _buildTableCell(e.name, PdfColors.black, bold: true),
                    for (final day in days) _buildTableCell(_getShiftDisplay(e, day), PdfColors.black),
                  ],
                ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Hours Summary Table
          pw.Text('HOURS SUMMARY & ACCUMULATED DATA:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: borderC),
            columnWidths: {
              0: pw.FlexColumnWidth(2),   // Name
              1: pw.FlexColumnWidth(1.5), // This Week Worked
              2: pw.FlexColumnWidth(1.3), // Holiday Earned
              3: pw.FlexColumnWidth(1.3), // Holiday Used
              4: pw.FlexColumnWidth(1.3), // Holiday Balance
              5: pw.FlexColumnWidth(1.8), // Total Accumulated Worked
              6: pw.FlexColumnWidth(1.8), // Total Accumulated Holiday
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  _buildTableCell('Employee', headerFg, bold: true),
                  _buildTableCell('Week\nWorked Hrs', headerFg, bold: true),
                  _buildTableCell('Holiday\nEarned', headerFg, bold: true),
                  _buildTableCell('Holiday\nUsed', headerFg, bold: true),
                  _buildTableCell('Holiday\nBalance', headerFg, bold: true),
                  _buildTableCell('Total Accum.\nWorked Hrs', headerFg, bold: true),
                  _buildTableCell('Total Accum.\nHoliday Hrs', headerFg, bold: true),
                ],
              ),
              // Employee data rows
              for (final e in employees)
                pw.TableRow(
                  children: [
                    _buildTableCell(e.name, PdfColors.black, bold: true),
                    _buildTableCell(e.totalWorkedThisRoster.toStringAsFixed(2), PdfColors.black),
                    _buildTableCell(e.holidayHoursEarnedThisRoster.toStringAsFixed(2), PdfColors.green700),
                    _buildTableCell(e.holidayHoursUsedThisRoster.toStringAsFixed(2), PdfColors.red700),
                    _buildTableCell(e.totalHolidayThisRoster.toStringAsFixed(2), PdfColors.black),
                    _buildTableCell(e.accumulatedWorkedHours.toStringAsFixed(2), PdfColors.blue),
                    _buildTableCell(e.accumulatedHolidayHours.toStringAsFixed(2), PdfColors.blue),
                  ],
                ),
              // Totals row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableCell('TOTALS:', PdfColors.black, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalWorkedThisRoster).toStringAsFixed(2), PdfColors.black, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.holidayHoursEarnedThisRoster).toStringAsFixed(2), PdfColors.green700, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.holidayHoursUsedThisRoster).toStringAsFixed(2), PdfColors.red700, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalHolidayThisRoster).toStringAsFixed(2), PdfColors.black, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.accumulatedWorkedHours).toStringAsFixed(2), PdfColors.blue, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.accumulatedHolidayHours).toStringAsFixed(2), PdfColors.blue, bold: true),
                ],
              ),
            ],
          ),
          
          pw.SizedBox(height: 20),
          
          // Additional Notes Section
          pw.Text('NOTES:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('• Blue numbers represent accumulated totals across all saved weeks', style: pw.TextStyle(fontSize: 10)),
          pw.Text('• Holiday Earned: 8% of worked hours per week', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
          pw.Text('• Holiday Used: 8 hours automatically deducted per holiday day taken', style: pw.TextStyle(fontSize: 10, color: PdfColors.red700)),
          pw.Text('• Holiday Balance = Earned + Manual + Carry-over - Used', style: pw.TextStyle(fontSize: 10)),
          pw.Text('• This report contains confidential payroll information - for management use only', style: pw.TextStyle(fontSize: 10)),
          
          pw.SizedBox(height: 20),
          pw.Text('Generated on ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                   style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    );

    return pdf.save();
  }

  /// Helper to build table cells with consistent styling
  static pw.Widget _buildTableCell(String text, PdfColor color, {bool bold = false}) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 9,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Get shift display text for a specific day
  static String _getShiftDisplay(Employee employee, String day) {
    final shift = employee.shifts[day];
    if (shift == null) return '-';
    return shift.formatted();
  }

  /// Share the PUBLIC roster PDF (for staff)
  static Future<void> sharePublicRosterPdf(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    final bytes = await buildPublicRosterPdf(employees, weekDates, style: style);
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    await Printing.sharePdf(bytes: bytes, filename: 'schedule_staff_$date.pdf');
  }

  /// Share the PRIVATE roster PDF (for management)
  static Future<void> sharePrivateRosterPdf(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    final bytes = await buildPrivateRosterPdf(employees, weekDates, style: style);
    final date = DateFormat('yyyyMMdd').format(DateTime.now());
    await Printing.sharePdf(bytes: bytes, filename: 'roster_management_$date.pdf');
  }

  /// Print/preview the PUBLIC roster PDF
  static Future<void> printPublicRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    await Printing.layoutPdf(onLayout: (_) => buildPublicRosterPdf(employees, weekDates, style: style));
  }

  /// Print/preview the PRIVATE roster PDF
  static Future<void> printPrivateRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    await Printing.layoutPdf(onLayout: (_) => buildPrivateRosterPdf(employees, weekDates, style: style));
  }

  // Legacy method - now points to public PDF for backward compatibility
  static Future<Uint8List> buildRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    return buildPublicRosterPdf(employees, weekDates, style: style);
  }

  static Future<void> shareRosterPdf(
    BuildContext context,
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    return sharePublicRosterPdf(context, employees, weekDates, style: style);
  }

  static Future<void> printRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    return printPublicRosterPdf(employees, weekDates, style: style);
  }

  // Helpers: convert ARGB int to PdfColor (RGB used; alpha ignored).
  static PdfColor _pdfC(int? v, PdfColor fallback) {
    if (v == null) return fallback;
    final rgb = v & 0xFFFFFF;
    return PdfColor.fromInt(rgb);
  }
}
