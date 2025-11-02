import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee_model.dart';

/// Represents a roster that has been moved to trash
class TrashItem {
  final String trashKey;
  final String originalName;
  final DateTime deletedAt;
  final String rosterData;
  final String? styleData;
  
  const TrashItem({
    required this.trashKey,
    required this.originalName,
    required this.deletedAt,
    required this.rosterData,
    this.styleData,
  });
  
  /// Get a display name for the trash item
  String get displayName {
    final daysSince = DateTime.now().difference(deletedAt).inDays;
    if (daysSince == 0) {
      return '$originalName (deleted today)';
    } else if (daysSince == 1) {
      return '$originalName (deleted yesterday)';
    } else {
      return '$originalName (deleted $daysSince days ago)';
    }
  }
  
  /// Format deletion date for display
  String get formattedDeleteDate {
    final now = DateTime.now();
    final difference = now.difference(deletedAt);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${deletedAt.day}/${deletedAt.month}/${deletedAt.year}';
    }
  }
}

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
      // CRITICAL: Always re-emit the current data when a new listener connects
      print('🔍 Re-loading and emitting current data for new listener...');
      loadRoster(rosterName).then((employees) {
        print('✅ Re-loaded ${employees.length} employees, re-emitting to stream');
        if (!existing.isClosed) {
          existing.add(employees);
          print('✅ Re-emitted current data to existing stream');
        }
      }).catchError((error) {
        print('❌ Error re-loading roster for stream: $error');
      });
      return;
    }
    print('🔍 Creating new stream controller...');
    final ctrl = StreamController<List<Employee>>.broadcast();
    _rosterCtrls[rosterName] = ctrl;
    print('🔍 Loading roster data...');
    loadRoster(rosterName).then((employees) {
      print('✅ Loaded ${employees.length} employees, adding to stream');
      if (!ctrl.isClosed) {
        ctrl.add(employees);
        print('✅ Added employees to new stream');
      }
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
    // Move to trash instead of permanent deletion
    await moveRosterToTrash(rosterName);
  }

  /// Move a roster to trash (soft delete)
  static Future<void> moveRosterToTrash(String rosterName) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get roster data before moving to trash
    final rosterData = prefs.getString('roster_$rosterName');
    final styleData = prefs.getString('style_$rosterName');
    
    if (rosterData != null) {
      // Store in trash with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final trashKey = 'trash_${timestamp}_$rosterName';
      
      final trashItem = {
        'originalName': rosterName,
        'deletedAt': timestamp,
        'rosterData': rosterData,
        'styleData': styleData,
      };
      
      await prefs.setString(trashKey, jsonEncode(trashItem));
      
      // Add to trash names list
      final trashNames = await _loadTrashRosterNames();
      trashNames.add(trashKey);
      await _saveTrashRosterNames(trashNames);
    }
    
    // Remove from active rosters
    await prefs.remove('roster_$rosterName');
    await prefs.remove('style_$rosterName');
    final names = await _loadLocalRosterNames();
    names.remove(rosterName);
    await _saveLocalRosterNames(names);

    final ctrl = _rosterCtrls[rosterName];
    ctrl?.add(const <Employee>[]);
  }

  /// Permanently delete a roster (bypass trash)
  static Future<void> permanentlyDeleteRoster(String rosterName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('roster_$rosterName');
    await prefs.remove('style_$rosterName');
    final names = await _loadLocalRosterNames();
    names.remove(rosterName);
    await _saveLocalRosterNames(names);

    final ctrl = _rosterCtrls[rosterName];
    ctrl?.add(const <Employee>[]);
  }

  /// Get list of deleted rosters
  static Future<List<TrashItem>> getDeletedRosters() async {
    final trashNames = await _loadTrashRosterNames();
    final prefs = await SharedPreferences.getInstance();
    final trashItems = <TrashItem>[];
    
    for (final trashKey in trashNames) {
      final trashDataJson = prefs.getString(trashKey);
      if (trashDataJson != null) {
        try {
          final trashData = jsonDecode(trashDataJson) as Map<String, dynamic>;
          trashItems.add(TrashItem(
            trashKey: trashKey,
            originalName: trashData['originalName'] as String,
            deletedAt: DateTime.fromMillisecondsSinceEpoch(trashData['deletedAt'] as int),
            rosterData: trashData['rosterData'] as String,
            styleData: trashData['styleData'] as String?,
          ));
        } catch (e) {
          print('Error loading trash item $trashKey: $e');
        }
      }
    }
    
    // Sort by deletion date (newest first)
    trashItems.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return trashItems;
  }

  /// Restore a roster from trash
  static Future<void> restoreRoster(TrashItem trashItem, {String? newName}) async {
    final prefs = await SharedPreferences.getInstance();
    final restoreName = newName ?? trashItem.originalName;
    
    // Check if name already exists
    final existingNames = await _loadLocalRosterNames();
    if (existingNames.contains(restoreName)) {
      throw Exception('A roster with the name "$restoreName" already exists');
    }
    
    // Restore roster data
    await prefs.setString('roster_$restoreName', trashItem.rosterData);
    if (trashItem.styleData != null) {
      await prefs.setString('style_$restoreName', trashItem.styleData!);
    }
    
    // Add to active roster names
    existingNames.add(restoreName);
    existingNames.sort();
    await _saveLocalRosterNames(existingNames);
    
    // Remove from trash
    await prefs.remove(trashItem.trashKey);
    final trashNames = await _loadTrashRosterNames();
    trashNames.remove(trashItem.trashKey);
    await _saveTrashRosterNames(trashNames);
  }

  /// Permanently delete a roster from trash
  static Future<void> permanentlyDeleteFromTrash(TrashItem trashItem) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(trashItem.trashKey);
    final trashNames = await _loadTrashRosterNames();
    trashNames.remove(trashItem.trashKey);
    await _saveTrashRosterNames(trashNames);
  }

  /// Empty trash (permanently delete all trashed rosters)
  static Future<void> emptyTrash() async {
    final trashNames = await _loadTrashRosterNames();
    final prefs = await SharedPreferences.getInstance();
    
    for (final trashKey in trashNames) {
      await prefs.remove(trashKey);
    }
    
    await _saveTrashRosterNames([]);
  }

  static Future<List<String>> _loadTrashRosterNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('trash_roster_names') ?? <String>[];
  }

  static Future<void> _saveTrashRosterNames(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('trash_roster_names', names);
  }

  /// Copy an existing roster to create a new one with the same employees and shifts
  static Future<void> copyRoster(String sourceRosterName, String newRosterName) async {
    print('🔍 copyRoster: Copying $sourceRosterName to $newRosterName');
    
    // Load the source roster data
    final sourceEmployees = await loadRoster(sourceRosterName);
    print('✅ Loaded ${sourceEmployees.length} employees from source roster');
    
    // Create deep copies of employees with same shifts but reset accumulated hours
    final copiedEmployees = sourceEmployees.map((emp) => Employee(
      name: emp.name,
      shifts: Map<String, Shift>.from(emp.shifts), // Deep copy shifts
      employeeColor: emp.employeeColor,
      accumulatedWorkedHours: 0.0, // Reset accumulated hours for new roster
      accumulatedTotalHours: 0.0,
    )).toList();
    
    print('✅ Created ${copiedEmployees.length} copied employees');
    
    // Create the new roster
    await createRoster(newRosterName, copiedEmployees);
    
    // Copy style settings if they exist
    try {
      final sourceStyle = await loadStyle(sourceRosterName);
      if (sourceStyle != null) {
        await saveStyle(newRosterName, sourceStyle);
        print('✅ Copied style settings');
      }
    } catch (e) {
      print('⚠️ Could not copy style settings: $e');
    }
    
    print('✅ Successfully copied roster $sourceRosterName to $newRosterName');
  }

  /// Stream roster employees for live multi-device sync
  static Stream<List<Employee>> watchRoster(String rosterName) {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    print('🔍 watchRoster called for: $rosterName');
    _seedRosterStreamOnce(rosterName);
    
    return _rosterCtrls[rosterName]!.stream;
    
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
    print('🔍 saveRoster called for: $rosterName with ${employees.length} employees');
    for (final emp in employees) {
      print('  - Employee: ${emp.name} with ${emp.shifts.length} shifts');
    }
    
    // CRITICAL: Save to storage first, then update stream
    await _saveLocalRoster(rosterName, employees);
    
    // Only update the stream if controller exists and is not closed
    final ctrl = _rosterCtrls[rosterName];
    if (ctrl != null && !ctrl.isClosed) {
      print('🔍 Updating stream controller with ${employees.length} employees');
      // Create a deep copy to prevent reference issues
      final employeesCopy = employees.map((e) => Employee(
        name: e.name,
        shifts: Map<String, Shift>.from(e.shifts),
        accumulatedWorkedHours: e.accumulatedWorkedHours,
        accumulatedTotalHours: e.accumulatedTotalHours,
        accumulatedHolidayHours: e.accumulatedHolidayHours,
        employeeColor: e.employeeColor,
        rosterStartDate: e.rosterStartDate,
        rosterEndDate: e.rosterEndDate,
      )).toList();
      
      ctrl.add(employeesCopy);
      print('✅ Stream updated successfully');
    } else {
      print('⚠️ No stream controller available for $rosterName');
    }
    
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
    print('🔍 _loadLocalRoster called for: $rosterName');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('roster_$rosterName');
    
    if (raw == null || raw.isEmpty) {
      print('❌ No data found for roster: $rosterName');
      return <Employee>[];
    }
    
    print('🔍 Raw data length: ${raw.length} characters');
    print('🔍 Raw data preview: ${raw.substring(0, raw.length > 200 ? 200 : raw.length)}...');
    
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final employees = decoded
            .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        
        print('✅ Successfully loaded ${employees.length} employees');
        for (final emp in employees) {
          print('  - Employee: ${emp.name} with ${emp.shifts.length} shifts');
          for (final entry in emp.shifts.entries) {
            print('    - ${entry.key}: ${entry.value.formatted()}');
          }
        }
        
        return employees;
      } else {
        print('❌ Decoded data is not a List: $decoded');
        return <Employee>[];
      }
    } catch (e, stackTrace) {
      print('❌ Error parsing roster data: $e');
      print('❌ Stack trace: $stackTrace');
      return <Employee>[];
    }
  }

  static Future<void> _saveLocalRoster(String rosterName, List<Employee> employees) async {
    print('🔍 _saveLocalRoster called for: $rosterName with ${employees.length} employees');
    
    for (final emp in employees) {
      print('  - Saving Employee: ${emp.name} with ${emp.shifts.length} shifts');
      for (final entry in emp.shifts.entries) {
        print('    - ${entry.key}: ${entry.value.formatted()}');
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(employees.map((e) => e.toJson()).toList());
    
    print('🔍 Encoded data length: ${encoded.length} characters');
    print('🔍 Encoded data preview: ${encoded.substring(0, encoded.length > 200 ? 200 : encoded.length)}...');
    
    await prefs.setString('roster_$rosterName', encoded);
    print('✅ Data saved to SharedPreferences for roster: $rosterName');
    
    // Verify the save by reading it back
    final verification = prefs.getString('roster_$rosterName');
    if (verification != null && verification == encoded) {
      print('✅ Save verification successful');
    } else {
      print('❌ Save verification failed!');
    }

    // Do NOT update stream here - let saveRoster() handle it to avoid double updates
    print('✅ _saveLocalRoster completed successfully');
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

  // ---- Compute total hours for a roster (cloud-aware) ----

  static Future<double> getTotalHours(String rosterName) async {
    // FORCE LOCAL MODE - skip Firebase entirely for performance
    final emps = await _loadLocalRoster(rosterName);
    double total = 0.0;
    for (final e in emps) {
      total += e.totalHours;
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
