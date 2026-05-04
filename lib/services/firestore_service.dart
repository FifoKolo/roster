import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';

/// Firestore database service for roster management
/// 
/// Data structure:
/// - users/{userId}/rosters/{rosterName}/employees/{employeeId}
/// - users/{userId}/settings/{settingKey}
/// - users/{userId}/trash/{trashItemId}
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;
  
  /// Configure the service with a user ID (from Firebase Auth)
  void configure(String? userId) {
    _userId = userId;
  }
  
  /// Check if the service is configured with a valid user
  bool get isConfigured => _userId != null && _userId!.isNotEmpty;
  
  // ============================================================================
  // ROSTER NAMES - Get list of all rosters for the current user
  // ============================================================================
  
  /// Get all roster names for the current user
  Future<List<String>> getRosterNames() async {
    if (!isConfigured) return [];
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .get();
      
      // Sort by createdAt in code to avoid composite index requirement
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
        // If both have createdAt, use it; otherwise preserve Firestore order
        if (aTime != null && bTime != null) return aTime.compareTo(bTime);
        return 0; // Keep original order if createdAt missing
      });
      print('🔍 getRosterNames order: ${docs.map((d) => d.id).join(", ")}');
      return docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error getting roster names: $e');
      return [];
    }
  }
  
  /// Stream of roster names (real-time updates)
  Stream<List<String>> watchRosterNames() {
    if (!isConfigured) {
      return Stream.value([]);
    }
    
    return _db
        .collection('users')
        .doc(_userId)
        .collection('rosters')
        .snapshots()
        .map((snapshot) {
      // Sort by createdAt in code to avoid composite index requirement
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
        final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
        // If both have createdAt, use it; otherwise preserve Firestore order (don't re-sort)
        if (aTime != null && bTime != null) return aTime.compareTo(bTime);
        // If one or both missing createdAt, maintain their original order
        return 0;
      });
      return docs.map((doc) => doc.id).toList();
    });
  }
  
  // ============================================================================
  // ROSTER OPERATIONS - Create, delete, rename rosters
  // ============================================================================
  
  /// Create a new roster (empty initially)
  Future<void> createRoster(String rosterName) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      // Create the roster document with metadata
      await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'employeeCount': 0,
      });
    } catch (e) {
      print('❌ Error creating roster: $e');
      rethrow;
    }
  }
  
  /// Delete a roster and all its employees
  Future<void> deleteRoster(String rosterName) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      // First, delete all employees in the roster
      final employeesSnapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .collection('employees')
          .get();
      
      // Batch delete for efficiency
      final batch = _db.batch();
      for (final doc in employeesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete the roster document itself
      batch.delete(_db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName));
      
      await batch.commit();
    } catch (e) {
      print('❌ Error deleting roster: $e');
      rethrow;
    }
  }
  
  /// Rename a roster
  Future<void> renameRoster(String oldName, String newName) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      // Get all employees from old roster
      final employees = await loadRoster(oldName);
      
      // Create new roster with same employees
      await createRoster(newName);
      for (final employee in employees) {
        await saveEmployee(newName, employee);
      }
      
      // Delete old roster
      await deleteRoster(oldName);
    } catch (e) {
      print('❌ Error renaming roster: $e');
      rethrow;
    }
  }
  
  // ============================================================================
  // EMPLOYEE OPERATIONS - CRUD operations for employees within a roster
  // ============================================================================
  
  /// Load all employees for a specific roster
  Future<List<Employee>> loadRoster(String rosterName) async {
    if (!isConfigured) return [];
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .collection('employees')
          .get();
      
      final employees = snapshot.docs
          .map((doc) {
            try {
              return Employee.fromJson(doc.data());
            } catch (e) {
              print('❌ Error parsing employee ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Employee>()
          .toList();
      
      // Sort by sortIndex, fix "N. Name" row order, then close numbering gaps
      employees.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      Employee.reorderLeadingNumberedNamesInPlace(employees);
      Employee.compactSortIndices(employees);
      return employees;
    } catch (e) {
      print('❌ Error loading roster: $e');
      return [];
    }
  }
  
  /// Stream of employees for a specific roster (real-time updates)
  Stream<List<Employee>> watchRoster(String rosterName) {
    if (!isConfigured) {
      return Stream.value([]);
    }
    
    return _db
        .collection('users')
        .doc(_userId)
        .collection('rosters')
        .doc(rosterName)
        .collection('employees')
        .snapshots()
        .map((snapshot) {
      final employees = snapshot.docs
          .map((doc) {
            try {
              return Employee.fromJson(doc.data());
            } catch (e) {
              print('❌ Error parsing employee ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Employee>()
          .toList();
      
      // Sort by sortIndex, fix "N. Name" row order, then close numbering gaps
      employees.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
      Employee.reorderLeadingNumberedNamesInPlace(employees);
      Employee.compactSortIndices(employees);
      return employees;
    });
  }
  
  /// Save/update an employee in a roster
  Future<void> saveEmployee(String rosterName, Employee employee) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      final employeeData = employee.toJson();
      employeeData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .collection('employees')
          .doc(employee.name)
          .set(employeeData);
      
      // Update roster metadata
      await _updateRosterMetadata(rosterName);
    } catch (e) {
      print('❌ Error saving employee: $e');
      rethrow;
    }
  }
  
  /// Delete an employee from a roster
  Future<void> deleteEmployee(String rosterName, String employeeName) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .collection('employees')
          .doc(employeeName)
          .delete();
      
      // Update roster metadata
      await _updateRosterMetadata(rosterName);
    } catch (e) {
      print('❌ Error deleting employee: $e');
      rethrow;
    }
  }
  
  /// Save entire roster (batch operation)
  Future<void> saveRoster(String rosterName, List<Employee> employees) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      final batch = _db.batch();
      
      for (final employee in employees) {
        final employeeData = employee.toJson();
        employeeData['updatedAt'] = FieldValue.serverTimestamp();
        
        final docRef = _db
            .collection('users')
            .doc(_userId)
            .collection('rosters')
            .doc(rosterName)
            .collection('employees')
            .doc(employee.name);
        
        batch.set(docRef, employeeData);
      }
      
      // Update roster metadata
      final rosterRef = _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName);
      
      batch.update(rosterRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'employeeCount': employees.length,
      });
      
      await batch.commit();
    } catch (e) {
      print('❌ Error saving roster: $e');
      rethrow;
    }
  }
  
  /// Update roster metadata (employee count, last updated time)
  Future<void> _updateRosterMetadata(String rosterName) async {
    try {
      final employeesSnapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .collection('employees')
          .get();
      
      await _db
          .collection('users')
          .doc(_userId)
          .collection('rosters')
          .doc(rosterName)
          .update({
        'updatedAt': FieldValue.serverTimestamp(),
        'employeeCount': employeesSnapshot.docs.length,
      });
    } catch (e) {
      print('❌ Error updating roster metadata: $e');
    }
  }
  
  // ============================================================================
  // SETTINGS - User preferences and settings
  // ============================================================================
  
  /// Save a setting to Firestore
  Future<void> saveSetting(String key, dynamic value) async {
    if (!isConfigured) return;
    
    try {
      await _db
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc(key)
          .set({
        'value': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving setting: $e');
    }
  }
  
  /// Get a setting from Firestore
  Future<dynamic> getSetting(String key) async {
    if (!isConfigured) return null;
    
    try {
      final doc = await _db
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc(key)
          .get();
      
      if (!doc.exists) return null;
      return doc.data()?['value'];
    } catch (e) {
      print('❌ Error getting setting: $e');
      return null;
    }
  }
  
  // ============================================================================
  // TRASH - Deleted rosters moved to trash
  // ============================================================================
  
  /// Move a roster to trash (soft delete)
  Future<void> moveRosterToTrash(String rosterName) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      // Get all employees
      final employees = await loadRoster(rosterName);
      
      // Create trash item
      final trashData = {
        'originalName': rosterName,
        'deletedAt': FieldValue.serverTimestamp(),
        'employees': employees.map((e) => e.toJson()).toList(),
      };
      
      await _db
          .collection('users')
          .doc(_userId)
          .collection('trash')
          .add(trashData);
      
      // Delete the original roster
      await deleteRoster(rosterName);
    } catch (e) {
      print('❌ Error moving roster to trash: $e');
      rethrow;
    }
  }
  
  /// Restore a roster from trash
  Future<void> restoreFromTrash(String trashId) async {
    if (!isConfigured) throw Exception('User not configured');
    
    try {
      final trashDoc = await _db
          .collection('users')
          .doc(_userId)
          .collection('trash')
          .doc(trashId)
          .get();
      
      if (!trashDoc.exists) {
        throw Exception('Trash item not found');
      }
      
      final data = trashDoc.data()!;
      final rosterName = data['originalName'] as String;
      final employeesJson = data['employees'] as List<dynamic>;
      
      // Create roster
      await createRoster(rosterName);
      
      // Restore employees
      final employees = employeesJson
          .map((json) => Employee.fromJson(json as Map<String, dynamic>))
          .toList();
      
      await saveRoster(rosterName, employees);
      
      // Delete trash item
      await _db
          .collection('users')
          .doc(_userId)
          .collection('trash')
          .doc(trashId)
          .delete();
    } catch (e) {
      print('❌ Error restoring from trash: $e');
      rethrow;
    }
  }
  
  /// Get all trash items
  Future<List<Map<String, dynamic>>> getTrashItems() async {
    if (!isConfigured) return [];
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('trash')
          .orderBy('deletedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error getting trash items: $e');
      return [];
    }
  }
  
  /// Empty trash (permanently delete all trash items)
  Future<void> emptyTrash() async {
    if (!isConfigured) return;
    
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('trash')
          .get();
      
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('❌ Error emptying trash: $e');
    }
  }
}
