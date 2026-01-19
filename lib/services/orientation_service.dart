import 'package:flutter/services.dart';

/// Service to manage app orientation based on context
/// - Lock to landscape for roster viewing
/// - Allow portrait for data entry dialogs
class OrientationService {
  static bool _isLandscapeLocked = false;

  /// Lock orientation to landscape only (for roster viewing)
  static Future<void> lockToLandscape() async {
    _isLandscapeLocked = true;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    print('🔒 Orientation locked to LANDSCAPE');
  }

  /// Allow both portrait and landscape (for dialogs/editing)
  static Future<void> unlockOrientation() async {
    _isLandscapeLocked = false;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    print('🔓 Orientation UNLOCKED - allows portrait and landscape');
  }

  /// Check if landscape is currently locked
  static bool get isLandscapeLocked => _isLandscapeLocked;

  /// Reset to default (allows all orientations)
  static Future<void> resetOrientation() async {
    _isLandscapeLocked = false;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    print('↻ Orientation reset to DEFAULT - all orientations allowed');
  }
}
