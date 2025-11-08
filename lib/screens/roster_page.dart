import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/pdf_service.dart';
import '../widgets/add_shift_dialog.dart';
import '../widgets/modern_roster_table.dart';
import '../services/roster_storage.dart';
import '../services/irish_bank_holidays.dart';


class RosterPage extends StatefulWidget {
  final String rosterName;
  const RosterPage({super.key, required this.rosterName});

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  List<Employee> employees = [];
  Map<String, DateTime> weekDates = {};

  // Current week's data for PDF generation
  List<Employee> currentWeekEmployees = [];
  DateTime currentWeekDate = DateTime.now();

  // NEW: appearance state
  Color? headerColor;
  Color? headerTextColor;
  Color? cellBorderColor;
  Color? dayOffBgColor;
  Color? holidayBgColor;

  @override
  void initState() {
    print('🔍 RosterPage initState started for: ${widget.rosterName}');
    super.initState();
    // _futureRoster = RosterStorage.loadRoster(widget.rosterName).then((data) { return data; });
    print('🔍 Initializing week dates...');
    _initWeekDates();
    print('🔍 Loading style...');
    _loadStyle(); // NEW
    print('✅ RosterPage initState completed');
  }

  Future<void> _loadStyle() async {
    final map = await RosterStorage.loadStyle(widget.rosterName);
    if (map == null) return;
    setState(() {
      headerColor = _c(map['headerColor']);
      headerTextColor = _c(map['headerTextColor']);
      cellBorderColor = _c(map['cellBorderColor']);
      dayOffBgColor = _c(map['dayOffBgColor']);
      holidayBgColor = _c(map['holidayBgColor']);
    });
  }

  Future<void> _saveStyle() async {
    await RosterStorage.saveStyle(widget.rosterName, {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    });
  }

  Color? _c(Object? v) => (v is int) ? Color(v) : null;

  // Callback to receive current week data from ModernRosterTable
  void _onCurrentWeekDataChanged(List<Employee> weekEmployees, DateTime weekDate) {
    print('📅 Current week data updated: Week of ${weekDate.toIso8601String().split('T')[0]}, ${weekEmployees.length} employees');
    
    // Use Future.microtask to defer setState until after the current build cycle
    Future.microtask(() {
      if (mounted) {
        setState(() {
          currentWeekEmployees = List.from(weekEmployees);
          currentWeekDate = weekDate;
        });
      }
    });
  }

  void _initWeekDates() {
    // This will be updated when roster data is loaded
    // Default to current week for now
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      weekDates[_dayName(i)] = monday.add(Duration(days: i));
    }
  }

  void _updateWeekDatesFromRoster(List<Employee> employees) {
    // Get the week dates from the first employee (all should have the same dates)
    if (employees.isNotEmpty && 
        employees.first.rosterStartDate != null && 
        employees.first.rosterEndDate != null) {
      final monday = employees.first.rosterStartDate!;
      for (int i = 0; i < 7; i++) {
        weekDates[_dayName(i)] = monday.add(Duration(days: i));
      }
      // setState() is now handled by the caller when needed
    }
  }

  String _dayName(int i) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[i];
  }

  Future<void> _saveRoster(List<Employee> employees) async {
    print('🔍 _saveRoster called with ${employees.length} employees for roster: ${widget.rosterName}');
    
    // Check if this is a week-specific roster - if so, skip saving here as the table handles it
    final isWeekSpecificRoster = RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster) {
      print('📌 Week-specific roster detected: ${widget.rosterName} - updating local state with deep copies');
      // Update local state with deep copies to maintain independence for week-specific rosters
      setState(() {
        this.employees = employees.map((emp) {
          final empJson = emp.toJson();
          return Employee.fromJson(empJson);
        }).toList();
      });
      return;
    }
    
    // Debug: Print each employee's current hours and holiday calculations
    for (final emp in employees) {
      print('🔍 Employee ${emp.name}:');
      print('  - totalWorkedHours = ${emp.totalWorkedHours}');
      print('  - totalPaidHours = ${emp.totalPaidHours}');
      print('  - holidayHoursEarnedThisWeek = ${emp.holidayHoursEarnedThisWeek}');
      print('  - totalHolidayHoursUsed = ${emp.totalHolidayHoursUsed}');
      print('  - accumulatedHolidayHours = ${emp.accumulatedHolidayHours}');
      print('  - remainingAccumulatedHolidayHours = ${emp.remainingAccumulatedHolidayHours}');
      for (final entry in emp.shifts.entries) {
        final shift = entry.value;
        print('  - ${entry.key}: ${shift.formatted()} (${shift.duration} hours) isHoliday: ${shift.isHoliday}');
      }
    }
    
    await RosterStorage.saveRoster(widget.rosterName, employees);
    print('✅ Roster saved successfully');
  }

  Future<void> _exportPublicPdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;
    
    // Public PDF for staff - only shows schedule information
    print('📄 Exporting Public PDF with ${employeesToUse.length} employees');
    print('📅 Current week: ${currentWeekDate.toIso8601String().split('T')[0]}');
    for (final emp in employeesToUse) {
      print('  - ${emp.name}: ${emp.shifts.length} shifts');
      for (final shift in emp.shifts.entries) {
        print('    - ${shift.key}: ${shift.value.toJson()}');
      }
    }
    
    final style = {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    };
    await PdfService.sharePublicRosterPdf(context, employeesToUse, weekDates, style: style);
  }

  Future<void> _exportPrivatePdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;
    
    // Private PDF for management - includes hours and accumulated data
    print('📄 Exporting Private PDF with ${employeesToUse.length} employees');
    print('📅 Current week: ${currentWeekDate.toIso8601String().split('T')[0]}');
    for (final emp in employeesToUse) {
      print('  - ${emp.name}: ${emp.shifts.length} shifts');
      for (final shift in emp.shifts.entries) {
        print('    - ${shift.key}: ${shift.value.toJson()}');
      }
    }
    
    final style = {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    };
    await PdfService.sharePrivateRosterPdf(context, employeesToUse, weekDates, style: style);
  }

  Future<Shift?> _openEditDialog(BuildContext context, Shift? currentShift) async {
    return await showDialog<Shift>(
      context: context,
      builder: (_) => AddShiftDialog(shift: currentShift),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rosterName),
        actions: [
          // NEW: palette customization
          IconButton(
            tooltip: 'Customize appearance',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _openCustomizeDialog,
          ),
          // Staff Schedule PDF (Public)
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Export Staff Schedule',
            onPressed: () => _exportPublicPdf(employees),
          ),
          // Management Report PDF (Private)
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Export Management Report',
            onPressed: () => _exportPrivatePdf(employees),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2196F3), // Primary blue to match the app theme
        foregroundColor: Colors.white,
        onPressed: () async {
          print('🔍 Add employee button pressed');
          final result = await _showAddEmployeeDialog(context);
          final name = result?.$1 ?? '';
          if (name.isNotEmpty) {
            print('🔍 Adding employee: $name');
            print('🔍 Current employee count: ${employees.length}');
            
            final newEmployee = Employee(
              name: name,
              rosterStartDate: weekDates['Mon'],
              rosterEndDate: weekDates['Sun'],
            );
            
            setState(() {
              employees.add(newEmployee);
            });
            
            print('✅ Employee added to local list. New count: ${employees.length}');
            print('🔍 Saving roster...');
            await _saveRoster(employees); // persist after add
            print('✅ Roster saved successfully');
          } else {
            print('❌ No employee name provided');
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // NEW: Week Date Display
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.indigo.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_today, color: Colors.blue.shade700, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Week Period',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_formatDate(weekDates['Mon'] ?? DateTime.now())} - ${_formatDate(weekDates['Sun'] ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getWeekDescription(weekDates['Mon'] ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                  ),
                ),
                
                // Bank holidays in this week
                ..._buildBankHolidayInfo(),
              ],
            ),
          ),
          
          // Roster Table
          Expanded(
            child: StreamBuilder<List<Employee>>(
              stream: RosterStorage.watchRoster(widget.rosterName),
              builder: (context, snapshot) {
                print('🔍 StreamBuilder state - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, connectionState: ${snapshot.connectionState}');
                
                if (snapshot.hasError) {
                  print('❌ StreamBuilder error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 64, color: Colors.red),
                        SizedBox(height: 16),
                        Text('Error loading roster: ${snapshot.error}'),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                
                if (snapshot.hasData) {
                  final currentEmployees = snapshot.data!;
                  print('✅ StreamBuilder received ${currentEmployees.length} employees');
                  
                  // Check if this is a week-specific roster
                  final isWeekSpecificRoster = RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
                  
                  if (isWeekSpecificRoster) {
                    // For week-specific rosters, completely ignore stream updates after initial load
                    // to maintain complete independence
                    if (employees.isEmpty && currentEmployees.isNotEmpty) {
                      print('🔄 Week-specific roster initial load - setting employees (one-time only)');
                      Future.microtask(() {
                        if (mounted) {
                          setState(() {
                            // Create deep copies to ensure complete independence
                            employees = currentEmployees.map((emp) {
                              final empJson = emp.toJson();
                              return Employee.fromJson(empJson);
                            }).toList();
                            _updateWeekDatesFromRoster(employees);
                          });
                        }
                      });
                      
                      // Return the table with deep-copied data for initial load
                      return ModernRosterTable(
                        employees: currentEmployees.map((emp) {
                          final empJson = emp.toJson();
                          return Employee.fromJson(empJson);
                        }).toList(),
                        weekDates: weekDates,
                        onEdit: _openEditDialog,
                        onRosterChanged: (list) => _saveRoster(list),
                        onCurrentWeekDataChanged: _onCurrentWeekDataChanged,
                        rosterName: widget.rosterName,
                      );
                    } else {
                      // After initial load, always use local state and ignore stream updates
                      print('📌 Week-specific roster: using local state (ignoring stream)');
                      return ModernRosterTable(
                        employees: employees,
                        weekDates: weekDates,
                        onEdit: _openEditDialog,
                        onRosterChanged: (list) => _saveRoster(list),
                        onCurrentWeekDataChanged: _onCurrentWeekDataChanged,
                        rosterName: widget.rosterName,
                      );
                    }
                  } else {
                    // For regular rosters, use the full stream logic
                    // CRITICAL: Only update state if this is initial load OR external change
                    bool shouldUpdate = false;
                    
                    // Initial load case - employees list is empty
                    if (employees.isEmpty && currentEmployees.isNotEmpty) {
                      print('🔄 Initial load - setting employees');
                      shouldUpdate = true;
                    }
                    // Length change from external source (not local addition)
                    else if (employees.length != currentEmployees.length) {
                      // Check if this is a new employee we just added locally
                      bool isLocalAddition = employees.length == currentEmployees.length - 1;
                      if (!isLocalAddition) {
                        print('🔄 Employee count changed externally');
                        shouldUpdate = true;
                      } else {
                        print('✅ Local addition detected - not overwriting');
                      }
                    }
                    // Check for actual data changes (shifts, etc.)
                    else if (employees.length == currentEmployees.length && employees.isNotEmpty) {
                      for (int i = 0; i < employees.length; i++) {
                        if (employees[i].name != currentEmployees[i].name || 
                            employees[i].shifts.length != currentEmployees[i].shifts.length) {
                          print('🔄 Employee data changed externally');
                          shouldUpdate = true;
                          break;
                        }
                      }
                    }
                    
                    if (shouldUpdate) {
                      print('🔄 Updating state with stream data');
                      // Use Future.microtask to avoid setState during build
                      Future.microtask(() {
                        if (mounted) {
                          setState(() {
                            employees = List.from(currentEmployees);
                            _updateWeekDatesFromRoster(currentEmployees);
                          });
                        }
                      });
                    } else {
                      print('✅ No state update needed - using current local data');
                    }
                    
                    return ModernRosterTable(
                      employees: currentEmployees,
                      weekDates: weekDates,
                      onEdit: _openEditDialog,
                      onRosterChanged: (list) => _saveRoster(list),
                      onCurrentWeekDataChanged: _onCurrentWeekDataChanged,
                      rosterName: widget.rosterName,
                    );
                  }
                }
                
                print('🔍 StreamBuilder showing loading spinner...');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading roster...'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async {
                          print('🔄 Manual reload requested');
                          // Force reload data from storage
                          try {
                            final loadedEmployees = await RosterStorage.loadRoster(widget.rosterName);
                            print('✅ Manual reload: loaded ${loadedEmployees.length} employees');
                            if (mounted) {
                              setState(() {
                                employees = loadedEmployees;
                                _updateWeekDatesFromRoster(loadedEmployees);
                              });
                            }
                          } catch (e) {
                            print('❌ Manual reload failed: $e');
                          }
                        },
                        child: Text('Reload Data'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getWeekDescription(DateTime monday) {
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    
    final diffDays = monday.difference(currentMonday).inDays;
    
    if (diffDays == 0) {
      return 'This Week';
    } else if (diffDays == 7) {
      return 'Next Week';
    } else if (diffDays > 0) {
      final weeks = (diffDays / 7).round();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ahead';
    } else {
      final weeks = (diffDays.abs() / 7).round();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
  }

  List<Widget> _buildBankHolidayInfo() {
    final startDate = weekDates['Mon'];
    final endDate = weekDates['Sun'];
    
    if (startDate == null || endDate == null) return [];
    
    // Get bank holidays in this week
    final bankHolidays = IrishBankHolidays.getHolidaysInRange(startDate, endDate);
    
    if (bankHolidays.isEmpty) return [];
    
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.event, color: Colors.red.shade700, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Bank ${bankHolidays.length == 1 ? 'Holiday' : 'Holidays'} This Week',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...bankHolidays.map((holiday) {
              final style = IrishBankHolidays.getHolidayStyle(holiday);
              const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
              final dayName = dayNames[holiday.date.weekday - 1];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(style.icon, size: 14, color: style.textColor),
                    const SizedBox(width: 6),
                    Text(
                      '$dayName: ${holiday.name}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: style.textColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ];
  }

  // NEW: appearance customization dialog
  Future<void> _openCustomizeDialog() async {
    Color? h = headerColor ?? Colors.blueGrey.shade100;
    Color? ht = headerTextColor ?? Colors.black87;
    Color? cb = cellBorderColor ?? Colors.grey.shade400;
    Color? dof = dayOffBgColor ?? Colors.grey.shade100;
    Color? hol = holidayBgColor ?? Colors.red.shade50;

    Color? pick = await _pickColor(context, h, title: 'Header background');
    if (pick != null) h = pick;
    pick = await _pickColor(context, ht, title: 'Header text color');
    if (pick != null) ht = pick;
    pick = await _pickColor(context, cb, title: 'Cell border color');
    if (pick != null) cb = pick;
    pick = await _pickColor(context, dof, title: 'Day-off background');
    if (pick != null) dof = pick;
    pick = await _pickColor(context, hol, title: 'Holiday background');
    if (pick != null) hol = pick;

    setState(() {
      headerColor = h;
      headerTextColor = ht;
      cellBorderColor = cb;
      dayOffBgColor = dof;
      holidayBgColor = hol;
    });
    await _saveStyle();
  }

  Future<Color?> _pickColor(BuildContext context, Color? initial, {String? title}) async {
    final presets = <Color>[
      Colors.white, Colors.black, Colors.grey.shade200, Colors.grey.shade600,
      Colors.red.shade100, Colors.red.shade300, Colors.red.shade600,
      Colors.orange.shade100, Colors.orange.shade300, Colors.orange.shade600,
      Colors.amber.shade100, Colors.amber.shade300, Colors.amber.shade600,
      Colors.yellow.shade100, Colors.yellow.shade300, Colors.yellow.shade600,
      Colors.green.shade100, Colors.green.shade300, Colors.green.shade700,
      Colors.teal.shade100, Colors.teal.shade300, Colors.teal.shade700,
      Colors.blue.shade100, Colors.blue.shade300, Colors.blue.shade700,
      Colors.indigo.shade100, Colors.indigo.shade300, Colors.indigo.shade700,
      Colors.purple.shade100, Colors.purple.shade300, Colors.purple.shade700,
      Colors.pink.shade100, Colors.pink.shade300, Colors.pink.shade700,
    ];
    Color? selected = initial;
    return showDialog<Color?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title ?? 'Select color'),
        content: SizedBox(
          width: 340,
          height: 240,
          child: GridView.count(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: presets.map((c) {
              final isSel = selected?.value == c.value;
              return InkWell(
                onTap: () => selected = c,
                onDoubleTap: () => Navigator.pop(context, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c,
                    border: Border.all(color: isSel ? Colors.black : Colors.grey.shade400, width: isSel ? 2 : 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Select')),
        ],
      ),
    );
  }

  Future<(String, double)?> _showAddEmployeeDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final holidayCtl = TextEditingController(text: '0');
    return showDialog<(String, double)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Employee Name',
                hintText: 'Enter employee name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: holidayCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custom holiday hours (optional)',
                hintText: 'e.g. 2.5',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtl.text.trim();
              final custom = double.tryParse(holidayCtl.text.trim()) ?? 0.0;
              Navigator.pop(context, (name, custom));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
