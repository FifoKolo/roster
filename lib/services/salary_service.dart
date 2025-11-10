import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/salary_model.dart';
import '../models/employee_model.dart';

class SalaryService {
  static const String _salaryProfilesKey = 'salary_profiles';
  static const String _globalSettingsKey = 'global_salary_settings';

  // Save salary profile for an employee
  static Future<void> saveSalaryProfile(SalaryProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_salaryProfilesKey) ?? '{}';
    final profiles = Map<String, dynamic>.from(json.decode(profilesJson));
    
    profiles[profile.employeeId] = profile.toJson();
    
    await prefs.setString(_salaryProfilesKey, json.encode(profiles));
    print('💰 Saved salary profile for employee: ${profile.employeeId}');
  }

  // Load salary profile for an employee
  static Future<SalaryProfile?> loadSalaryProfile(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_salaryProfilesKey) ?? '{}';
    final profiles = Map<String, dynamic>.from(json.decode(profilesJson));
    
    if (profiles.containsKey(employeeId)) {
      return SalaryProfile.fromJson(profiles[employeeId]);
    }
    
    return null;
  }

  // Load all salary profiles
  static Future<Map<String, SalaryProfile>> loadAllSalaryProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_salaryProfilesKey) ?? '{}';
    final profiles = Map<String, dynamic>.from(json.decode(profilesJson));
    
    final result = <String, SalaryProfile>{};
    for (final entry in profiles.entries) {
      result[entry.key] = SalaryProfile.fromJson(entry.value);
    }
    
    return result;
  }

  // Delete salary profile for an employee
  static Future<void> deleteSalaryProfile(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getString(_salaryProfilesKey) ?? '{}';
    final profiles = Map<String, dynamic>.from(json.decode(profilesJson));
    
    profiles.remove(employeeId);
    
    await prefs.setString(_salaryProfilesKey, json.encode(profiles));
    print('💰 Deleted salary profile for employee: $employeeId');
  }

  // Save global salary settings
  static Future<void> saveGlobalSettings(GlobalSalarySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_globalSettingsKey, json.encode(settings.toJson()));
    print('⚙️ Saved global salary settings');
  }

  // Load global salary settings
  static Future<GlobalSalarySettings> loadGlobalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_globalSettingsKey);
    
    if (settingsJson != null) {
      return GlobalSalarySettings.fromJson(json.decode(settingsJson));
    }
    
    // Return default settings if none exist
    return GlobalSalarySettings();
  }

  // Create a new salary profile with default bonuses from global settings
  static Future<SalaryProfile> createDefaultProfile(String employeeId, double baseSalaryPerHour) async {
    final globalSettings = await loadGlobalSettings();
    
    return SalaryProfile(
      employeeId: employeeId,
      baseSalaryPerHour: baseSalaryPerHour,
      sundayBonusPercentage: globalSettings.defaultSundayBonusPercentage,
      bankHolidayBonusPercentage: globalSettings.defaultBankHolidayBonusPercentage,
      christmasBonusPercentage: globalSettings.defaultChristmasBonusPercentage,
    );
  }

  // Calculate total earnings for an employee based on paid hours and salary profile
  static Future<Map<String, double>> calculateEarningsFromEmployee(Employee employee, Map<String, DateTime> weekDates, {double? previousWeekWorkedHours}) async {
    final profile = await loadSalaryProfile(employee.name);
    final globalSettings = await loadGlobalSettings();
    
    if (profile == null) {
      return {
        'baseEarnings': 0.0,
        'sundayBonus': 0.0,
        'bankHolidayBonus': 0.0,
        'christmasBonus': 0.0,
        'irishBankHolidayEntitlement': 0.0,
        'paidBreakTime': 0.0,
        'totalEarnings': 0.0,
      };
    }

    // Calculate paid break time based on global settings and per-shift toggles
    double totalPaidBreakHours = 0.0;
    
    if (globalSettings.enableAutomaticBreaks) {
      for (final entry in employee.shifts.entries) {
        final shift = entry.value;
        if (shift.isHoliday || shift.duration <= 0) continue;
        
        bool shouldCalculateBreak = false;
        
        // Determine if break should be calculated based on behavior
        switch (globalSettings.breakBehavior) {
          case 'always_on':
            shouldCalculateBreak = true;
            break;
          case 'always_off':
            shouldCalculateBreak = false;
            break;
          case 'per_shift_toggle':
          default:
            // Use per-shift setting, defaulting to true if not set
            shouldCalculateBreak = shift.enablePaidBreak ?? true;
            break;
        }
        
        if (shouldCalculateBreak) {
          // Calculate automatic break time based on shift duration
          final automaticBreakMinutes = GlobalSalarySettings.getAutomaticBreakMinutes(shift.duration);
          totalPaidBreakHours += automaticBreakMinutes / 60.0;
        }
      }
    } else {
      // Use manual break calculation from global settings
      int shiftsWorked = 0;
      for (final shift in employee.shifts.values) {
        if (!shift.isHoliday && shift.duration > 0) {
          shiftsWorked++;
        }
      }
      totalPaidBreakHours = (shiftsWorked * globalSettings.defaultPaidBreakMinutesPerShift) / 60.0;
    }

    // Use PAID HOURS (including breaks) for base calculation
    final adjustedPaidHours = employee.totalPaidHours + totalPaidBreakHours;
    final baseEarnings = adjustedPaidHours * profile.baseSalaryPerHour;
    
    double sundayBonus = 0.0;
    double bankHolidayBonus = 0.0;
    double christmasBonus = 0.0;
    double irishBankHolidayEntitlement = 0.0;

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Calculate bonuses per shift and Irish bank holiday entitlement
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final shift = employee.shifts[day];
      final date = weekDates[day];
      
      if (date == null) continue;
      
      // Check for Irish bank holiday entitlement (when employee doesn't work on bank holiday)
      if (globalSettings.enableIrishBankHolidayEntitlement && 
          _isIrishBankHoliday(date) && 
          (shift == null || (!shift.isHoliday && shift.duration == 0))) {
        
        // Calculate 1/5th of previous week's worked hours
        final entitlementHours = (previousWeekWorkedHours ?? 0.0) / 5.0;
        if (entitlementHours > 0) {
          irishBankHolidayEntitlement += entitlementHours * profile.baseSalaryPerHour;
        }
      }
      
      if (shift == null) continue;
      
      // For bonuses, use the actual shift duration (or holiday hours if it's a holiday)
      double shiftHours = 0.0;
      if (shift.isHoliday) {
        // Use the holiday hours deducted (custom or default 8 hours)
        shiftHours = shift.customHolidayHours ?? 8.0;
      } else {
        shiftHours = shift.duration;
      }
      
      if (shiftHours <= 0) continue;
      
      final shiftEarnings = shiftHours * profile.baseSalaryPerHour;
      
      // Check for Sunday bonus
      if (i == 6) { // Sunday is index 6
        sundayBonus += shiftEarnings * (profile.sundayBonusPercentage / 100);
      }
      
      // Check for bank holiday bonus (when working on bank holiday)
      if (shift.isHoliday) {
        bankHolidayBonus += shiftEarnings * (profile.bankHolidayBonusPercentage / 100);
      }
      
      // Check for Christmas bonus (December 25th)
      if (date.month == 12 && date.day == 25) {
        christmasBonus += shiftEarnings * (profile.christmasBonusPercentage / 100);
      }
    }

    final paidBreakEarnings = totalPaidBreakHours * profile.baseSalaryPerHour;
    final totalEarnings = baseEarnings + sundayBonus + bankHolidayBonus + christmasBonus + irishBankHolidayEntitlement;

    return {
      'baseEarnings': baseEarnings - paidBreakEarnings, // Base without breaks for clarity
      'sundayBonus': sundayBonus,
      'bankHolidayBonus': bankHolidayBonus,
      'christmasBonus': christmasBonus,
      'irishBankHolidayEntitlement': irishBankHolidayEntitlement,
      'paidBreakTime': paidBreakEarnings,
      'totalEarnings': totalEarnings,
    };
  }

  // Helper method to check if a date is an Irish bank holiday
  static bool _isIrishBankHoliday(DateTime date) {
    // Import the existing Irish bank holidays service
    // This should integrate with your existing IrishBankHolidays service
    return _getIrishBankHolidays(date.year).any((holiday) =>
        holiday.month == date.month && holiday.day == date.day);
  }

  // Get Irish bank holidays for a year (simplified version)
  static List<DateTime> _getIrishBankHolidays(int year) {
    return [
      DateTime(year, 1, 1),   // New Year's Day
      DateTime(year, 3, 17),  // St. Patrick's Day
      DateTime(year, 12, 25), // Christmas Day
      DateTime(year, 12, 26), // St. Stephen's Day
      // Add Easter Monday calculation
      _getEasterMonday(year),
      // Add first Monday in May
      _getFirstMondayInMay(year),
      // Add first Monday in June
      _getFirstMondayInJune(year),
      // Add first Monday in August
      _getFirstMondayInAugust(year),
      // Add last Monday in October
      _getLastMondayInOctober(year),
    ];
  }

  static DateTime _getEasterMonday(int year) {
    // Simplified Easter calculation (you might want to use a more precise algorithm)
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
    return DateTime(year, month, day + 1); // Monday after Easter
  }

  static DateTime _getFirstMondayInMay(int year) {
    final firstOfMay = DateTime(year, 5, 1);
    final dayOfWeek = firstOfMay.weekday;
    final daysToAdd = dayOfWeek == 1 ? 0 : 8 - dayOfWeek;
    return firstOfMay.add(Duration(days: daysToAdd));
  }

  static DateTime _getFirstMondayInJune(int year) {
    final firstOfJune = DateTime(year, 6, 1);
    final dayOfWeek = firstOfJune.weekday;
    final daysToAdd = dayOfWeek == 1 ? 0 : 8 - dayOfWeek;
    return firstOfJune.add(Duration(days: daysToAdd));
  }

  static DateTime _getFirstMondayInAugust(int year) {
    final firstOfAugust = DateTime(year, 8, 1);
    final dayOfWeek = firstOfAugust.weekday;
    final daysToAdd = dayOfWeek == 1 ? 0 : 8 - dayOfWeek;
    return firstOfAugust.add(Duration(days: daysToAdd));
  }

  static DateTime _getLastMondayInOctober(int year) {
    final lastOfOctober = DateTime(year, 10, 31);
    final dayOfWeek = lastOfOctober.weekday;
    final daysToSubtract = dayOfWeek == 1 ? 0 : dayOfWeek - 1;
    return lastOfOctober.subtract(Duration(days: daysToSubtract));
  }

  // Calculate total earnings for an employee based on shifts and salary profile
  static Future<Map<String, double>> calculateEarnings(String employeeId, Map<String, dynamic> shifts, Map<String, DateTime> weekDates) async {
    final profile = await loadSalaryProfile(employeeId);
    
    if (profile == null) {
      return {
        'baseEarnings': 0.0,
        'sundayBonus': 0.0,
        'bankHolidayBonus': 0.0,
        'christmasBonus': 0.0,
        'totalEarnings': 0.0,
      };
    }

    double baseEarnings = 0.0;
    double sundayBonus = 0.0;
    double bankHolidayBonus = 0.0;
    double christmasBonus = 0.0;

    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    for (int i = 0; i < days.length; i++) {
      final day = days[i];
      final shift = shifts[day];
      
      if (shift == null) continue;
      
      final date = weekDates[day];
      if (date == null) continue;
      
      // Parse shift duration (assuming it's stored as hours)
      final duration = shift['duration'] ?? 0.0;
      if (duration <= 0) continue;
      
      final dayEarnings = duration * profile.baseSalaryPerHour;
      baseEarnings += dayEarnings;
      
      // Check for Sunday bonus
      if (i == 6) { // Sunday is index 6
        sundayBonus += dayEarnings * (profile.sundayBonusPercentage / 100);
      }
      
      // Check for bank holiday bonus
      if (shift['isHoliday'] == true) {
        bankHolidayBonus += dayEarnings * (profile.bankHolidayBonusPercentage / 100);
      }
      
      // Check for Christmas bonus (December 25th)
      if (date.month == 12 && date.day == 25) {
        christmasBonus += dayEarnings * (profile.christmasBonusPercentage / 100);
      }
    }

    final totalEarnings = baseEarnings + sundayBonus + bankHolidayBonus + christmasBonus;

    return {
      'baseEarnings': baseEarnings,
      'sundayBonus': sundayBonus,
      'bankHolidayBonus': bankHolidayBonus,
      'christmasBonus': christmasBonus,
      'totalEarnings': totalEarnings,
    };
  }
}