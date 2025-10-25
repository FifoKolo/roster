import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import 'roster_page.dart';
import '../services/roster_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RosterManager extends StatefulWidget {
  const RosterManager({super.key});

  @override
  State<RosterManager> createState() => _RosterManagerState();
}

class _RosterManagerState extends State<RosterManager> {
  List<String> rosterNames = [];

  @override
  void initState() {
    super.initState();
    _loadRosters();
  }

  Future<void> _loadRosters() async {
    // Keep local initial state; UI will be driven by stream below
    final names = await RosterStorage.watchRosterNames().first;
    setState(() => rosterNames = names);
  }

  /// Create a new roster (remove default staff)
  Future<void> _createRoster() async {
    print('🔍 _createRoster: Starting...');
    try {
      // Get current week number and dates
      final now = DateTime.now();
      final firstDayOfYear = DateTime(now.year, 1, 1);
      final weekNumber = ((now.difference(firstDayOfYear).inDays +
              firstDayOfYear.weekday - 1) / 7)
          .ceil();

      // Calculate week start and end dates
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      // Format default name
      final defaultName =
          'Week $weekNumber (${_formatDate(monday)} - ${_formatDate(sunday)})';

      print('🔍 Showing name dialog...');
      // Show dialog with pre-filled name
      final customName = await _showNewRosterDialog(defaultName);
      if (customName == null || customName.isEmpty) {
        print('❌ User cancelled name dialog');
        return;
      }
      print('✅ Got roster name: $customName');

      print('🔍 Showing choice dialog...');
      // Ask how to initialize staff for this new roster
      final choice = await _askRosterInitChoice(hasPrevious: rosterNames.isNotEmpty);
      if (choice == null) {
        print('❌ User cancelled choice dialog');
        return;
      }
      print('✅ User chose: $choice');

      List<Employee> newEmployees = [];

      if (choice == 'load_previous' && rosterNames.isNotEmpty) {
        print('🔍 Loading previous roster data...');
        final lastRosterName = rosterNames.last;
        print('🔍 Last roster name: $lastRosterName');
        
        final prev = await RosterStorage.loadRoster(lastRosterName);
        print('✅ Loaded ${prev.length} employees from previous roster');
        
        newEmployees = prev
            .map((e) => Employee(
                  name: e.name,
                  shifts: {}, // start with empty shifts for the new week
                  manualHolidayHours: 0.0,
                  carryOverHolidayHours: e.totalHolidayThisRoster,
                  employeeColor: e.employeeColor,
                  // CRITICAL: Carry forward accumulated totals + this week's work
                  accumulatedWorkedHours: e.accumulatedWorkedHours + e.totalWorkedThisRoster,
                  accumulatedHolidayHours: e.accumulatedHolidayHours + e.holidayHoursEarnedThisRoster,
                ))
            .toList();
        print('✅ Processed ${newEmployees.length} employees');
        } else if (choice == 'start_fresh') {
        print('🔍 Getting initial staff names...');
        // Optionally prefill names
        final names = await _askInitialStaffNames();
        if (names != null && names.trim().isNotEmpty) {
          newEmployees = names
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .map((n) => Employee(name: n))
              .toList();
          print('✅ Created ${newEmployees.length} employees from names');
        }
      }

      print('🔍 Creating roster with ${newEmployees.length} employees...');
      await RosterStorage.createRoster(customName, newEmployees);
      print('✅ Roster created successfully');
      
      print('🔍 Opening roster...');
      if (mounted) _openRoster(customName);
      print('✅ Navigation initiated');
      
    } catch (e, stackTrace) {
      print('❌ Error in _createRoster: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<String?> _showNewRosterDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Roster'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Roster Name',
                hintText: 'Enter roster name or use default',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askRosterInitChoice({required bool hasPrevious}) async {
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Initialize staff for new roster'),
        content: const Text('Load staff from previous roster or start fresh?'),
        actions: [
          if (hasPrevious)
            TextButton(
              onPressed: () => Navigator.pop(context, 'load_previous'),
              child: const Text('Load previous'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'start_fresh'),
            child: const Text('Start fresh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askInitialStaffNames() async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Initial staff (optional)'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Comma-separated names',
            hintText: 'e.g. Alice, Bob, Carol',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip')),
          TextButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('Add')),
        ],
      ),
    );
  }

  void _openRoster(String name) {
    print('🔍 _openRoster called with name: $name');
    print('🔍 About to navigate to RosterPage...');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RosterPage(rosterName: name)),
    ).then((_) {
      print('✅ Navigation completed - NOT reloading rosters to avoid loop');
      // Removed _loadRosters() to prevent potential loop
    }).catchError((error) {
      print('❌ Navigation error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster Manager'),
        centerTitle: true,
        actions: [
          // NEW: Sign out
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: RosterStorage.watchRosterNames(),
        initialData: rosterNames,
        builder: (context, snap) {
          final names = snap.data ?? const <String>[];
          if (names.isEmpty) {
            return const Center(
              child: Text(
                'No rosters yet.\nTap + to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, index) {
              final name = names[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  title: Text(name),
                  subtitle: FutureBuilder<double>(
                    future: RosterStorage.getTotalHolidayHours(name),
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? 0;
                      return Text('Total Holiday Hours: ${total.toStringAsFixed(1)}');
                    },
                  ),
                  onTap: () => _openRoster(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await RosterStorage.deleteRoster(name);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoster,
        tooltip: 'Create new roster',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// ✅ Calculate total holiday hours for a given roster (moved to storage)
  Future<double> _getTotalHolidayHours(String rosterName) async {
    // kept for compatibility; now delegates
    return RosterStorage.getTotalHolidayHours(rosterName);
  }
}


