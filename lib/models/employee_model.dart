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
  final double? customHolidayHours; // NEW: custom hours deducted for this holiday

  Shift({
    this.startTime,
    this.endTime,
    this.role,
    this.comment, // NEW
    this.isHoliday = false,
    this.customColor, // <- new
    this.customHolidayHours, // NEW: defaults to null (uses 8 hours)
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
        'customHolidayHours': customHolidayHours, // NEW
      };

  static Shift fromJson(Map<String, dynamic> json) => Shift(
        startTime: TimeOfDayExtension.from24Hour(json['startTime'] as String?),
        endTime: TimeOfDayExtension.from24Hour(json['endTime'] as String?),
        role: json['role'] as String?,
        comment: json['comment'] as String?, // NEW
        isHoliday: (json['isHoliday'] as bool?) ?? false,
        customColor: (json['color'] is int) ? Color(json['color'] as int) : null,
        customHolidayHours: json['customHolidayHours'] as double?, // NEW
      );
}

class Employee {
  final String name;
  final Map<String, Shift> shifts;

  // NEW: Accumulated totals across all saved weeks (for management tracking)
  double accumulatedWorkedHours;  // total worked hours across all weeks
  double accumulatedTotalHours;   // total hours including breaks across all weeks

  // NEW: Accumulated holiday hours tracking
  double accumulatedHolidayHours; // total holiday hours available

  // NEW: per-employee color (used for name cell / default shift color)
  Color? employeeColor;

  // NEW: Week date tracking for this roster
  DateTime? rosterStartDate;  // Monday of the roster week
  DateTime? rosterEndDate;    // Sunday of the roster week

  Employee({
    required this.name,
    Map<String, Shift>? shifts,
    this.accumulatedWorkedHours = 0.0,
    this.accumulatedTotalHours = 0.0,
    this.accumulatedHolidayHours = 0.0,
    this.employeeColor,
    this.rosterStartDate,
    this.rosterEndDate,
  }) : shifts = shifts ?? {};

  double get totalWorkedHours {
    return shifts.values.fold(0, (sum, shift) => sum + shift.duration);
  }

  // Calculate break time based on hours worked (time deducted PER SHIFT for unpaid breaks)
  double get breakHours {
    double totalBreaks = 0.0;
    
    // Calculate breaks for EACH individual shift
    for (final shift in shifts.values) {
      final shiftHours = shift.duration;
      if (shiftHours >= 6.0) {
        totalBreaks += 0.5; // 30 minutes deducted per 6+ hour shift
      } else if (shiftHours >= 4.5) {
        totalBreaks += 0.25; // 15 minutes deducted per 4.5+ hour shift
      }
    }
    
    return totalBreaks;
  }

  // Total scheduled hours (what appears on public schedule - no break deductions shown)
  double get totalScheduledHours {
    return totalWorkedHours; // Raw scheduled time for public viewing
  }

  // Total paid hours (scheduled hours MINUS unpaid breaks - for management/payroll)
  double get totalPaidHours {
    return totalWorkedHours - breakHours;
  }

  // Calculate total holiday hours used in this roster (8 hours per holiday by default, or custom)
  double get totalHolidayHoursUsed {
    double holidayHours = 0.0;
    for (final shift in shifts.values) {
      if (shift.isHoliday) {
        holidayHours += shift.customHolidayHours ?? 8.0; // Use custom hours or default 8
      }
    }
    return holidayHours;
  }

  // Calculate remaining accumulated holiday hours after this roster
  double get remainingAccumulatedHolidayHours {
    // Calculate holiday hours earned this week (8% of worked hours)
    final holidayEarnedThisWeek = totalPaidHours * 0.08;
    
    // Calculate total available = accumulated + earned this week
    final totalAvailable = accumulatedHolidayHours + holidayEarnedThisWeek;
    
    // Subtract holiday hours used this week
    return totalAvailable - totalHolidayHoursUsed;
  }

  // Get holiday hours earned this week (8% of paid hours)
  double get holidayHoursEarnedThisWeek {
    return totalPaidHours * 0.08;
  }

  // Separate Mon-Sat vs Sunday hours (PAID hours after break deductions)
  double get totalMondayToSaturdayPaidHours {
    final weekdayShifts = shifts.entries.where((entry) {
      // Use abbreviated day names that match the UI: Mon, Tue, Wed, Thu, Fri, Sat
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return weekdays.contains(entry.key);
    });
    
    double totalPaid = 0.0;
    
    // Calculate paid hours for each weekday shift (scheduled - breaks)
    for (final entry in weekdayShifts) {
      final workedHours = entry.value.duration;
      double shiftBreaks = 0.0;
      
      // Calculate breaks per shift (deducted time)
      if (workedHours >= 6.0) {
        shiftBreaks = 0.5; // 30 minutes deducted
      } else if (workedHours >= 4.5) {
        shiftBreaks = 0.25; // 15 minutes deducted
      }
      
      totalPaid += workedHours - shiftBreaks; // SUBTRACT breaks
    }
    
    return totalPaid;
  }

  double get totalSundayPaidHours {
    final sundayShift = shifts['Sun']; // Use 'Sun' not 'Sunday'
    if (sundayShift == null) return 0.0;
    
    final workedHours = sundayShift.duration;
    
    // Calculate breaks for Sunday shift (deducted time)
    double sundayBreaks = 0.0;
    if (workedHours >= 6.0) {
      sundayBreaks = 0.5; // 30 minutes deducted
    } else if (workedHours >= 4.5) {
      sundayBreaks = 0.25; // 15 minutes deducted
    }
    
    return workedHours - sundayBreaks; // SUBTRACT breaks
  }

  // For backward compatibility - now returns paid hours (after break deductions)
  double get totalHours {
    return totalPaidHours;
  }

  // Keep old method names for compatibility but redirect to new logic
  double get totalMondayToSaturdayHours {
    return totalMondayToSaturdayPaidHours;
  }

  double get totalSundayHours {
    return totalSundayPaidHours;
  }

  // Additional getters for detailed breakdown
  double get mondayToSaturdayWorkedHours {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final weekdayShifts = shifts.entries.where((entry) => weekdays.contains(entry.key));
    return weekdayShifts.fold(0.0, (sum, entry) => sum + entry.value.duration);
  }

  double get mondayToSaturdayBreakHours {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final weekdayShifts = shifts.entries.where((entry) => weekdays.contains(entry.key));
    
    double totalBreaks = 0.0;
    for (final entry in weekdayShifts) {
      final workedHours = entry.value.duration;
      if (workedHours >= 6.0) {
        totalBreaks += 0.5;
      } else if (workedHours >= 4.5) {
        totalBreaks += 0.25;
      }
    }
    return totalBreaks;
  }

  double get sundayWorkedHours {
    final sundayShift = shifts['Sun']; // Use 'Sun' not 'Sunday'
    return sundayShift?.duration ?? 0.0;
  }

  double get sundayBreakHours {
    final sundayShift = shifts['Sun']; // Use 'Sun' not 'Sunday'
    if (sundayShift == null) return 0.0;
    
    final workedHours = sundayShift.duration;
    if (workedHours >= 6.0) {
      return 0.5;
    } else if (workedHours >= 4.5) {
      return 0.25;
    }
    return 0.0;
  }

  // Alias for PDF compatibility
  double get totalWorkedThisRoster => totalWorkedHours;

  // For API compatibility with callers; getters compute on demand.
  void calculateHours() {
    // no-op
  }

  Map<String, dynamic> toJson() {
    final json = {
      'name': name,
      'shifts': shifts.map((day, shift) => MapEntry(day, shift.toJson())),
      'accumulatedWorkedHours': accumulatedWorkedHours,
      'accumulatedTotalHours': accumulatedTotalHours,
      'accumulatedHolidayHours': accumulatedHolidayHours,
      'employeeColor': employeeColor?.value, // <- persist ARGB
      'rosterStartDate': rosterStartDate?.millisecondsSinceEpoch,
      'rosterEndDate': rosterEndDate?.millisecondsSinceEpoch,
    };
    print('🔍 Employee.toJson for $name: ${shifts.length} shifts, ${json.toString().substring(0, json.toString().length > 100 ? 100 : json.toString().length)}...');
    return json;
  }

  static Employee fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '') as String;
    print('🔧 Employee.fromJson for $name starting...');
    
    final shifts = (() {
      final raw = json['shifts'];
      print('🔧 Employee.fromJson $name: raw shifts type: ${raw.runtimeType}');
      if (raw is Map) {
        final shiftCount = raw.length;
        print('🔧 Employee.fromJson $name: processing $shiftCount shifts');
        return raw.map<String, Shift>((day, shiftJson) {
          return MapEntry(
            day.toString(),
            Shift.fromJson(Map<String, dynamic>.from(shiftJson as Map)),
          );
        });
      }
      print('🔧 Employee.fromJson $name: returning empty shifts map');
      return <String, Shift>{};
    })();
    
    print('🔧 Employee.fromJson $name: created with ${shifts.length} shifts');
    return Employee(
    name: name,
    shifts: shifts,
    accumulatedWorkedHours: _toDouble(json['accumulatedWorkedHours']),
    accumulatedTotalHours: _toDouble(json['accumulatedTotalHours']),
    accumulatedHolidayHours: _toDouble(json['accumulatedHolidayHours']),
    employeeColor: (json['employeeColor'] is int) ? Color(json['employeeColor'] as int) : null,
    rosterStartDate: json['rosterStartDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['rosterStartDate'] as int) : null,
    rosterEndDate: json['rosterEndDate'] != null ? DateTime.fromMillisecondsSinceEpoch(json['rosterEndDate'] as int) : null,
  );
  }
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
