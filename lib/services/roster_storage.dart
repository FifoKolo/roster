import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/employee_document.dart';
import '../models/employee_model.dart';
import 'firestore_service.dart';

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
  // Cloud + local hybrid
  static final FirestoreService _cloud = FirestoreService();
  static bool _useCloud = false;
  static String? _uid;

  // Local stream controllers (live updates in local mode)
  static final _namesCtrl = StreamController<List<String>>.broadcast();
  static final Map<String, StreamController<List<Employee>>> _rosterCtrls = {};
  static bool _namesSeeded = false;

  /// Recover roster names from stored roster_* keys if the name list was cleared.
  /// This is a safety net so existing rosters are rediscovered even if
  /// `roster_names` was wiped (e.g., cache reset or older builds).
  static Future<int> recoverRosterNamesIfMissing() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList('roster_names') ?? <String>[];
    final keys = prefs.getKeys();
    final derived = keys
        .where((k) => k.startsWith('roster_'))
        .map((k) => k.substring('roster_'.length))
        .where((n) => n.isNotEmpty)
        .toSet();

    // Merge saved + derived while preserving the existing order
    final merged = List<String>.from(saved);
    for (final name in derived) {
      if (!merged.contains(name)) {
        merged.add(name);
      }
    }
    final added = merged.length - saved.length;

    if (added > 0) {
      await _saveLocalRosterNames(merged);
      print('✅ Recovered $added roster(s) from stored data');
    }

    return added;
  }

  static void _seedNamesOnce() {
    if (_namesSeeded) return;
    _namesSeeded = true;
    recoverRosterNamesIfMissing().then((_) async {
      final names = await _loadLocalRosterNames();
      if (!_namesCtrl.isClosed) _namesCtrl.add(names);
    });
  }

  /// Push all local rosters to cloud after a user signs in.
  static Future<void> syncLocalToCloud({bool overwriteCloud = true}) async {
    if (!_useCloud || _uid == null) {
      print('ℹ️ syncLocalToCloud skipped: not in cloud mode');
      return;
    }

    // Rebuild the roster name list from any stored roster_* keys so nothing is missed
    await recoverRosterNamesIfMissing();

    final names = await _loadLocalRosterNames();
    print('🔄 Syncing ${names.length} local roster(s) to cloud...');

    for (final rosterName in names) {
      try {
        final employees = await _loadLocalRoster(rosterName);
        await _cloud.createRoster(rosterName);

        if (overwriteCloud || employees.isNotEmpty) {
          await _cloud.saveRoster(rosterName, employees);
          print('✅ Synced "$rosterName" (${employees.length} employees)');
        }
      } catch (e) {
        print('⚠️ Failed to sync "$rosterName" to cloud: $e');
      }
    }
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
    _uid = uid;
    _useCloud = uid != null && uid.isNotEmpty;
    _cloud.configure(uid);
    if (!_useCloud) {
      // Seed local streams when returning to local mode
      _seedNamesOnce();
    }
  }

  /// Stream roster names (cloud) or local live stream
  static Stream<List<String>> watchRosterNames() {
    if (_useCloud && _uid != null) {
      return _cloud.watchRosterNames().map((names) => _sortRosterNames(names)).handleError((_) {
        // Fallback to local stream on error
        _seedNamesOnce();
        return <String>[];
      });
    }

    _seedNamesOnce();
    return _namesCtrl.stream.map((names) => _sortRosterNames(names));
  }

  static Future<List<String>> _loadLocalRosterNames() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('roster_names') ?? <String>[];
    // Sort roster names by week number
    return _sortRosterNames(names);
  }

  /// Sort roster names by week number (Week 1, Week 2, etc.)
  static List<String> _sortRosterNames(List<String> names) {
    final sorted = List<String>.from(names);
    sorted.sort((a, b) {
      // Extract week numbers using regex
      final aMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(a);
      final bMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(b);
      
      // If both have week numbers, sort by number
      if (aMatch != null && bMatch != null) {
        final aNum = int.parse(aMatch.group(1)!);
        final bNum = int.parse(bMatch.group(1)!);
        return aNum.compareTo(bNum);
      }
      
      // If only one has a week number, put it first
      if (aMatch != null) return -1;
      if (bMatch != null) return 1;
      
      // Neither has week number, sort alphabetically
      return a.compareTo(b);
    });
    return sorted;
  }

  /// Get roster names once with cloud + local fallback. Avoids hanging on a
  /// cloud stream that never emits by timing out and returning local names.
  static Future<List<String>> getRosterNamesOnce({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    // Try cloud stream first when signed in
    if (_useCloud && _uid != null) {
      try {
        final names = await _cloud.watchRosterNames().first.timeout(timeout);
        if (names.isNotEmpty) return List<String>.from(names);
      } catch (e) {
        print('⚠️ getRosterNamesOnce cloud timed out/fell back: $e');
      }
    }

    // Fallback to local storage
    _seedNamesOnce();
    final names = await _loadLocalRosterNames();
    return List<String>.from(names);
  }

  static Future<void> _saveLocalRosterNames(List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('roster_names', names);
    if (!_namesCtrl.isClosed) _namesCtrl.add(List<String>.from(names));
  }

  /// Create roster (cloud or local)
  static Future<void> createRoster(String rosterName, List<Employee> initialEmployees) async {
    // Cloud first
    if (_useCloud && _uid != null) {
      try {
        await _cloud.createRoster(rosterName);
        if (initialEmployees.isNotEmpty) {
          await _cloud.saveRoster(rosterName, initialEmployees);
        }
      } catch (e) {
        print('⚠️ Cloud createRoster failed, falling back to local: $e');
      }
    }

    // Always keep local backup
    final names = await _loadLocalRosterNames();
    if (!names.contains(rosterName)) {
      names.add(rosterName);
      await _saveLocalRosterNames(names);
    }
    await _saveLocalRoster(rosterName, initialEmployees);
    if (!_namesCtrl.isClosed) _namesCtrl.add(names);
  }

  static Future<void> deleteRoster(String rosterName) async {
    // Move to trash instead of permanent deletion
    await moveRosterToTrash(rosterName);
  }

  /// Move a roster to trash (soft delete)
  static Future<void> moveRosterToTrash(String rosterName) async {
    // Ensure cloud copy is removed so the roster list updates for signed-in users
    if (_useCloud && _uid != null) {
      await _cloud.moveRosterToTrash(rosterName);
    }

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
    
    // Create deep copies of employees with same shifts but preserve accumulated hours
    final copiedEmployees = sourceEmployees.map((emp) => Employee(
      name: emp.name,
      sortIndex: emp.sortIndex,
      shifts: Map<String, Shift>.from(emp.shifts), // Deep copy shifts
      employeeColor: emp.employeeColor,
      accumulatedWorkedHours: emp.accumulatedWorkedHours,
      accumulatedTotalHours: emp.accumulatedTotalHours,
      accumulatedHolidayHours: emp.accumulatedHolidayHours,
      accumulatedHolidayHoursUsed: emp.accumulatedHolidayHoursUsed,
      accumulatedHolidayHoursEarned: emp.accumulatedHolidayHoursEarned,
      customAccumulatedHours: emp.customAccumulatedHours,
      customHolidayHours: emp.customHolidayHours,
      rosterStartDate: emp.rosterStartDate,
      rosterEndDate: emp.rosterEndDate,
      email: emp.email,
      contractType: emp.contractType,
      contractPdfPath: emp.contractPdfPath,
      contractPdfName: emp.contractPdfName,
      contractPdfBase64: emp.contractPdfBase64,
      documents: List<EmployeeDocument>.from(emp.documents),
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
    print('🔍 watchRoster called for: $rosterName');
    if (_useCloud && _uid != null) {
      return _cloud.watchRoster(rosterName).handleError((error) {
        print('⚠️ Cloud watchRoster error, falling back to local: $error');
        _seedRosterStreamOnce(rosterName);
        return <Employee>[];
      });
    }

    _seedRosterStreamOnce(rosterName);
    return _rosterCtrls[rosterName]!.stream;
  }

  /// Load roster (cloud-aware; used by copy-from-previous flow)
  static Future<List<Employee>> loadRoster(String rosterName) async {
    if (_useCloud && _uid != null) {
      try {
        final cloud = await _cloud.loadRoster(rosterName);
        if (cloud.isNotEmpty) {
          // Firestore docs are not in a guaranteed order; sort then align "N. Name" rows.
          cloud.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
          final reordered = Employee.reorderLeadingNumberedNamesInPlace(cloud);
          final indicesFixed = Employee.compactSortIndices(cloud);
          if (reordered || indicesFixed) {
            unawaited(saveRoster(rosterName, cloud));
          }
          return cloud;
        }
      } catch (e) {
        print('⚠️ Cloud loadRoster failed, using local: $e');
      }
    }
    return _loadLocalRoster(rosterName);
  }

  /// Save roster data (cloud or local)
  static Future<void> saveRoster(String rosterName, List<Employee> employees) async {
    print('🔍 saveRoster called for: $rosterName with ${employees.length} employees');
    for (final emp in employees) {
      print('  - Employee: ${emp.name} with ${emp.shifts.length} shifts');
    }
    
    if (_useCloud && _uid != null) {
      try {
        await _cloud.saveRoster(rosterName, employees);
      } catch (e) {
        print('⚠️ Cloud saveRoster failed, falling back to local: $e');
      }
    }

    // Always keep local backup
    await _saveLocalRoster(rosterName, employees);
    
    // Only update the stream if controller exists and is not closed
    final ctrl = _rosterCtrls[rosterName];
    if (ctrl != null && !ctrl.isClosed) {
      print('🔍 Updating stream controller with ${employees.length} employees');
      // Create a deep copy to prevent reference issues and maintain sortIndex
      final employeesCopy = employees.asMap().entries.map((entry) {
        final index = entry.key;
        final e = entry.value;
        return Employee(
          name: e.name,
          sortIndex: e.sortIndex > 0 ? e.sortIndex : index, // Use existing or assign from position
          shifts: Map<String, Shift>.from(e.shifts),
          accumulatedWorkedHours: e.accumulatedWorkedHours,
          accumulatedTotalHours: e.accumulatedTotalHours,
          accumulatedHolidayHours: e.accumulatedHolidayHours,
          accumulatedHolidayHoursUsed: e.accumulatedHolidayHoursUsed,
          accumulatedHolidayHoursEarned: e.accumulatedHolidayHoursEarned,
          employeeColor: e.employeeColor,
          rosterStartDate: e.rosterStartDate,
          rosterEndDate: e.rosterEndDate,
          customAccumulatedHours: e.customAccumulatedHours,
          customHolidayHours: e.customHolidayHours,
          email: e.email,
          contractType: e.contractType,
          contractPdfPath: e.contractPdfPath,
          contractPdfName: e.contractPdfName,
          contractPdfBase64: e.contractPdfBase64,
          documents: List<EmployeeDocument>.from(e.documents),
        );
      }).toList();
      
      ctrl.add(employeesCopy);
      print('✅ Stream updated successfully');
    } else {
      print('⚠️ No stream controller available for $rosterName');
    }
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
        
        // Fix "1., 5., 2., …" name prefixes out of order; keep unnumbered rows fixed.
        final reordered = Employee.reorderLeadingNumberedNamesInPlace(employees);
        final indicesFixed = Employee.compactSortIndices(employees);
        if (reordered || indicesFixed) {
          unawaited(saveRoster(rosterName, employees));
        }

        print('✅ Successfully loaded ${employees.length} employees');
        for (final emp in employees) {
          print('  - Employee: ${emp.name} (sortIndex=${emp.sortIndex}) with ${emp.shifts.length} shifts');
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

  /// Apply custom values to an employee across all future weeks
  /// Returns the count of rosters updated
  static Future<int> applyCustomValuesForward({
    required String employeeName,
    required double? customAccumulatedHours,
    required double? customHolidayHours,
    DateTime? fromDate,
  }) async {
    print('🔍 applyCustomValuesForward: $employeeName from $fromDate');
    
    try {
      // Get all roster names
      final rosterNames = await _loadLocalRosterNames();
      print('📋 Found ${rosterNames.length} rosters');
      
      int updatedCount = 0;
      final now = DateTime.now();
      final referenceDate = fromDate ?? now;
      
      for (final rosterName in rosterNames) {
        // Parse week number from roster name (e.g., "Week 5")
        final match = RegExp(r'^Week (\d+)').firstMatch(rosterName);
        if (match == null) continue; // Skip non-week rosters
        
        final weekNum = int.parse(match.group(1)!);
        
        // Estimate the date of this week (rough calculation)
        // Week 1 = Jan 1 area, Week 52 = Dec 25 area
        final estimatedDate = DateTime(now.year, 1, 1).add(Duration(days: (weekNum - 1) * 7));
        
        // Check if this week is after the reference date (in same or future year)
        if (estimatedDate.isBefore(referenceDate)) {
          print('⏭️  Skipping Week $weekNum (in past)');
          continue;
        }
        
        // Load roster
        final employees = await _loadLocalRoster(rosterName);
        
        // Find and update the employee
        bool updated = false;
        for (final emp in employees) {
          if (emp.name.toLowerCase() == employeeName.toLowerCase()) {
            print('✏️  Updating $employeeName in $rosterName');
            emp.customAccumulatedHours = customAccumulatedHours;
            // Store custom holiday hours as additive (do not overwrite accumulated)
            if (customHolidayHours != null) {
              emp.customHolidayHours = customHolidayHours;
            }
            updated = true;
            break;
          }
        }
        
        if (updated) {
          await _saveLocalRoster(rosterName, employees);
          updatedCount++;
          print('✅ Saved $rosterName');
        }
      }
      
      print('🎉 applyCustomValuesForward: updated $updatedCount rosters');
      return updatedCount;
    } catch (e) {
      print('❌ Error in applyCustomValuesForward: $e');
      return 0;
    }
  }

  /// One-time helper: upload all local rosters to cloud for the signed-in user.
  /// Returns a summary with counts of rosters uploaded and any errors.
  static Future<Map<String, dynamic>> pushAllLocalRostersToCloud({bool overwrite = false}) async {
    if (!_useCloud || _uid == null) {
      throw Exception('Not signed in; cannot push rosters to cloud.');
    }

    final summary = {
      'uploaded': 0,
      'skipped': 0,
      'errors': <String, String>{},
    };

    final names = await _loadLocalRosterNames();
    for (final name in names) {
      try {
        final employees = await _loadLocalRoster(name);
        // Skip empty rosters unless overwriting explicitly
        if (employees.isEmpty && !overwrite) {
          summary['skipped'] = (summary['skipped'] as int) + 1;
          continue;
        }

        if (overwrite) {
          // Ensure roster exists in cloud; create if missing
          await _cloud.createRoster(name);
        } else {
          // Create if missing, ignore if exists
          try {
            await _cloud.createRoster(name);
          } catch (_) {
            // likely exists; proceed to save
          }
        }

        if (employees.isNotEmpty) {
          await _cloud.saveRoster(name, employees);
        }

        // Push style if present
        try {
          final style = await loadStyle(name);
          if (style != null && style.isNotEmpty) {
            await saveStyle(name, style);
          }
        } catch (_) {}

        summary['uploaded'] = (summary['uploaded'] as int) + 1;
      } catch (e) {
        (summary['errors'] as Map<String, String>)[name] = e.toString();
      }
    }

    return summary;
  }
}
