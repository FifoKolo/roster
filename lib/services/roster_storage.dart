import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee_model.dart';

class RosterStorage {
  // Local-only mode - no cloud configuration needed

  // Local stream controllers (live updates in local mode)
  static final _namesCtrl = StreamController<List<String>>.broadcast();
  static final Map<String, StreamController<List<Employee>>> _rosterCtrls = {};
  static bool _namesSeeded = false;

  static void _seedNamesOnce() {
    if (_namesSeeded) return;
    _namesSeeded = true;
    _loadLocalRosterNames().then((names) {
      if (!_namesCtrl.isClosed) _namesCtrl.add(names);
    });
  }

  static void _seedRosterStreamOnce(String rosterName) {
    print('🔍 _seedRosterStreamOnce called for: $rosterName');
    final existing = _rosterCtrls[rosterName];
    if (existing != null && !existing.isClosed) {
      print('✅ Stream controller already exists and is open');
      return;
    }
    print('🔍 Creating new stream controller...');
    final ctrl = StreamController<List<Employee>>.broadcast();
    _rosterCtrls[rosterName] = ctrl;
    print('🔍 Loading roster data...');
    loadRoster(rosterName).then((employees) {
      print('✅ Loaded ${employees.length} employees, adding to stream');
      if (!ctrl.isClosed) ctrl.add(employees);
      print('✅ Added employees to stream');
    }).catchError((error) {
      print('❌ Error loading roster for stream: $error');
    });
  }

  /// Call this after auth changes. No-op in local-only mode.
  static Future<void> configureCloud(String? uid, {String? email, String? displayName}) async {
    // Local-only mode - no configuration needed
    // This method is kept for API compatibility
  }

  /// Stream roster names (cloud) or local live stream
  static Stream<List<String>> watchRosterNames() {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    _seedNamesOnce();
    return _namesCtrl.stream;
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   final col = _db.collection('users').doc(_uid).collection('rosters');
    //   return col.snapshots().map((snap) {
    //     // Use doc IDs as names
    //     final names = snap.docs.map((d) => d.id).toList()..sort();
    //     return names;
    //   });
    // }
    // _seedNamesOnce();
    // return _namesCtrl.stream;
  }

  static Future<List<String>> _loadLocalRosterNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('roster_names') ?? <String>[];
  }

  static Future<void> _saveLocalRosterNames(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('roster_names', names);
    if (!_namesCtrl.isClosed) _namesCtrl.add(List<String>.from(names));
  }

  /// Create roster (cloud or local)
  static Future<void> createRoster(String rosterName, List<Employee> initialEmployees) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final names = await _loadLocalRosterNames();
    if (!names.contains(rosterName)) {
      names.add(rosterName);
      names.sort();
      await _saveLocalRosterNames(names);
    }
    await _saveLocalRoster(rosterName, initialEmployees);
    if (!_namesCtrl.isClosed) _namesCtrl.add(names);
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     await _rosterDoc(rosterName).set({
    //       'name': rosterName,
    //       'createdAt': FieldValue.serverTimestamp(),
    //       'employees': initialEmployees.map((e) => e.toJson()).toList(),
    //       'style': null,
    //     }, SetOptions(merge: true));
    //     return;
    //   } catch (_) {
    //     // Fall through to local on error
    //   }
    // }
    // Local fallback code moved above
  }

  static Future<void> deleteRoster(String rosterName) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('roster_$rosterName');
    await prefs.remove('style_$rosterName');
    final names = await _loadLocalRosterNames();
    names.remove(rosterName);
    await _saveLocalRosterNames(names);

    final ctrl = _rosterCtrls[rosterName];
    ctrl?.add(const <Employee>[]);
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     await _rosterDoc(rosterName).delete();
    //     return;
    //   } catch (_) {
    //     // Fall through to local on error
    //   }
    // }
  }

  /// Stream roster employees for live multi-device sync
  static Stream<List<Employee>> watchRoster(String rosterName) {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    print('🔍 watchRoster called for: $rosterName');
    _seedRosterStreamOnce(rosterName);
    
    // Ensure data is available immediately by re-adding current data
    final ctrl = _rosterCtrls[rosterName]!;
    loadRoster(rosterName).then((employees) {
      print('🔍 Re-seeding stream with ${employees.length} employees for immediate access');
      if (!ctrl.isClosed) ctrl.add(employees);
    });
    
    return ctrl.stream;
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   return _rosterDoc(rosterName).snapshots().map((doc) {
    //     final data = doc.data();
    //     final list = (data?['employees'] as List?) ?? const [];
    //     return list
    //         .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
    //         .toList();
    //   });
    // }
    // _seedRosterStreamOnce(rosterName);
    // return _rosterCtrls[rosterName]!.stream;
  }

  /// Load roster (cloud-aware; used by copy-from-previous flow)
  static Future<List<Employee>> loadRoster(String rosterName) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    return _loadLocalRoster(rosterName);
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     final snap = await _rosterDoc(rosterName).get();
    //     final data = snap.data();
    //     final list = (data?['employees'] as List?) ?? const [];
    //     return list
    //         .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
    //         .toList();
    //   } catch (_) {
    //     // fall through to local
    //   }
    // }
    // return _loadLocalRoster(rosterName);
  }

  /// Save roster data (cloud or local)
  static Future<void> saveRoster(String rosterName, List<Employee> employees) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    await _saveLocalRoster(rosterName, employees);
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     await _rosterDoc(rosterName).set(
    //       {
    //         'employees': employees.map((e) => e.toJson()).toList(),
    //         'updatedAt': FieldValue.serverTimestamp(),
    //       },
    //       SetOptions(merge: true),
    //     );
    //     return;
    //   } catch (_) {
    //     // Fall through to local on error
    //   }
    // }
    // await _saveLocalRoster(rosterName, employees);
  }

  // ---- Local helpers ----

  static Future<List<Employee>> _loadLocalRoster(String rosterName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('roster_$rosterName');
    if (raw == null || raw.isEmpty) return <Employee>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      // ignore decode errors, return empty
    }
    return <Employee>[];
  }

  static Future<void> _saveLocalRoster(String rosterName, List<Employee> employees) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(employees.map((e) => e.toJson()).toList());
    await prefs.setString('roster_$rosterName', encoded);

    // Push to local stream
    _seedRosterStreamOnce(rosterName);
    final ctrl = _rosterCtrls[rosterName];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(List<Employee>.from(employees));
    }
  }

  // ---- Appearance (colors) per roster — cloud-aware ----

  static Future<Map<String, dynamic>?> loadStyle(String rosterName) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('style_$rosterName');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map) return Map<String, dynamic>.from(map);
    } catch (_) {}
    return null;
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     final snap = await _rosterDoc(rosterName).get();
    //     final data = snap.data();
    //     final style = data?['style'];
    //     if (style is Map) {
    //       return Map<String, dynamic>.from(style);
    //     }
    //   } catch (_) {}
    //   return null;
    // }
  }

  static Future<void> saveStyle(String rosterName, Map<String, dynamic> style) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('style_$rosterName', jsonEncode(style));
    
    // Disabled Firebase code:
    // if (_useCloud && _uid != null) {
    //   try {
    //     await _rosterDoc(rosterName).set({'style': style}, SetOptions(merge: true));
    //     return;
    //   } catch (_) {
    //     // Fall through to local
    //   }
    // }
  }

  // ---- Compute total holiday hours for a roster (cloud-aware) ----

  static Future<double> getTotalHolidayHours(String rosterName) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final emps = await _loadLocalRoster(rosterName);
    double total = 0.0;
    for (final e in emps) {
      total += e.totalHolidayThisRoster;
    }
    return total;
    
    // Disabled Firebase code:
    // List<Employee> emps;
    // if (_useCloud && _uid != null) {
    //   try {
    //     final snap = await _rosterDoc(rosterName).get();
    //     final data = snap.data();
    //     final list = (data?['employees'] as List?) ?? const [];
    //     emps = list
    //         .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
    //         .toList();
    //   } catch (_) {
    //     emps = await _loadLocalRoster(rosterName);
    //   }
    // } else {
    //   emps = await _loadLocalRoster(rosterName);
    // }
  }
}
