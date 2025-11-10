import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_model.dart';
import '../services/irish_bank_holidays.dart';
import '../services/roster_storage.dart';
import '../screens/roster_page.dart';
import '../widgets/employee_profile_dialog.dart';
import '../theme/app_theme.dart';

class ModernRosterTable extends StatefulWidget {
  final List<Employee> employees;
  final Map<String, DateTime> weekDates;
  final Future<Shift?> Function(BuildContext, Shift?) onEdit;
  final Future<void> Function(List<Employee>) onRosterChanged;
  final void Function(List<Employee>, DateTime)? onCurrentWeekDataChanged;
  final String rosterName; // Add roster name for persistent weekly data
  final VoidCallback? onAddStaff; // Callback for add staff functionality

  const ModernRosterTable({
    super.key,
    required this.employees,
    required this.weekDates,
    required this.onEdit,
    required this.onRosterChanged,
    required this.rosterName,
    this.onCurrentWeekDataChanged,
    this.onAddStaff,
  });

  @override
  State<ModernRosterTable> createState() => _ModernRosterTableState();
}

class _ModernRosterTableState extends State<ModernRosterTable> {
  static const List<String> _days = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  DateTime _currentWeek = DateTime.now();

  // Week-specific data storage to maintain separate schedules for each week
  final Map<String, Map<String, Map<String, Shift>>> _weeklyData = {};

  // Independent employee data for week-specific rosters
  List<Employee> _independentEmployees = [];

  // Clipboard state for copy/paste functionality
  Shift? _clipboardShift;

  // Color scheme matching original app (white and blue theme)
  // Theme colors - using centralized AppTheme
  static const Color _primaryBlue = AppTheme.primaryBlue;
  static const Color _lightGray = AppTheme.backgroundSecondary;
  static const Color _darkGray = AppTheme.textSecondary;
  static const Color _white = AppTheme.surface;
  static const Color _lightBlue = AppTheme.primaryBlueBackground;

  @override
  void initState() {
    super.initState();
    _initCurrentWeek();
    _initWeeklyData();

    // For week-specific rosters, create independent copies of employee data
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster) {
      // Removed emoji print statement
      _independentEmployees = widget.employees.map((emp) {
        final empJson = emp.toJson();
        final newEmp = Employee.fromJson(empJson);
        // Removed emoji print statement
        return newEmp;
      }).toList();
    }
  }

  // Get the appropriate employee list based on roster type
  List<Employee> _getEmployeeList() {
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    return isWeekSpecificRoster ? _independentEmployees : widget.employees;
  }

  @override
  void didUpdateWidget(ModernRosterTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update independent employees when the widget updates
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster && widget.employees != oldWidget.employees) {
      setState(() {
        _independentEmployees = widget.employees.map((emp) {
          final empJson = emp.toJson();
          final newEmp = Employee.fromJson(empJson);
          return newEmp;
        }).toList();
      });
      print(
          '🔄 Updated independent employees: ${_independentEmployees.length}');
    }
  }

  @override
  void dispose() {
    // IMPORTANT: Do NOT auto-save on dispose for week-specific rosters
    // This causes race conditions when navigating between weeks
    // Removed emoji print statement

    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster) {
      // For week-specific rosters, do NOT auto-save on dispose
      // This prevents race conditions during navigation
      // Removed emoji print statement
      // Removed emoji print statement
    } else {
      // For regular rosters, save weekly data
      // Removed emoji print statement
      _saveWeeklyDataToStorage(widget.rosterName);
    }
    super.dispose();
  }

  void _initCurrentWeek() {
    if (widget.weekDates.isNotEmpty) {
      final mondayDate = widget.weekDates['Mon'];
      if (mondayDate != null) {
        _currentWeek = mondayDate;
      }
    }
  }

  // Initialize weekly data by loading from storage, then load current week
  Future<void> _initWeeklyData() async {
    // Removed emoji print statement
    await _loadWeeklyDataFromStorage(widget.rosterName);
    _loadCurrentWeekData();
  }

  // Generate a unique key for each week
  String _getWeekKey(DateTime week) {
    return '${week.year}-${week.month.toString().padLeft(2, '0')}-${week.day.toString().padLeft(2, '0')}';
  }

  // Load current week's data from storage or widget.employees
  void _loadCurrentWeekData() {
    final weekKey = _getWeekKey(_currentWeek);
    // Removed emoji print statement

    // Check if this is a week-specific roster (like "Week 45", "Week 46", etc.)
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);

    if (isWeekSpecificRoster) {
      // For week-specific rosters, don't use weekly data system - just use the roster's data directly
      // Removed emoji print statement
      return; // Keep the original employee data as-is
    }

    if (_weeklyData.containsKey(weekKey)) {
      // Load from cached weekly data
      // Removed emoji print statement
      final weekData = _weeklyData[weekKey]!;
      final employeeList = _getEmployeeList();
      for (final employee in employeeList) {
        final employeeData = weekData[employee.name] ?? <String, Shift>{};
        employee.shifts.clear();
        employee.shifts.addAll(employeeData);
        // Removed emoji print statement
      }
    } else {
      // First time loading this week - save current data
      // Removed emoji print statement
      _saveCurrentWeekData();
    }
  }

  // Save current week's data to our weekly storage
  void _saveCurrentWeekData() {
    final weekKey = _getWeekKey(_currentWeek);
    // Removed emoji print statement

    // Check if this is a week-specific roster (like "Week 45", "Week 46", etc.)
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);

    if (isWeekSpecificRoster) {
      // For week-specific rosters, save directly to roster storage instead of weekly data
      // Removed emoji print statement
      _saveToRosterStorage(); // This is async but we don't await it to keep the method sync
      _notifyCurrentWeekDataChanged();
      return;
    }

    final employeeList = _getEmployeeList();
    _weeklyData[weekKey] = {};

    for (final employee in employeeList) {
      final shiftsCopy = <String, Shift>{};
      // Create deep copies of shifts to ensure independence
      for (final entry in employee.shifts.entries) {
        final shiftJson = entry.value.toJson();
        shiftsCopy[entry.key] = Shift.fromJson(shiftJson);
      }
      _weeklyData[weekKey]![employee.name] = shiftsCopy;
      // Removed emoji print statement
    }
    // Removed emoji print statement

    // Persist weekly data to storage
    _saveWeeklyDataToStorage(widget.rosterName);

    // Notify parent of current week data changes for PDF generation
    _notifyCurrentWeekDataChanged();
  }

  // Save week-specific roster data directly to roster storage
  Future<void> _saveToRosterStorage() async {
    try {
      // Removed emoji print statement
      final employeeList = _getEmployeeList();
      await RosterStorage.saveRoster(widget.rosterName, employeeList);
      // Removed emoji print statement
    } catch (e) {
      // Removed emoji print statement
    }
  }

  // Notify parent component of current week data for PDF generation
  void _notifyCurrentWeekDataChanged() {
    if (widget.onCurrentWeekDataChanged != null) {
      final employeeList = _getEmployeeList();
      // Defer the callback to prevent setState() during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onCurrentWeekDataChanged!(employeeList, _currentWeek);
        }
      });
    }
  }

  // Persist weekly data to SharedPreferences
  Future<void> _saveWeeklyDataToStorage(String rosterName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final weeklyDataJson = <String, Map<String, Map<String, dynamic>>>{};

      // Convert weekly data to JSON format
      for (final weekEntry in _weeklyData.entries) {
        final weekKey = weekEntry.key;
        final weekData = weekEntry.value;
        weeklyDataJson[weekKey] = {};

        for (final employeeEntry in weekData.entries) {
          final employeeName = employeeEntry.key;
          final shifts = employeeEntry.value;
          weeklyDataJson[weekKey]![employeeName] = {};

          for (final shiftEntry in shifts.entries) {
            final day = shiftEntry.key;
            final shift = shiftEntry.value;
            weeklyDataJson[weekKey]![employeeName]![day] = shift.toJson();
          }
        }
      }

      final jsonString = jsonEncode(weeklyDataJson);
      await prefs.setString('weekly_data_$rosterName', jsonString);
      // Removed emoji print statement
    } catch (e) {
      // Removed emoji print statement
    }
  }

  // Load weekly data from SharedPreferences
  Future<void> _loadWeeklyDataFromStorage(String rosterName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('weekly_data_$rosterName');

      if (jsonString != null) {
        final weeklyDataJson = jsonDecode(jsonString) as Map<String, dynamic>;
        _weeklyData.clear();

        // Convert JSON back to weekly data format
        for (final weekEntry in weeklyDataJson.entries) {
          final weekKey = weekEntry.key;
          final weekData = weekEntry.value as Map<String, dynamic>;
          _weeklyData[weekKey] = {};

          for (final employeeEntry in weekData.entries) {
            final employeeName = employeeEntry.key;
            final shiftsData = employeeEntry.value as Map<String, dynamic>;
            _weeklyData[weekKey]![employeeName] = {};

            for (final shiftEntry in shiftsData.entries) {
              final day = shiftEntry.key;
              final shiftJson = shiftEntry.value as Map<String, dynamic>;
              _weeklyData[weekKey]![employeeName]![day] =
                  Shift.fromJson(shiftJson);
            }
          }
        }

        // Removed emoji print statement
      } else {
        // Removed emoji print statement
      }
    } catch (e) {
      // Removed emoji print statement
      _weeklyData.clear(); // Reset to empty on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          _buildWeekNavigation(),
          _buildHelpfulTips(),
          _buildDayHeaders(),
          _buildRosterContent(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          // Logo/Title area
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: _white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '[appName]',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation() {
    // Check if this is a week-specific roster (like "Week 45", "Week 46", etc.)
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: _white,
      child: Row(
        children: [
          // Date picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _darkGray.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: _darkGray),
                const SizedBox(width: 8),
                Text(
                  '${_currentWeek.year}-${_currentWeek.month.toString().padLeft(2, '0')}-${_currentWeek.day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: _darkGray),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Show different navigation based on roster type - wrap in Expanded to prevent overflow
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (isWeekSpecificRoster) ...[
                  // For week-specific rosters, show week navigation
                  Flexible(child: _buildWeekSpecificNavigation()),
                ] else ...[
                  // For regular rosters, show navigation buttons
                  _buildNavButton('◄◄ Prev Week', () => _navigateWeek(-1)),
                  const SizedBox(width: 8),
                  _buildNavButton('Current Week', () => _goToCurrentWeek()),
                  const SizedBox(width: 8),
                  _buildNavButton('Next Week ►►', () => _navigateWeek(1)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _lightGray,
        foregroundColor: _darkGray,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _darkGray.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(text),
    );
  }

  Widget _buildWeekSpecificNavigation() {
    // Extract current week number from roster name
    final weekMatch = RegExp(r'Week (\d+)').firstMatch(widget.rosterName);
    final currentWeekNumber =
        weekMatch != null ? int.parse(weekMatch.group(1)!) : null;

    if (currentWeekNumber == null) {
      // Fallback for week-specific rosters without number
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: _primaryBlue),
            const SizedBox(width: 8),
            Text(
              'Week-Specific Roster',
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final prevWeekNumber = currentWeekNumber - 1;
    final nextWeekNumber = currentWeekNumber + 1;
    final prevWeekName = 'Week $prevWeekNumber';
    final nextWeekName = 'Week $nextWeekNumber';

    return Row(
      children: [
        // Current week indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: _primaryBlue),
              const SizedBox(width: 8),
              Text(
                widget.rosterName,
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Previous week button
        ElevatedButton(
          onPressed: () async {
            print('Previous week button clicked for $prevWeekName');
            print(
                'About to get roster names directly from SharedPreferences...');
            try {
              // Get roster names directly from SharedPreferences instead of stream
              final prefs = await SharedPreferences.getInstance();
              final rosterNames =
                  prefs.getStringList('roster_names') ?? <String>[];
              print('Got roster names directly: ${rosterNames.join(", ")}');
              final exists = rosterNames.contains(prevWeekName);
              print('Does $prevWeekName exist? $exists');

              if (exists) {
                print('Navigating to existing $prevWeekName');
                _navigateToWeekRoster(prevWeekName);
              } else {
                print('Showing dialog to create new $prevWeekName');
                // Get current week shifts for copying option
                final currentWeekShifts = _getCurrentWeekShifts();
                _showCreateNewWeekDialog(prevWeekName, currentWeekShifts);
              }
            } catch (e) {
              print('Error in navigation logic: $e');
              print('Stack trace: ${StackTrace.current}');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue.withOpacity(0.1),
            foregroundColor: _primaryBlue,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 14),
              const SizedBox(width: 4),
              Text('◄ $prevWeekName', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Next week button
        ElevatedButton(
          onPressed: () async {
            print('Next week button clicked for $nextWeekName');
            print(
                'About to get roster names directly from SharedPreferences...');
            try {
              // Get roster names directly from SharedPreferences instead of stream
              final prefs = await SharedPreferences.getInstance();
              final rosterNames =
                  prefs.getStringList('roster_names') ?? <String>[];
              print('Got roster names directly: ${rosterNames.join(", ")}');
              final exists = rosterNames.contains(nextWeekName);
              print('Does $nextWeekName exist? $exists');

              if (exists) {
                print('Navigating to existing $nextWeekName');
                _navigateToWeekRoster(nextWeekName);
              } else {
                print('Showing dialog to create new $nextWeekName');
                // Get current week shifts for copying option
                final currentWeekShifts = _getCurrentWeekShifts();
                _showCreateNewWeekDialog(nextWeekName, currentWeekShifts);
              }
            } catch (e) {
              print('Error in navigation logic: $e');
              print('Stack trace: ${StackTrace.current}');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue.withOpacity(0.1),
            foregroundColor: _primaryBlue,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 14),
              const SizedBox(width: 4),
              Text('$nextWeekName ►', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpfulTips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryBlue.withOpacity(0.05),
            Colors.indigo.withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primaryBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.lightbulb, color: _primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tips:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• Tap empty cells to add shifts  • Drag & drop shifts to move them  • Long-press shifts for options (copy, edit, delete)',
                  style: TextStyle(
                    fontSize: 12,
                    color: _darkGray,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Employee name column header
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Text(
              'Employees',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkGray,
              ),
            ),
          ),

          // Day headers
          Expanded(
            child: Row(
              children: _days.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                final date = widget.weekDates[day];

                return Expanded(
                  child: _buildDayHeader(day, date, index),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(String day, DateTime? date, int dayIndex) {
    final bankHoliday =
        date != null ? IrishBankHolidays.getBankHoliday(date) : null;
    final isBankHoliday = bankHoliday != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: _darkGray.withOpacity(0.2),
            width: dayIndex == 0 ? 1 : 0,
          ),
          right: BorderSide(color: _darkGray.withOpacity(0.2)),
        ),
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isBankHoliday ? Colors.red : _primaryBlue,
            ),
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              '${date.day}${_getOrdinalSuffix(date.day)} ${_getMonthAbbr(date.month)}',
              style: TextStyle(
                fontSize: 12,
                color: isBankHoliday ? Colors.red : _darkGray,
              ),
            ),
            if (isBankHoliday) ...[
              const SizedBox(height: 2),
              Text(
                bankHoliday.name,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRosterContent() {
    final employeeList = _getEmployeeList();

    return Container(
      color: _white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Employee rows - Use direct list instead of ListView with Expanded
          ...employeeList.asMap().entries.map((entry) {
            final index = entry.key;
            final employee = entry.value;
            return _buildEmployeeRow(employee, index);
          }),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Employee employee, int index) {
    final isEvenRow = index % 2 == 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isEvenRow ? _lightGray.withOpacity(0.3) : _white,
        border: Border(
          bottom: BorderSide(color: _darkGray.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Employee info
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildEmployeeInfo(employee),
          ),

          // Shift cells
          Expanded(
            child: Row(
              children: _days.map((day) {
                final shift = employee.shifts[day];
                return Expanded(
                  child: _buildShiftCell(employee, day, shift),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfo(Employee employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 12,
              backgroundColor: _primaryBlue,
              child: Text(
                employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _darkGray,
                    ),
                  ),
                  Text(
                    '${employee.totalWorkedHours.toStringAsFixed(1)}hrs',
                    style: TextStyle(
                      fontSize: 12,
                      color: _darkGray.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Delete button - compact size
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                onPressed: () {
                  print('🗑️ Delete button clicked for ${employee.name}');
                  _showDeleteEmployeeDialog(employee.name);
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove ${employee.name}',
                iconSize: 16,
                color: Colors.red,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showEmployeeProfile(employee),
          child: Text(
            'View profile',
            style: TextStyle(
              fontSize: 12,
              color: _primaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCell(Employee employee, String day, Shift? shift) {
    if (shift != null) {
      // Existing shift - make it draggable
      return Draggable<Map<String, dynamic>>(
        data: {
          'shift': shift,
          'sourceEmployee': employee.name,
          'sourceDay': day,
        },
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getShiftCellColor(shift).withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _primaryBlue, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drag_handle, color: _primaryBlue, size: 16),
                const SizedBox(height: 4),
                _buildShiftContent(shift),
              ],
            ),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: Colors.grey.shade400, style: BorderStyle.solid),
          ),
          child: Center(
            child: Text(
              'Moving...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        child: _buildInteractiveShiftCell(employee, day, shift),
      );
    } else {
      // Empty cell - make it a drop target
      return DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (details) => details.data['shift'] != null,
        onAcceptWithDetails: (details) {
          final data = details.data;
          final draggedShift = data['shift'] as Shift;
          final sourceEmployee = data['sourceEmployee'] as String;
          final sourceDay = data['sourceDay'] as String;

          _moveShift(
              sourceEmployee, sourceDay, employee.name, day, draggedShift);
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return GestureDetector(
            onTap: () => _addShiftToCell(employee, day),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isHovering
                    ? _primaryBlue.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isHovering
                      ? _primaryBlue
                      : _hasClipboard()
                          ? _primaryBlue.withOpacity(0.5)
                          : _darkGray.withOpacity(0.2),
                  width: isHovering ? 2 : (_hasClipboard() ? 2 : 0.5),
                ),
              ),
              child: Stack(
                children: [
                  _buildShiftContent(shift),
                  if (isHovering)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_circle,
                            color: _primaryBlue,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  // Add visual indicator for empty cells when clipboard has data
                  if (_hasClipboard() && shift == null && !isHovering)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  // Add visual indicator for clickable empty cells
                  if (shift == null && !_hasClipboard() && !isHovering)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Icon(
                        Icons.add_circle_outline,
                        size: 16,
                        color: _darkGray.withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Color _getShiftCellColor(Shift? shift) {
    if (shift == null) return Colors.transparent;

    if (shift.isHoliday) return Colors.green[100]!;

    // For work shifts, use role-based colors
    return shift.role?.toLowerCase().contains('manager') == true
        ? Colors.orange[100]! // Manager shifts in light orange
        : _lightBlue;
  }

  Widget _buildShiftContent(Shift? shift) {
    if (shift == null) {
      return const SizedBox(height: 40);
    }

    if (shift.isHoliday) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Holiday',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _darkGray,
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator,
            size: 14,
            color: _darkGray.withOpacity(0.6),
          ),
        ],
      );
    } else if (shift.startTime != null && shift.endTime != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_formatTime(shift.startTime!)} - ${_formatTime(shift.endTime!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.brown[700],
                  ),
                ),
                if (shift.role?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    shift.role!,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.brown[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.drag_indicator,
            size: 14,
            color: Colors.brown[600]?.withOpacity(0.6),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'Day Off',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _darkGray,
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator,
            size: 14,
            color: _darkGray.withOpacity(0.6),
          ),
        ],
      );
    }
  }

  // Interactive shift cell with hover effects and quick actions
  Widget _buildInteractiveShiftCell(
      Employee employee, String day, Shift shift) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () => _editShift(employee, day, shift),
            onLongPress: () => _showQuickActions(context, employee, day, shift),
            child: Tooltip(
              message: 'Click to edit • Long press for options',
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _getShiftCellColor(shift),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _darkGray.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    _buildShiftContent(shift),
                    // Quick action buttons on hover (desktop) or always visible (mobile)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQuickActionButton(
                            icon: Icons.copy,
                            onTap: () =>
                                _copyShiftToClipboard(employee, day, shift),
                            tooltip: 'Copy',
                          ),
                          const SizedBox(width: 2),
                          _buildQuickActionButton(
                            icon: Icons.delete_outline,
                            onTap: () =>
                                _confirmDeleteShift(employee, day, shift),
                            tooltip: 'Delete',
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : _primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 12,
            color: isDestructive ? Colors.red : _primaryBlue,
          ),
        ),
      ),
    );
  }

  void _showQuickActions(
      BuildContext context, Employee employee, String day, Shift shift) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + renderBox.size.height,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height + 100,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.edit, size: 18, color: _primaryBlue),
              const SizedBox(width: 8),
              const Text('Edit'),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _editShift(employee, day, shift),
          ),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              Icon(Icons.copy, size: 18, color: _primaryBlue),
              const SizedBox(width: 8),
              const Text('Copy'),
            ],
          ),
          onTap: () => _copyShiftToClipboard(employee, day, shift),
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              const Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => Future.delayed(
            const Duration(milliseconds: 100),
            () => _confirmDeleteShift(employee, day, shift),
          ),
        ),
      ],
    );
  }

  // Clipboard and cell interaction methods
  bool _hasClipboard() {
    return _clipboardShift != null;
  }

  void _moveShift(String sourceEmployeeName, String sourceDay,
      String targetEmployeeName, String targetDay, Shift shift) {
    // Removed emoji print statement
    // Removed emoji print statement

    final employeeList = _getEmployeeList();

    // Find source and target employees
    final sourceEmployee =
        employeeList.firstWhere((e) => e.name == sourceEmployeeName);
    final targetEmployee =
        employeeList.firstWhere((e) => e.name == targetEmployeeName);

    setState(() {
      // Remove shift from source
      sourceEmployee.shifts.remove(sourceDay);
      // Removed emoji print statement

      // Add shift to target (create deep copy to avoid reference issues)
      final shiftJson = shift.toJson();
      final newShift = Shift.fromJson(shiftJson);
      targetEmployee.shifts[targetDay] = newShift;
      // Removed emoji print statement
    });

    // Save current week data after modification
    _saveCurrentWeekData();
    widget.onRosterChanged(employeeList);
    _notifyCurrentWeekDataChanged();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  const Icon(Icons.swap_horiz, color: Colors.green, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Moved shift from $sourceEmployeeName ($sourceDay) to $targetEmployeeName ($targetDay)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmDeleteShift(Employee employee, String day, Shift shift) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Shift',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this shift?',
              style: TextStyle(fontSize: 16, color: _darkGray),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${employee.name} - $day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shift.isHoliday
                        ? 'Holiday'
                        : shift.startTime != null && shift.endTime != null
                            ? '${_formatTime(shift.startTime!)} - ${_formatTime(shift.endTime!)}'
                            : 'Shift',
                    style: TextStyle(color: _darkGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteShift(employee, day, shift);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteShift(Employee employee, String day, Shift shift) {
    setState(() {
      employee.shifts.remove(day);
    });

    final employeeList = _getEmployeeList();

    // Save current week data after modification
    _saveCurrentWeekData();
    widget.onRosterChanged(employeeList);
    _notifyCurrentWeekDataChanged();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.delete, color: Colors.red, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Deleted shift for ${employee.name} ($day)',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyShiftToClipboard(Employee employee, String day, Shift shift) {
    // Removed emoji print statement
    setState(() {
      // Create a deep copy to avoid reference issues
      final shiftJson = shift.toJson();
      _clipboardShift = Shift.fromJson(shiftJson);
      // Removed emoji print statement
    });
  }

  Future<void> _addShiftToCell(Employee employee, String day) async {
    if (_hasClipboard()) {
      // Paste from clipboard
      await _pasteShiftToCell(employee, day);
    } else {
      // Create new shift
      final newShift = await widget.onEdit(context, null);
      if (newShift != null) {
        setState(() {
          employee.shifts[day] = newShift;
        });

        final employeeList = _getEmployeeList();

        // Save current week data after modification
        _saveCurrentWeekData();
        widget.onRosterChanged(employeeList);
        _notifyCurrentWeekDataChanged();
      }
    }
  }

  Future<void> _pasteShiftToCell(Employee employee, String day) async {
    if (_clipboardShift != null) {
      // Removed emoji print statement
      setState(() {
        // Create a deep copy to avoid reference issues
        final shiftJson = _clipboardShift!.toJson();
        final newShift = Shift.fromJson(shiftJson);
        employee.shifts[day] = newShift;
        // Removed emoji print statement
        // Clear clipboard after paste
        _clipboardShift = null;
      });

      final employeeList = _getEmployeeList();

      // Save current week data after modification
      _saveCurrentWeekData();
      widget.onRosterChanged(employeeList);
      _notifyCurrentWeekDataChanged();
    }
  }

  // Helper methods
  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _getMonthAbbr(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Action methods
  void _navigateWeek(int direction) {
    // Safety check: Week-specific rosters should never use this method
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster) {
      // Removed emoji print statement
      return;
    }

    // Save current week's data before navigation
    _saveCurrentWeekData();

    // Store current week's shifts for copying to next week (if going forward)
    Map<String, Map<String, Shift>> currentWeekShifts = {};
    if (direction == 1) {
      final employeeList = _getEmployeeList();
      for (final employee in employeeList) {
        final shiftsCopy = <String, Shift>{};
        // Create deep copies for copying
        for (final entry in employee.shifts.entries) {
          final shiftJson = entry.value.toJson();
          shiftsCopy[entry.key] = Shift.fromJson(shiftJson);
        }
        currentWeekShifts[employee.name] = shiftsCopy;
      }
      // Removed emoji print statement
    }

    setState(() {
      _currentWeek = _currentWeek.add(Duration(days: 7 * direction));
      // Update week dates
      for (int i = 0; i < 7; i++) {
        widget.weekDates[_days[i]] = _currentWeek.add(Duration(days: i));
      }
    });

    // Load data for the new week
    final newWeekKey = _getWeekKey(_currentWeek);
    bool isNewWeek = !_weeklyData.containsKey(newWeekKey);
    // Removed emoji print statement

    if (isNewWeek && direction == 1 && currentWeekShifts.isNotEmpty) {
      // New week going forward - offer to create a new roster or just copy data
      _showCreateNewWeekDialog(newWeekKey, currentWeekShifts);
    } else {
      // Load existing week data or start with empty week
      // Removed emoji print statement
      _loadCurrentWeekData();
    }

    // Notify parent of week change and current data
    final employeeList = _getEmployeeList();
    widget.onRosterChanged(employeeList);
    _notifyCurrentWeekDataChanged();
  }

  // Get current week shifts for copying to new week
  Map<String, Map<String, Shift>> _getCurrentWeekShifts() {
    Map<String, Map<String, Shift>> currentWeekShifts = {};
    final employeeList = _getEmployeeList();
    for (final employee in employeeList) {
      final shiftsCopy = <String, Shift>{};
      // Create deep copies for copying
      for (final entry in employee.shifts.entries) {
        final shiftJson = entry.value.toJson();
        shiftsCopy[entry.key] = Shift.fromJson(shiftJson);
      }
      currentWeekShifts[employee.name] = shiftsCopy;
    }
    return currentWeekShifts;
  }

  // Show dialog to ask user if they want to create a new roster for the next week
  void _showCreateNewWeekDialog(
      String newWeekKey, Map<String, Map<String, Shift>> currentWeekShifts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_month, color: _primaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Moving to New Week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you like to set up the new week?',
              style: TextStyle(fontSize: 16, color: _darkGray),
            ),
            const SizedBox(height: 16),

            // Option 1: Fresh clean roster
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cleaning_services,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Fresh Clean Roster',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Keep only staff names, start with empty schedule. Perfect for creating a completely new roster.',
                    style: TextStyle(color: _darkGray, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Option 2: Copy entire roster
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.copy_all, color: _primaryBlue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Copy Entire Roster',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Copy all staff and their complete schedules. Great for repeating similar weekly patterns.',
                    style: TextStyle(color: _darkGray, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Create fresh roster with only staff names
              _createFreshRoster(newWeekKey);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade700,
            ),
            child: const Text('Fresh Clean'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Copy entire roster with all shifts
              _copyEntireRoster(newWeekKey, currentWeekShifts);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy All'),
          ),
        ],
      ),
    );
  }

  // Create fresh roster with only staff names (no shifts)
  void _createFreshRoster(String newWeekKey) async {
    print('🧹 Creating fresh roster for week: $newWeekKey');

    try {
      // Create new employees with only names (no shifts)
      final newEmployees = <Employee>[];
      final employeeList = _getEmployeeList();
      for (final employee in employeeList) {
        final newEmployee = Employee(
          name: employee.name,
          shifts: <String, Shift>{}, // Empty shifts
          accumulatedWorkedHours: 0,
          accumulatedTotalHours: 0,
          accumulatedHolidayHours: 0,
          employeeColor: employee.employeeColor,
          rosterStartDate: DateTime.now(),
          rosterEndDate: DateTime.now().add(const Duration(days: 6)),
        );
        newEmployees.add(newEmployee);
      }

      // Create the new roster using RosterStorage
      await RosterStorage.createRoster(newWeekKey, newEmployees);

      // Navigate to the new roster
      _navigateToWeekRoster(newWeekKey);

      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.cleaning_services,
                    color: Colors.green, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'Fresh roster "$newWeekKey" created with staff names only',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error creating fresh roster: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating fresh roster: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Copy entire roster with all shifts
  void _copyEntireRoster(String newWeekKey,
      Map<String, Map<String, Shift>> currentWeekShifts) async {
    print('📋 Copying entire roster to week: $newWeekKey');

    try {
      // Create new employees with copied shifts
      final newEmployees = <Employee>[];
      final employeeList = _getEmployeeList();

      for (final employee in employeeList) {
        final employeeShifts =
            currentWeekShifts[employee.name] ?? <String, Shift>{};

        final newEmployee = Employee(
          name: employee.name,
          shifts: Map<String, Shift>.from(employeeShifts), // Copy all shifts
          accumulatedWorkedHours: employee.accumulatedWorkedHours,
          accumulatedTotalHours: employee.accumulatedTotalHours,
          accumulatedHolidayHours: employee.accumulatedHolidayHours,
          employeeColor: employee.employeeColor,
          rosterStartDate: DateTime.now(),
          rosterEndDate: DateTime.now().add(const Duration(days: 6)),
        );
        newEmployees.add(newEmployee);
        print(
            '  📅 Copied ${employeeShifts.length} shifts for ${employee.name}');
      }

      // Create the new roster using RosterStorage
      await RosterStorage.createRoster(newWeekKey, newEmployees);

      // Navigate to the new roster
      _navigateToWeekRoster(newWeekKey);

      // Show notification
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.copy_all, color: _primaryBlue, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'Complete roster "$newWeekKey" copied with all shifts',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: _primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('Error copying entire roster: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error copying entire roster: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToCurrentWeek() {
    // Safety check: Week-specific rosters should never use this method
    final isWeekSpecificRoster =
        RegExp(r'^Week \d+$').hasMatch(widget.rosterName);
    if (isWeekSpecificRoster) {
      // Removed emoji print statement
      return;
    }

    // Save current week's data before navigation
    _saveCurrentWeekData();

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _currentWeek = monday;
      for (int i = 0; i < 7; i++) {
        widget.weekDates[_days[i]] = monday.add(Duration(days: i));
      }
    });

    // Load data for current week
    _loadCurrentWeekData();

    // Notify parent of week change and current data
    final employeeList = _getEmployeeList();
    widget.onRosterChanged(employeeList);
    _notifyCurrentWeekDataChanged();
  }

  Future<void> _editShift(Employee employee, String day, Shift? shift) async {
    final editedShift = await widget.onEdit(context, shift);
    if (editedShift != null) {
      setState(() {
        employee.shifts[day] = editedShift;
      });

      final employeeList = _getEmployeeList();

      // Save current week data after modification
      _saveCurrentWeekData();
      widget.onRosterChanged(employeeList);
      _notifyCurrentWeekDataChanged();
    }
  }

  void _showEmployeeProfile(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => EmployeeProfileDialog(
        employee: employee,
        weekDates: widget.weekDates,
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: _primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _darkGray,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _darkGray,
          ),
        ),
      ],
    );
  }

  void _navigateToWeekRoster(String rosterName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RosterPage(rosterName: rosterName)),
    );
  }

  void _showDeleteEmployeeDialog(String employeeName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Remove Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to remove "$employeeName"?'),
              SizedBox(height: 16),
              Text(
                'Choose removal scope:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close delete dialog
                Navigator.of(context).pop(); // Close employee profile dialog
                _removeStaffMember(employeeName, false);
              },
              child: Text('Current Week Only'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close delete dialog
                Navigator.of(context).pop(); // Close employee profile dialog
                _removeStaffMember(employeeName, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('All Future Weeks'),
            ),
          ],
        );
      },
    );
  }

  // Staff Management Methods
  // Public method for adding staff - can be called from parent widget
  void showAddStaffDialog() {
    _showAddStaffDialog();
  }

  void _showAddStaffDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Staff Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'This staff member will be added to ${widget.rosterName} and all future weeks.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _addStaffMember(nameController.text.trim()),
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addStaffMember(String name) {
    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    // Check if employee already exists
    bool exists = _independentEmployees
        .any((emp) => emp.name.toLowerCase() == name.toLowerCase());

    setState(() {
      if (!exists) {
        _independentEmployees.add(Employee(name: name));
        print('Staff Management: Added "$name" to ${widget.rosterName}');
        print(
            'Staff Management: Current staff count: ${_independentEmployees.length}');

        // Save to current week
        _saveCurrentWeekData();

        // Add to all future weeks as well
        _addStaffToFutureWeeks(name);
      }
    });

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(exists
            ? 'Staff member "$name" already exists'
            : 'Added staff member "$name"'),
        backgroundColor: exists ? Colors.orange : Colors.green,
      ),
    );
  }

  void _addStaffToFutureWeeks(String name) async {
    try {
      // Get all week rosters from storage
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('roster_Week'))
          .toList();

      // Extract week numbers
      List<int> weekNumbers = [];
      for (String key in keys) {
        final weekStr = key.replaceFirst('roster_Week', '');
        final weekNum = int.tryParse(weekStr);
        if (weekNum != null) {
          weekNumbers.add(weekNum);
        }
      }

      // Get current week number
      final currentWeekStr = widget.rosterName.replaceFirst('Week', '');
      final currentWeekNum = int.tryParse(currentWeekStr);

      if (currentWeekNum != null) {
        // Add to all future weeks
        for (int weekNum in weekNumbers) {
          if (weekNum > currentWeekNum) {
            final weekKey = 'roster_Week$weekNum';
            final weekData = prefs.getString(weekKey);

            if (weekData != null) {
              try {
                final Map<String, dynamic> data = json.decode(weekData);
                List<dynamic> employeesJson = data['employees'] ?? [];
                List<Employee> employees =
                    employeesJson.map((e) => Employee.fromJson(e)).toList();

                // Check if employee already exists in this week
                bool exists = employees
                    .any((emp) => emp.name.toLowerCase() == name.toLowerCase());

                if (!exists) {
                  employees.add(Employee(name: name));
                  data['employees'] = employees.map((e) => e.toJson()).toList();
                  await prefs.setString(weekKey, json.encode(data));
                  print('Staff Management: Added "$name" to Week$weekNum');
                }
              } catch (e) {
                print('Staff Management: Error adding to Week$weekNum: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Staff Management: Error adding to future weeks: $e');
    }
  }

  void _removeStaffMember(String name, bool removeFromFuture) async {
    setState(() {
      _independentEmployees.removeWhere((emp) => emp.name == name);
      print('Staff Management: Removed "$name" from ${widget.rosterName}');
      print(
          'Staff Management: Current staff count: ${_independentEmployees.length}');
    });

    // Save current week
    _saveCurrentWeekData();

    if (removeFromFuture) {
      await _removeStaffFromFutureWeeks(name);
    }

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(removeFromFuture
            ? 'Removed "$name" from current and all future weeks'
            : 'Removed "$name" from ${widget.rosterName} only'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _removeStaffFromFutureWeeks(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith('roster_Week'))
          .toList();

      // Extract week numbers
      List<int> weekNumbers = [];
      for (String key in keys) {
        final weekStr = key.replaceFirst('roster_Week', '');
        final weekNum = int.tryParse(weekStr);
        if (weekNum != null) {
          weekNumbers.add(weekNum);
        }
      }

      // Get current week number
      final currentWeekStr = widget.rosterName.replaceFirst('Week', '');
      final currentWeekNum = int.tryParse(currentWeekStr);

      if (currentWeekNum != null) {
        // Remove from all future weeks
        for (int weekNum in weekNumbers) {
          if (weekNum > currentWeekNum) {
            final weekKey = 'roster_Week$weekNum';
            final weekData = prefs.getString(weekKey);

            if (weekData != null) {
              try {
                final Map<String, dynamic> data = json.decode(weekData);
                List<dynamic> employeesJson = data['employees'] ?? [];
                List<Employee> employees =
                    employeesJson.map((e) => Employee.fromJson(e)).toList();

                // Remove the employee
                employees.removeWhere((emp) => emp.name == name);
                data['employees'] = employees.map((e) => e.toJson()).toList();
                await prefs.setString(weekKey, json.encode(data));
                print('Staff Management: Removed "$name" from Week$weekNum');
              } catch (e) {
                print('Staff Management: Error removing from Week$weekNum: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Staff Management: Error removing from future weeks: $e');
    }
  }
}
