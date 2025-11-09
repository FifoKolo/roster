import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

import '../models/employee_model.dart';
import 'irish_bank_holidays.dart';

/// Represents an employee working on a bank holiday
class BankHolidayWork {
  final String employeeName;
  final String day;
  final String holidayName;
  final DateTime date;
  final double hoursWorked;
  final double breakDeduction;
  final double paidHours;
  
  const BankHolidayWork({
    required this.employeeName,
    required this.day,
    required this.holidayName,
    required this.date,
    required this.hoursWorked,
    required this.breakDeduction,
    required this.paidHours,
  });
}

class PdfService {
  /// Build a PUBLIC roster PDF for staff viewing (basic schedule only)
  static Future<Uint8List> buildPublicRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    print('📄 Building Public PDF with ${employees.length} employees');
    for (final emp in employees) {
      print('  - ${emp.name}: ${emp.shifts.length} shifts');
      for (final shift in emp.shifts.entries) {
        print('    - ${shift.key}: ${shift.value.toJson()}');
      }
    }
    
    final pdf = pw.Document();
    final dateFmt = DateFormat('EEE dd MMM yyyy');

    final headerBg = _pdfC(style?['headerColor'], PdfColors.blueGrey100);
    final headerFg = _pdfC(style?['headerTextColor'], PdfColors.black);
    final borderC = _pdfC(style?['cellBorderColor'], PdfColors.grey300);

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final columnWidths = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(2.5), // Employee name - wider for landscape
    };
    for (var i = 1; i <= 7; i++) {
      columnWidths[i] = pw.FlexColumnWidth(2.0); // Day columns - much wider for better time display
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: pw.EdgeInsets.all(20),
          pageFormat: PdfPageFormat.a4.landscape, // Make it horizontal
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
                      child: pw.Column(
                        children: [
                          pw.Text(d, style: pw.TextStyle(color: headerFg, fontWeight: pw.FontWeight.bold)),
                          // Check for bank holiday
                          if (_isBankHoliday(weekDates[d]))
                            pw.Text('BANK HOLIDAY', 
                                   style: pw.TextStyle(color: PdfColors.red, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
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
                        child: pw.Text(_getShiftDisplay(e, day), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// private roster
  static Future<Uint8List> buildPrivateRosterPdf(
    List<Employee> employees,
    Map<String, DateTime> weekDates, {
    Map<String, int?>? style,
  }) async {
    print('📄 Building Private PDF with ${employees.length} employees');
    for (final emp in employees) {
      print('  - ${emp.name}: ${emp.shifts.length} shifts');
      for (final shift in emp.shifts.entries) {
        print('    - ${shift.key}: ${shift.value.toJson()}');
      }
    }
    
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
                  for (final d in days) 
                    _buildTableCell(
                      _isBankHoliday(weekDates[d]) ? '$d\n(BANK HOLIDAY)' : d, 
                      _isBankHoliday(weekDates[d]) ? PdfColors.red : headerFg, 
                      bold: true
                    ),
                ],
              ),
              // Employee schedule rows
              for (final e in employees)
                pw.TableRow(
                  children: [
                    _buildTableCell(e.name, PdfColors.black, bold: true),
                    for (final day in days) _buildTableCell(_getShiftDisplay(e, day), PdfColors.black, bold: true),
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
              1: pw.FlexColumnWidth(1.5), // Scheduled Hours
              2: pw.FlexColumnWidth(1.3), // Break Deductions
              3: pw.FlexColumnWidth(1.3), // Paid Hours
              4: pw.FlexColumnWidth(1.3), // Mon-Sat Paid
              5: pw.FlexColumnWidth(1.3), // Sunday Paid
              6: pw.FlexColumnWidth(1.5), // Holiday Hours Used
              7: pw.FlexColumnWidth(1.8), // Accum Holiday Hours
              8: pw.FlexColumnWidth(1.8), // Remaining Holiday Hours
            },
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: headerBg),
                children: [
                  _buildTableCell('Employee', headerFg, bold: true),
                  _buildTableCell('Scheduled\nHours', headerFg, bold: true),
                  _buildTableCell('Break\nDeductions', headerFg, bold: true),
                  _buildTableCell('Paid\nHours', headerFg, bold: true),
                  _buildTableCell('Mon-Sat\nPaid', headerFg, bold: true),
                  _buildTableCell('Sunday\nPaid', headerFg, bold: true),
                  _buildTableCell('Holiday\nUsed', headerFg, bold: true),
                  _buildTableCell('Accum.\nHoliday', headerFg, bold: true),
                  _buildTableCell('Remaining\nHoliday', headerFg, bold: true),
                ],
              ),
              // Employee data rows
              for (final e in employees)
                pw.TableRow(
                  children: [
                    _buildTableCell(e.name, PdfColors.black, bold: true),
                    _buildTableCell(e.totalScheduledHours.toStringAsFixed(2), PdfColors.black, bold: true),
                    _buildTableCell(e.breakHours.toStringAsFixed(2), PdfColors.red, bold: true),
                    _buildTableCell(e.totalPaidHours.toStringAsFixed(2), PdfColors.green700, bold: true),
                    _buildTableCell(e.totalMondayToSaturdayPaidHours.toStringAsFixed(2), PdfColors.blue, bold: true),
                    _buildTableCell(e.totalSundayPaidHours.toStringAsFixed(2), PdfColors.purple, bold: true),
                    _buildTableCell(e.totalHolidayHoursUsed.toStringAsFixed(2), PdfColors.orange, bold: true),
                    _buildTableCell(e.accumulatedHolidayHours.toStringAsFixed(2), PdfColors.grey600, bold: true),
                    _buildTableCell(e.remainingAccumulatedHolidayHours.toStringAsFixed(2), 
                        e.remainingAccumulatedHolidayHours < 0 ? PdfColors.red : PdfColors.green700, bold: true),
                  ],
                ),
              // Totals row
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableCell('TOTALS:', PdfColors.black, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalScheduledHours).toStringAsFixed(2), PdfColors.black, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.breakHours).toStringAsFixed(2), PdfColors.red, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalPaidHours).toStringAsFixed(2), PdfColors.green700, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalMondayToSaturdayPaidHours).toStringAsFixed(2), PdfColors.blue, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalSundayPaidHours).toStringAsFixed(2), PdfColors.purple, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.totalHolidayHoursUsed).toStringAsFixed(2), PdfColors.orange, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.accumulatedHolidayHours).toStringAsFixed(2), PdfColors.grey600, bold: true),
                  _buildTableCell(employees.fold(0.0, (sum, e) => sum + e.remainingAccumulatedHolidayHours).toStringAsFixed(2), PdfColors.grey600, bold: true),
                ],
              ),
            ],
          ),
          
          // Bank Holiday Pay Section
          ..._buildBankHolidayPaySection(employees, weekDates, headerBg, headerFg, borderC),
          
          pw.SizedBox(height: 20),
          
          // Additional Notes Section
          pw.Text('NOTES:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('• Grey numbers represent accumulated totals across all saved weeks', style: pw.TextStyle(fontSize: 10)),
          pw.Text('• Scheduled Hours: Total time rostered for each employee', style: pw.TextStyle(fontSize: 10, color: PdfColors.black)),
          pw.Text('• Break Deductions: 15min (≥4.5hrs) or 30min (≥6hrs) UNPAID break time per shift', style: pw.TextStyle(fontSize: 10, color: PdfColors.red)),
          pw.Text('• Paid Hours = Scheduled Hours - Break Deductions (for payroll)', style: pw.TextStyle(fontSize: 10, color: PdfColors.green700)),
          pw.Text('• Mon-Sat Paid: Monday through Saturday paid hours (standard rate)', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue)),
          pw.Text('• Sunday Paid: Sunday paid hours (penalty/overtime rate)', style: pw.TextStyle(fontSize: 10, color: PdfColors.purple)),
          pw.Text('• Holiday Used: Hours deducted from accumulated holiday hours this roster', style: pw.TextStyle(fontSize: 10, color: PdfColors.orange)),
          pw.Text('• Accum. Holiday: Total holiday hours available per employee', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text('• Remaining Holiday: Holiday hours left after this roster (negative = overused)', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.Text('• Use PAID hours for payroll calculations and wages', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text('• This report contains confidential payroll information - for management use only', style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build bank holiday pay section for management PDF
  static List<pw.Widget> _buildBankHolidayPaySection(
    List<Employee> employees,
    Map<String, DateTime> weekDates,
    PdfColor headerBg,
    PdfColor headerFg,
    PdfColor borderC,
  ) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Find all bank holidays in this week
    final bankHolidays = <String, BankHoliday>{};
    for (final day in days) {
      final date = weekDates[day];
      if (date != null) {
        final holiday = IrishBankHolidays.getBankHoliday(date);
        if (holiday != null) {
          bankHolidays[day] = holiday;
        }
      }
    }
    
    // If no bank holidays, return empty list
    if (bankHolidays.isEmpty) {
      return [];
    }
    
    // Find employees who worked on bank holidays
    final bankHolidayWorkers = <BankHolidayWork>[];
    for (final emp in employees) {
      for (final entry in bankHolidays.entries) {
        final day = entry.key;
        final holiday = entry.value;
        final shift = emp.shifts[day];
        
        if (shift != null && !shift.isHoliday && shift.duration > 0) {
          // Employee worked on this bank holiday
          bankHolidayWorkers.add(BankHolidayWork(
            employeeName: emp.name,
            day: day,
            holidayName: holiday.name,
            date: weekDates[day]!,
            hoursWorked: shift.duration,
            breakDeduction: _calculateBreakForShift(shift.duration),
            paidHours: shift.duration - _calculateBreakForShift(shift.duration),
          ));
        }
      }
    }
    
    // If no one worked on bank holidays, show a note
    if (bankHolidayWorkers.isEmpty) {
      return [
        pw.SizedBox(height: 20),
        pw.Container(
          padding: pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            border: pw.Border.all(color: PdfColors.green300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'BANK HOLIDAY PAY SUMMARY',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Bank holidays this week: ${bankHolidays.values.map((h) => h.name).join(', ')}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.green700),
              ),
              pw.Text(
                'No employees worked on bank holidays - no premium pay required.',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.green600),
              ),
            ],
          ),
        ),
      ];
    }
    
    // Calculate totals
    final totalPaidHours = bankHolidayWorkers.fold(0.0, (sum, w) => sum + w.paidHours);
    
    return [
      pw.SizedBox(height: 20),
      pw.Container(
        padding: pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.red50,
          border: pw.Border.all(color: PdfColors.red300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Icon(pw.IconData(0xe916), color: PdfColors.red700, size: 16), // alert icon
                pw.SizedBox(width: 8),
                pw.Text(
                  'BANK HOLIDAY PAY SUMMARY - PREMIUM RATES REQUIRED',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            
            // Bank holidays list
            pw.Text(
              'Bank holidays this week: ${bankHolidays.values.map((h) => h.name).join(', ')}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
            ),
            pw.SizedBox(height: 8),
            
            // Workers table
            pw.Table(
              border: pw.TableBorder.all(color: borderC),
              columnWidths: {
                0: pw.FlexColumnWidth(3.0), // Employee
                1: pw.FlexColumnWidth(2.0), // Holiday Name  
                2: pw.FlexColumnWidth(2.0), // Hours Worked
                3: pw.FlexColumnWidth(2.5), // Premium Pay Hours
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: headerBg),
                  children: [
                    _buildTableCell('Employee', headerFg, bold: true),
                    _buildTableCell('Bank Holiday', headerFg, bold: true),
                    _buildTableCell('Hours Worked', headerFg, bold: true),
                    _buildTableCell('Bank Holiday Hours\n(Double Time)', PdfColors.red, bold: true),
                  ],
                ),
                // Worker rows
                for (final worker in bankHolidayWorkers)
                  pw.TableRow(
                    children: [
                      _buildTableCell(worker.employeeName, PdfColors.black, bold: true),
                      _buildTableCell(worker.holidayName, PdfColors.red700, bold: true),
                      _buildTableCell(worker.paidHours.toStringAsFixed(2), PdfColors.green700, bold: true),
                      _buildTableCell('${(worker.paidHours * 2).toStringAsFixed(2)} hrs', PdfColors.red, bold: true),
                    ],
                  ),
                // Totals row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('TOTALS:', PdfColors.black, bold: true),
                    _buildTableCell('', PdfColors.black),
                    _buildTableCell(totalPaidHours.toStringAsFixed(2), PdfColors.green700, bold: true),
                    _buildTableCell('${(totalPaidHours * 2).toStringAsFixed(2)} hrs', PdfColors.red, bold: true),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 12),
            
            // Important notes
            pw.Container(
              padding: pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.yellow50,
                border: pw.Border.all(color: PdfColors.yellow300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PAYROLL SUMMARY:',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.amber700),
                  ),
                  pw.Text(
                    'Total Premium Hours to Pay: ${(totalPaidHours * 2).toStringAsFixed(2)} hours',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red),
                  ),
                  pw.Text(
                    '(Bank holiday work typically paid at double time)',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.amber700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Helper to calculate break deduction for a given number of hours
  static double _calculateBreakForShift(double hours) {
    if (hours >= 6.0) {
      return 0.5; // 30 minutes
    } else if (hours >= 4.5) {
      return 0.25; // 15 minutes
    }
    return 0.0;
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

  // Helper: check if a date is an Irish bank holiday
  static bool _isBankHoliday(DateTime? date) {
    if (date == null) return false;
    return IrishBankHolidays.isBankHoliday(date);
  }
}
