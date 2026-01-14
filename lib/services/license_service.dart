import 'package:shared_preferences/shared_preferences.dart';

/// App licensing and demo mode service
/// 
/// Controls whether the app is in demo/free mode or full/pro mode
/// Demo mode has limitations on number of staff and rosters
class LicenseService {
  static const String _licenseKeyPrefix = 'license_';
  static const String _isPurchasedKey = 'app_is_purchased';
  static const String _purchaseDateKey = 'app_purchase_date';
  static const String _demoModeKey = 'app_demo_mode';
  
  // Demo mode limits
  static const int maxStaffInDemo = 5;
  static const int maxRostersInDemo = 3;
  static const int maxWeeksInDemo = 4;
  
  static late SharedPreferences _prefs;
  
  /// Initialize the license service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Check if app is in demo/free mode
  static Future<bool> isDemoMode() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to demo mode (true) unless explicitly purchased
    return prefs.getBool(_demoModeKey) ?? true;
  }
  
  /// Check if user has purchased the full app
  static Future<bool> isPurchased() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isPurchasedKey) ?? false;
  }
  
  /// Get purchase date if available
  static Future<DateTime?> getPurchaseDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_purchaseDateKey);
    if (dateStr == null) return null;
    return DateTime.parse(dateStr);
  }
  
  /// Mark app as purchased (full version)
  /// In a real app, this would be called after successful IAP purchase
  static Future<void> markAsPurchased() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPurchasedKey, true);
    await prefs.setBool(_demoModeKey, false);
    await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());
    print('✅ App marked as purchased - full features unlocked!');
  }
  
  /// Reset to demo mode (for testing)
  static Future<void> resetToDemo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isPurchasedKey, false);
    await prefs.setBool(_demoModeKey, true);
    await prefs.remove(_purchaseDateKey);
    print('📱 App reset to demo mode');
  }
  
  /// Check if adding a new staff member would exceed demo limit
  static Future<bool> canAddMoreStaff(int currentStaffCount) async {
    if (await isPurchased()) return true; // Unlimited in full version
    return currentStaffCount < maxStaffInDemo;
  }
  
  /// Check if adding a new roster would exceed demo limit
  static Future<bool> canAddMoreRosters(int currentRosterCount) async {
    if (await isPurchased()) return true; // Unlimited in full version
    return currentRosterCount < maxRostersInDemo;
  }
  
  /// Check if user can create rosters for more weeks
  static Future<bool> canAddMoreWeeks(int currentWeekCount) async {
    if (await isPurchased()) return true; // Unlimited in full version
    return currentWeekCount < maxWeeksInDemo;
  }
  
  /// Get remaining demo slots for staff
  static Future<int> remainingStaffSlots(int currentStaffCount) async {
    if (await isPurchased()) return 999; // Effectively unlimited
    return (maxStaffInDemo - currentStaffCount).clamp(0, maxStaffInDemo);
  }
  
  /// Get remaining demo slots for rosters
  static Future<int> remainingRosterSlots(int currentRosterCount) async {
    if (await isPurchased()) return 999; // Effectively unlimited
    return (maxRostersInDemo - currentRosterCount).clamp(0, maxRostersInDemo);
  }
  
  /// Get remaining demo slots for weeks
  static Future<int> remainingWeekSlots(int currentWeekCount) async {
    if (await isPurchased()) return 999; // Effectively unlimited
    return (maxWeeksInDemo - currentWeekCount).clamp(0, maxWeeksInDemo);
  }
  
  /// Get demo mode status as a user-friendly string
  static Future<String> getDemoStatus() async {
    final purchased = await isPurchased();
    
    if (!purchased) {
      return '''
📱 DEMO MODE
───────────
You're using the demo version with limited features:
• Max ${maxStaffInDemo} staff members
• Max ${maxRostersInDemo} rosters
• Max ${maxWeeksInDemo} weeks per roster

Purchase the full app to unlock unlimited features!
''';
    }
    
    final purchaseDate = await getPurchaseDate();
    return '''
🔓 FULL VERSION UNLOCKED
──────────────────────
Purchased on: ${purchaseDate?.toString().split('.')[0] ?? 'Unknown'}
• Unlimited staff members
• Unlimited rosters
• Unlimited weeks
• Cloud sync (coming soon)
• Multi-device support (coming soon)
''';
  }
  
  /// Show upgrade prompt details
  static String getUpgradePromptMessage(String limitType) {
    return '''
🎉 Demo Limit Reached!

You've reached the ${limitType} limit in demo mode.

Upgrade to the full app to enjoy:
✓ Unlimited staff members
✓ Unlimited rosters  
✓ Unlimited weeks
✓ Cloud synchronization
✓ Multi-device support
✓ Priority support

Get the full version now!
''';
  }
}
