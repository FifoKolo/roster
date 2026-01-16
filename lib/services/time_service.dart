import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Provides accurate time using NTP (Network Time Protocol)
/// Falls back to device time if NTP fails
class TimeService {
  static DateTime? _cachedAccurateTime;
  static DateTime? _lastSyncTime;
  static int? _timeOffsetMs;
  
  /// Get the current accurate time
  /// Syncs with NTP if cache is stale (> 1 hour old) or missing
  static Future<DateTime> now() async {
    // Check if we need to sync
    if (_shouldSync()) {
      await _syncWithNTP();
    }
    
    // Return cached accurate time or device time
    if (_timeOffsetMs != null) {
      return DateTime.now().add(Duration(milliseconds: _timeOffsetMs!));
    }
    
    return DateTime.now();
  }
  
  /// Get current time synchronously (uses cached offset)
  /// Falls back to DateTime.now() if no offset cached
  static DateTime nowSync() {
    if (_timeOffsetMs != null) {
      return DateTime.now().add(Duration(milliseconds: _timeOffsetMs!));
    }
    return DateTime.now();
  }
  
  /// Check if we should sync with NTP
  static bool _shouldSync() {
    if (_timeOffsetMs == null || _lastSyncTime == null) {
      return true;
    }
    
    final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceSync > Duration(hours: 1);
  }
  
  /// Sync time with NTP server
  static Future<void> _syncWithNTP() async {
    // Skip NTP sync on web platform - InternetAddress.lookup not supported
    if (kIsWeb) {
      print('🌐 Web platform detected - using browser time (NTP not supported)');
      _timeOffsetMs = 0; // Use device/browser time
      _lastSyncTime = DateTime.now();
      return;
    }
    
    try {
      print('⏰ Syncing time with NTP server...');
      
      final offset = await NTP.getNtpOffset(
        localTime: DateTime.now(),
        lookUpAddress: 'time.google.com',
        timeout: Duration(seconds: 5),
      );
      
      _timeOffsetMs = offset;
      _lastSyncTime = DateTime.now();
      _cachedAccurateTime = DateTime.now().add(Duration(milliseconds: offset));
      
      // Cache offset to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('time_offset_ms', offset);
      await prefs.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
      
      print('✅ Time synced! Offset: ${offset}ms (${(offset / 1000).toStringAsFixed(1)}s)');
      print('   Accurate time: ${_cachedAccurateTime!.toIso8601String()}');
    } catch (e) {
      print('⚠️ NTP sync failed, using device time: $e');
      
      // Try to load cached offset from previous sync
      await _loadCachedOffset();
    }
  }
  
  /// Load previously cached time offset
  static Future<void> _loadCachedOffset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedOffset = prefs.getInt('time_offset_ms');
      final cachedSyncTime = prefs.getInt('last_sync_time');
      
      if (cachedOffset != null && cachedSyncTime != null) {
        final syncTime = DateTime.fromMillisecondsSinceEpoch(cachedSyncTime);
        final age = DateTime.now().difference(syncTime);
        
        // Use cached offset if less than 24 hours old
        if (age < Duration(hours: 24)) {
          _timeOffsetMs = cachedOffset;
          _lastSyncTime = syncTime;
          print('📦 Using cached time offset: ${cachedOffset}ms (age: ${age.inHours}h)');
        } else {
          print('⚠️ Cached offset too old (${age.inHours}h), using device time');
        }
      }
    } catch (e) {
      print('⚠️ Failed to load cached offset: $e');
    }
  }
  
  /// Force immediate sync with NTP
  static Future<void> forceSync() async {
    _timeOffsetMs = null;
    _lastSyncTime = null;
    await _syncWithNTP();
  }
  
  /// Initialize time service (call at app start)
  static Future<void> initialize() async {
    print('⏰ Initializing TimeService...');
    await _loadCachedOffset();
    
    // Do async sync in background
    _syncWithNTP().catchError((e) {
      print('⚠️ Background NTP sync failed: $e');
    });
  }
}
