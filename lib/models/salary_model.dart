class SalaryProfile {
  final String employeeId;
  final double baseSalaryPerHour;
  final double sundayBonusPercentage;
  final double bankHolidayBonusPercentage;
  final double christmasBonusPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  SalaryProfile({
    required this.employeeId,
    required this.baseSalaryPerHour,
    this.sundayBonusPercentage = 0.0,
    this.bankHolidayBonusPercentage = 0.0,
    this.christmasBonusPercentage = 0.0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'baseSalaryPerHour': baseSalaryPerHour,
      'sundayBonusPercentage': sundayBonusPercentage,
      'bankHolidayBonusPercentage': bankHolidayBonusPercentage,
      'christmasBonusPercentage': christmasBonusPercentage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SalaryProfile.fromJson(Map<String, dynamic> json) {
    return SalaryProfile(
      employeeId: json['employeeId'] ?? '',
      baseSalaryPerHour: (json['baseSalaryPerHour'] ?? 0.0).toDouble(),
      sundayBonusPercentage: (json['sundayBonusPercentage'] ?? 0.0).toDouble(),
      bankHolidayBonusPercentage: (json['bankHolidayBonusPercentage'] ?? 0.0).toDouble(),
      christmasBonusPercentage: (json['christmasBonusPercentage'] ?? 0.0).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  SalaryProfile copyWith({
    String? employeeId,
    double? baseSalaryPerHour,
    double? sundayBonusPercentage,
    double? bankHolidayBonusPercentage,
    double? christmasBonusPercentage,
  }) {
    return SalaryProfile(
      employeeId: employeeId ?? this.employeeId,
      baseSalaryPerHour: baseSalaryPerHour ?? this.baseSalaryPerHour,
      sundayBonusPercentage: sundayBonusPercentage ?? this.sundayBonusPercentage,
      bankHolidayBonusPercentage: bankHolidayBonusPercentage ?? this.bankHolidayBonusPercentage,
      christmasBonusPercentage: christmasBonusPercentage ?? this.christmasBonusPercentage,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class GlobalSalarySettings {
  final double defaultSundayBonusPercentage;
  final double defaultBankHolidayBonusPercentage;
  final double defaultChristmasBonusPercentage;
  final double defaultPaidBreakMinutesPerShift;
  final bool enableIrishBankHolidayEntitlement;
  final bool enableAutomaticBreaks;
  final String breakBehavior; // 'always_on', 'always_off', 'per_shift_toggle'
  final DateTime updatedAt;

  GlobalSalarySettings({
    this.defaultSundayBonusPercentage = 25.0,
    this.defaultBankHolidayBonusPercentage = 50.0,
    this.defaultChristmasBonusPercentage = 100.0,
    this.defaultPaidBreakMinutesPerShift = 30.0,
    this.enableIrishBankHolidayEntitlement = true,
    this.enableAutomaticBreaks = true,
    this.breakBehavior = 'per_shift_toggle',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'defaultSundayBonusPercentage': defaultSundayBonusPercentage,
      'defaultBankHolidayBonusPercentage': defaultBankHolidayBonusPercentage,
      'defaultChristmasBonusPercentage': defaultChristmasBonusPercentage,
      'defaultPaidBreakMinutesPerShift': defaultPaidBreakMinutesPerShift,
      'enableIrishBankHolidayEntitlement': enableIrishBankHolidayEntitlement,
      'enableAutomaticBreaks': enableAutomaticBreaks,
      'breakBehavior': breakBehavior,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GlobalSalarySettings.fromJson(Map<String, dynamic> json) {
    return GlobalSalarySettings(
      defaultSundayBonusPercentage: (json['defaultSundayBonusPercentage'] ?? 25.0).toDouble(),
      defaultBankHolidayBonusPercentage: (json['defaultBankHolidayBonusPercentage'] ?? 50.0).toDouble(),
      defaultChristmasBonusPercentage: (json['defaultChristmasBonusPercentage'] ?? 100.0).toDouble(),
      defaultPaidBreakMinutesPerShift: (json['defaultPaidBreakMinutesPerShift'] ?? 30.0).toDouble(),
      enableIrishBankHolidayEntitlement: json['enableIrishBankHolidayEntitlement'] ?? true,
      enableAutomaticBreaks: json['enableAutomaticBreaks'] ?? true,
      breakBehavior: json['breakBehavior'] ?? 'per_shift_toggle',
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  GlobalSalarySettings copyWith({
    double? defaultSundayBonusPercentage,
    double? defaultBankHolidayBonusPercentage,
    double? defaultChristmasBonusPercentage,
    double? defaultPaidBreakMinutesPerShift,
    bool? enableIrishBankHolidayEntitlement,
    bool? enableAutomaticBreaks,
    String? breakBehavior,
  }) {
    return GlobalSalarySettings(
      defaultSundayBonusPercentage: defaultSundayBonusPercentage ?? this.defaultSundayBonusPercentage,
      defaultBankHolidayBonusPercentage: defaultBankHolidayBonusPercentage ?? this.defaultBankHolidayBonusPercentage,
      defaultChristmasBonusPercentage: defaultChristmasBonusPercentage ?? this.defaultChristmasBonusPercentage,
      defaultPaidBreakMinutesPerShift: defaultPaidBreakMinutesPerShift ?? this.defaultPaidBreakMinutesPerShift,
      enableIrishBankHolidayEntitlement: enableIrishBankHolidayEntitlement ?? this.enableIrishBankHolidayEntitlement,
      enableAutomaticBreaks: enableAutomaticBreaks ?? this.enableAutomaticBreaks,
      breakBehavior: breakBehavior ?? this.breakBehavior,
      updatedAt: DateTime.now(),
    );
  }

  // Calculate automatic break time based on shift duration
  static double getAutomaticBreakMinutes(double shiftHours) {
    if (shiftHours >= 6.0) {
      return 30.0; // 30 minutes for 6+ hours
    } else if (shiftHours >= 4.5) {
      return 15.0; // 15 minutes for 4.5+ hours
    } else {
      return 0.0; // No break for less than 4.5 hours
    }
  }
}