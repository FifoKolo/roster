import 'package:flutter/material.dart';

/// Service for calculating Irish bank holidays
/// 
/// Ireland has both fixed and variable bank holidays:
/// 
/// **Fixed Dates:**
/// - New Year's Day (1 January)
/// - St. Patrick's Day (17 March) 
/// - May Day (1 May)
/// - June Holiday (1st Monday in June)
/// - August Holiday (1st Monday in August)
/// - October Holiday (last Monday in October)
/// - Christmas Day (25 December)
/// - St. Stephen's Day (26 December)
/// 
/// **Easter-Based (Variable):**
/// - Easter Monday (day after Easter Sunday)
/// 
/// **Special Rules:**
/// - If a bank holiday falls on weekend, it may be moved to Monday
/// - Some holidays have specific substitution rules
class IrishBankHolidays {
  
  /// Get all Irish bank holidays for a given year
  static List<BankHoliday> getHolidaysForYear(int year) {
    final holidays = <BankHoliday>[];
    
    // Fixed holidays
    holidays.addAll(_getFixedHolidays(year));
    
    // Easter-based holidays  
    holidays.addAll(_getEasterBasedHolidays(year));
    
    // Sort by date
    holidays.sort((a, b) => a.date.compareTo(b.date));
    
    return holidays;
  }
  
  /// Check if a specific date is an Irish bank holiday
  static BankHoliday? getBankHoliday(DateTime date) {
    final year = date.year;
    final holidays = getHolidaysForYear(year);
    
    // Check exact date match
    for (final holiday in holidays) {
      if (_isSameDay(holiday.date, date)) {
        return holiday;
      }
    }
    
    return null;
  }
  
  /// Check if a date is a bank holiday (boolean)
  static bool isBankHoliday(DateTime date) {
    return getBankHoliday(date) != null;
  }
  
  /// Get all bank holidays in a date range
  static List<BankHoliday> getHolidaysInRange(DateTime start, DateTime end) {
    final holidays = <BankHoliday>[];
    
    // Get holidays for all years in the range
    for (int year = start.year; year <= end.year; year++) {
      holidays.addAll(getHolidaysForYear(year));
    }
    
    // Filter to date range
    return holidays.where((holiday) {
      return holiday.date.isAfter(start.subtract(const Duration(days: 1))) &&
             holiday.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }
  
  /// Get fixed holidays for a year
  static List<BankHoliday> _getFixedHolidays(int year) {
    final holidays = <BankHoliday>[];
    
    // New Year's Day (1 January)
    holidays.add(BankHoliday(
      name: "New Year's Day",
      date: _applyWeekendRule(DateTime(year, 1, 1)),
      type: BankHolidayType.fixed,
      description: "Start of the new year",
    ));
    
    // St. Patrick's Day (17 March)
    holidays.add(BankHoliday(
      name: "St. Patrick's Day",
      date: _applyWeekendRule(DateTime(year, 3, 17)),
      type: BankHolidayType.fixed,
      description: "Ireland's national day",
    ));
    
    // May Day (1 May)
    holidays.add(BankHoliday(
      name: "May Day",
      date: _applyWeekendRule(DateTime(year, 5, 1)),
      type: BankHolidayType.fixed,
      description: "International Workers' Day",
    ));
    
    // June Holiday (1st Monday in June)
    holidays.add(BankHoliday(
      name: "June Holiday",
      date: _getFirstMondayOfMonth(year, 6),
      type: BankHolidayType.moveable,
      description: "First Monday in June",
    ));
    
    // August Holiday (1st Monday in August)
    holidays.add(BankHoliday(
      name: "August Holiday",
      date: _getFirstMondayOfMonth(year, 8),
      type: BankHolidayType.moveable,
      description: "First Monday in August",
    ));
    
    // October Holiday (last Monday in October)
    holidays.add(BankHoliday(
      name: "October Holiday",
      date: _getLastMondayOfMonth(year, 10),
      type: BankHolidayType.moveable,
      description: "Last Monday in October",
    ));
    
    // Christmas Day (25 December)
    holidays.add(BankHoliday(
      name: "Christmas Day",
      date: _applyWeekendRule(DateTime(year, 12, 25)),
      type: BankHolidayType.fixed,
      description: "Christmas celebration",
    ));
    
    // St. Stephen's Day (26 December)
    holidays.add(BankHoliday(
      name: "St. Stephen's Day",
      date: _applyStStephensRule(DateTime(year, 12, 26)),
      type: BankHolidayType.fixed,
      description: "Day after Christmas",
    ));
    
    return holidays;
  }
  
  /// Get Easter-based holidays for a year
  static List<BankHoliday> _getEasterBasedHolidays(int year) {
    final holidays = <BankHoliday>[];
    
    // Calculate Easter Sunday
    final easterSunday = _calculateEaster(year);
    
    // Easter Monday (day after Easter Sunday)
    holidays.add(BankHoliday(
      name: "Easter Monday",
      date: easterSunday.add(const Duration(days: 1)),
      type: BankHolidayType.easter,
      description: "Day after Easter Sunday",
    ));
    
    return holidays;
  }
  
  /// Calculate Easter Sunday using the algorithm
  /// Based on the algorithm for Western Christianity
  static DateTime _calculateEaster(int year) {
    // Easter calculation algorithm
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    
    return DateTime(year, month, day);
  }
  
  /// Apply weekend substitution rule for fixed holidays
  static DateTime _applyWeekendRule(DateTime date) {
    // If holiday falls on weekend, move to Monday
    if (date.weekday == DateTime.saturday) {
      return date.add(const Duration(days: 2));
    } else if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    return date;
  }
  
  /// Special rule for St. Stephen's Day
  static DateTime _applyStStephensRule(DateTime date) {
    // Complex rules when Christmas and St. Stephen's fall on weekends
    final christmas = DateTime(date.year, 12, 25);
    
    if (christmas.weekday == DateTime.saturday) {
      // Christmas moves to Monday, St. Stephen's to Tuesday
      return DateTime(date.year, 12, 28);
    } else if (christmas.weekday == DateTime.sunday) {
      // Christmas moves to Monday, St. Stephen's to Tuesday  
      return DateTime(date.year, 12, 27);
    } else if (date.weekday == DateTime.saturday) {
      // St. Stephen's on Saturday moves to Monday
      return date.add(const Duration(days: 2));
    } else if (date.weekday == DateTime.sunday) {
      // St. Stephen's on Sunday moves to Monday
      return date.add(const Duration(days: 1));
    }
    
    return date;
  }
  
  /// Get first Monday of a month
  static DateTime _getFirstMondayOfMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final daysUntilMonday = (DateTime.monday - firstDay.weekday + 7) % 7;
    return firstDay.add(Duration(days: daysUntilMonday));
  }
  
  /// Get last Monday of a month
  static DateTime _getLastMondayOfMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0); // Last day of month
    final daysSinceMonday = (lastDay.weekday - DateTime.monday + 7) % 7;
    return lastDay.subtract(Duration(days: daysSinceMonday));
  }
  
  /// Check if two dates are the same day
  static bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  /// Get visual styling for bank holidays
  static BankHolidayStyle getHolidayStyle(BankHoliday holiday) {
    switch (holiday.type) {
      case BankHolidayType.fixed:
        return BankHolidayStyle(
          backgroundColor: Colors.red.shade50,
          borderColor: Colors.red.shade300,
          textColor: Colors.red.shade800,
          icon: Icons.event,
        );
      case BankHolidayType.easter:
        return BankHolidayStyle(
          backgroundColor: Colors.purple.shade50,
          borderColor: Colors.purple.shade300,
          textColor: Colors.purple.shade800,
          icon: Icons.celebration,
        );
      case BankHolidayType.moveable:
        return BankHolidayStyle(
          backgroundColor: Colors.orange.shade50,
          borderColor: Colors.orange.shade300,
          textColor: Colors.orange.shade800,
          icon: Icons.today,
        );
    }
  }
}

/// Represents an Irish bank holiday
class BankHoliday {
  final String name;
  final DateTime date;
  final BankHolidayType type;
  final String description;
  
  const BankHoliday({
    required this.name,
    required this.date,
    required this.type,
    required this.description,
  });
  
  /// Format the holiday for display
  String get displayName => name;
  
  /// Get formatted date string
  String get formattedDate {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month]}';
  }
  
  @override
  String toString() => '$name ($formattedDate)';
}

/// Type of bank holiday
enum BankHolidayType {
  fixed,      // Fixed date (may move for weekends)
  easter,     // Based on Easter calculation
  moveable,   // Specific day of week in month
}

/// Visual styling for bank holidays
class BankHolidayStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  
  const BankHolidayStyle({
    required this.backgroundColor,
    required this.borderColor, 
    required this.textColor,
    required this.icon,
  });
}