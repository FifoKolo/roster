import 'package:flutter/material.dart';

// Data models for the roster app.
//
// - Shift: represents one day's shift for an employee. Holds start/end TimeOfDay,
//   optional role/comment, holiday flag, and optional custom color.
//   Includes helpers:
//     - duration: hours between start and end (0 if holiday or missing times).
//     - formatted(): human readable "HH:MM - HH:MM" or "Holiday".
//     - toJson/fromJson: persistable representation.
//
// - Employee: represents one staff member and their weekly shifts map.
//   Includes:
//     - calculateHours(): recomputes total worked hours and derived holiday hours.
//     - toJson/fromJson: persist/load from SharedPreferences.

class Shift {
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String? role;
  final String? comment; // NEW: optional comment
  final bool isHoliday;
  final Color? customColor; // <- optional custom cell color

  Shift({
    this.startTime,
    this.endTime,
    this.role,
    this.comment, // NEW
    this.isHoliday = false,
    this.customColor, // <- new
  });

  double get duration {
    if (isHoliday || startTime == null || endTime == null) return 0;
    // Fix: month/day must be >= 1
    final start = DateTime(0, 1, 1, startTime!.hour, startTime!.minute);
    final end = DateTime(0, 1, 1, endTime!.hour, endTime!.minute);
    return end.difference(start).inMinutes / 60.0;
  }

  // Human readable formatting used by table/PDF
  String formatted() {
    if (isHoliday) return 'Holiday';
    if (startTime == null || endTime == null) return '-';
    final base = '${startTime!.format24Hour()} - ${endTime!.format24Hour()}';
    final r = (role ?? '').trim();
    final c = (comment ?? '').trim();
    if (r.isEmpty && c.isEmpty) return base;
    if (r.isNotEmpty && c.isNotEmpty) return '$base\n$r — $c';
    return '$base\n${r.isNotEmpty ? r : c}';
  }

  Map<String, dynamic> toJson() => {
        'startTime': startTime?.format24Hour(),
        'endTime': endTime?.format24Hour(),
        'role': role,
        'comment': comment, // NEW
        'isHoliday': isHoliday,
        'color': customColor?.value, // ARGB int
      };

  static Shift fromJson(Map<String, dynamic> json) => Shift(
        startTime: TimeOfDayExtension.from24Hour(json['startTime'] as String?),
        endTime: TimeOfDayExtension.from24Hour(json['endTime'] as String?),
        role: json['role'] as String?,
        comment: json['comment'] as String?, // NEW
        isHoliday: (json['isHoliday'] as bool?) ?? false,
        customColor: (json['color'] is int) ? Color(json['color'] as int) : null,
      );
}

class Employee {
  final String name;
  final Map<String, Shift> shifts;

  // New holiday fields
  double manualHolidayHours;      // user-entered per roster
  double carryOverHolidayHours;   // accumulated from previous roster

  // NEW: Accumulated totals across all saved weeks (for management tracking)
  double accumulatedWorkedHours;  // total worked hours across all weeks
  double accumulatedHolidayHours; // total holiday hours across all weeks

  // NEW: per-employee color (used for name cell / default shift color)
  Color? employeeColor;

  Employee({
    required this.name,
    Map<String, Shift>? shifts,
    this.manualHolidayHours = 0.0,
    this.carryOverHolidayHours = 0.0,
    this.accumulatedWorkedHours = 0.0,
    this.accumulatedHolidayHours = 0.0,
    this.employeeColor,
  }) : shifts = shifts ?? {};

  double get totalWorkedHours {
    return shifts.values.fold(0, (sum, shift) => sum + shift.duration);
  }

  // Alias for PDF compatibility
  double get totalWorkedThisRoster => totalWorkedHours;

  // Weekly auto holiday hours (8% of worked)
  double get holidayHours {
    // Count holiday days taken this roster (8 hours per holiday day)
    final holidayDaysTaken = shifts.values.where((shift) => shift.isHoliday).length;
    final holidayHoursUsed = holidayDaysTaken * 8.0;
    
    // Calculate earned holiday hours (8% of worked hours)
    final earnedHolidayHours = totalWorkedHours * 0.08;
    
    // Return net holiday hours (earned minus used)
    return earnedHolidayHours - holidayHoursUsed;
  }

  // Helper getter: hours used for holidays this roster
  double get holidayHoursUsedThisRoster {
    final holidayDaysTaken = shifts.values.where((shift) => shift.isHoliday).length;
    return holidayDaysTaken * 8.0;
  }

  // Helper getter: hours earned from work this roster  
  double get holidayHoursEarnedThisRoster {
    return totalWorkedHours * 0.08;
  }

  // Total holiday represented in this roster (carry-over + manual + auto)
  double get totalHolidayThisRoster {
    return carryOverHolidayHours + manualHolidayHours + holidayHours;
  }

  // For API compatibility with callers; getters compute on demand.
  void calculateHours() {
    // no-op
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'shifts': shifts.map((day, shift) => MapEntry(day, shift.toJson())),
    'manualHolidayHours': manualHolidayHours,
    'carryOverHolidayHours': carryOverHolidayHours,
    'accumulatedWorkedHours': accumulatedWorkedHours,
    'accumulatedHolidayHours': accumulatedHolidayHours,
    'employeeColor': employeeColor?.value, // <- persist ARGB
  };

  static Employee fromJson(Map<String, dynamic> json) => Employee(
    name: (json['name'] ?? '') as String,
    shifts: (() {
      final raw = json['shifts'];
      if (raw is Map) {
        return raw.map<String, Shift>((day, shiftJson) {
          return MapEntry(
            day.toString(),
            Shift.fromJson(Map<String, dynamic>.from(shiftJson as Map)),
          );
        });
      }
      return <String, Shift>{};
    })(),
    manualHolidayHours: _toDouble(json['manualHolidayHours']),
    carryOverHolidayHours: _toDouble(json['carryOverHolidayHours']),
    accumulatedWorkedHours: _toDouble(json['accumulatedWorkedHours']),
    accumulatedHolidayHours: _toDouble(json['accumulatedHolidayHours']),
    employeeColor: (json['employeeColor'] is int) ? Color(json['employeeColor'] as int) : null,
  );
}

// Safe numeric parsing
double _toDouble(Object? v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

extension TimeOfDayExtension on TimeOfDay {
  // Converts TimeOfDay to a 24-hour formatted string (e.g., "14:30").
  String format24Hour() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Parses a 24-hour formatted string (nullable-safe).
  static TimeOfDay? from24Hour(String? time) {
    if (time == null) return null;
    final reg = RegExp(r'^\d{2}:\d{2}$');
    if (!reg.hasMatch(time)) return null;
    final parts = time.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
