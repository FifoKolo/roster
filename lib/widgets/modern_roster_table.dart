import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee_document.dart';
import '../models/employee_model.dart';
import '../services/irish_bank_holidays.dart';
import '../services/roster_storage.dart';
import '../services/time_service.dart';
import '../services/orientation_service.dart';
import '../screens/roster_page.dart';
import '../widgets/employee_profile_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/responsive_helper.dart';

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
  DateTime _currentWeek = TimeService.nowSync();

  // Week-specific data storage to maintain separate schedules for each week
  final Map<String, Map<String, Map<String, Shift>>> _weeklyData = {};

  // Independent employee data for week-specific rosters
  List<Employee> _independentEmployees = [];

  // Clipboard state for copy/paste functionality
  Shift? _clipboardShift;

  // Quick copy mode state
  bool _copyModeActive = false;
  Shift? _copiedShift;
  final Set<String> _selectedCellsForPaste = {}; // Format: "employeeName|day"
  
  // Move mode state (cut and paste)
  bool _moveModeActive = false;
  String? _moveSourceEmployee;
  String? _moveSourceDay;

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
        Employee.isWeekStyleRosterName(widget.rosterName);
    if (isWeekSpecificRoster) {
      _independentEmployees = widget.employees.map((emp) {
        final empJson = emp.toJson();
        return Employee.fromJson(empJson);
      }).toList();
    }
  }

  // Get the appropriate employee list based on roster type
  List<Employee> _getEmployeeList() {
    if (Employee.isWeekStyleRosterName(widget.rosterName)) {
      return _independentEmployees;
    }
    final list = List<Employee>.from(widget.employees);
    list.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    return list;
  }

  @override
  void didUpdateWidget(ModernRosterTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update independent employees when the widget updates
    final isWeekSpecificRoster =
        Employee.isWeekStyleRosterName(widget.rosterName);
    if (isWeekSpecificRoster && widget.employees != oldWidget.employees) {
      setState(() {
        _independentEmployees = widget.employees.map((emp) {
          final empJson = emp.toJson();
          return Employee.fromJson(empJson);
        }).toList();
      });
      print(
          '🔄 Updated independent employees: ${_independentEmployees.length}');
    }
    
    // Update current week when weekDates change (important for week-specific rosters)
    if (widget.weekDates['Mon'] != oldWidget.weekDates['Mon']) {
      final newMonday = widget.weekDates['Mon'];
      if (newMonday != null && newMonday != _currentWeek) {
        setState(() {
          _currentWeek = newMonday;
          print('🔄 Updated _currentWeek to: ${_currentWeek.toIso8601String().split('T')[0]}');
        });
        // Notify parent of the new week
        _notifyCurrentWeekDataChanged();
      }
    }
  }

  @override
  void dispose() {
    // IMPORTANT: Do NOT auto-save on dispose for week-specific rosters
    // This causes race conditions when navigating between weeks
    // Removed emoji print statement

    final isWeekSpecificRoster =
        Employee.isWeekStyleRosterName(widget.rosterName);
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
        Employee.isWeekStyleRosterName(widget.rosterName);

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
  Future<void> _saveCurrentWeekData() async {
    final weekKey = _getWeekKey(_currentWeek);
    // Removed emoji print statement

    // Check if this is a week-specific roster (like "Week 45", "Week 46", etc.)
    final isWeekSpecificRoster =
        Employee.isWeekStyleRosterName(widget.rosterName);

    if (isWeekSpecificRoster) {
      // For week-specific rosters, save directly to roster storage instead of weekly data
      await _saveToRosterStorage();
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
    await _saveWeeklyDataToStorage(widget.rosterName);

    // Notify parent of current week data changes for PDF generation
    _notifyCurrentWeekDataChanged();
  }

  // Save week-specific roster data directly to roster storage
  Future<void> _saveToRosterStorage() async {
    try {
      final employeeList = _getEmployeeList();
      // Debug: verify custom values before saving
      for (final emp in employeeList) {
        if (emp.customAccumulatedHours != null || emp.customHolidayHours != null) {
          print('💾 Saving employee: ${emp.name}');
          print('   customAccumulatedHours: ${emp.customAccumulatedHours}');
          print('   customHolidayHours: ${emp.customHolidayHours}');
        }
      }
      await RosterStorage.saveRoster(widget.rosterName, employeeList);
    } catch (e) {
      print('❌ Error saving to roster storage: $e');
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Stack(
      children: [
        Container(
          width: isMobile ? null : screenWidth, // Let mobile scroll, constrain desktop
          decoration: BoxDecoration(
            color: _lightGray,
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildWeekNavigation(),
              if (isMobile) _buildMobileQuickActions(),
              _buildDayHeaders(),
              _buildRosterContent(),
            ],
          ),
        ),
        // Copy mode action bar
        if (_copyModeActive) _buildCopyModeActionBar(),
      ],
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
                'Roster IE',
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
    final isMobile = ResponsiveHelper.isMobile(context);
    // Check if this is a week-specific roster (like "Week 45", "Week 46", etc.)
    final isWeekSpecificRoster =
        Employee.isWeekStyleRosterName(widget.rosterName);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 20,
        vertical: isMobile ? 10 : 16,
      ),
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

  Widget _buildMobileQuickActions() {
    final hasActionState = _copyModeActive || _moveModeActive || _hasClipboard();
    final statusText = _copyModeActive
        ? 'Copy mode: select cells, then tap Apply.'
        : _moveModeActive
            ? 'Move mode: tap destination cell.'
            : _hasClipboard()
                ? 'Copied shift ready: tap a cell to paste.'
                : 'Tip: long-press a shift for quick actions.';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _primaryBlue.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: hasActionState ? _primaryBlue : _darkGray,
              fontWeight: hasActionState ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.onAddStaff != null)
                ElevatedButton.icon(
                  onPressed: widget.onAddStaff,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add Staff'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 42),
                  ),
                ),
              if (_copyModeActive)
                ElevatedButton.icon(
                  onPressed: _selectedCellsForPaste.isEmpty ? null : _applyCopyMode,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('Apply (${_selectedCellsForPaste.length})'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 42),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              if (_copyModeActive)
                OutlinedButton.icon(
                  onPressed: _cancelCopyMode,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel Copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(128, 42),
                  ),
                ),
              if (_moveModeActive)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _moveModeActive = false;
                      _moveSourceEmployee = null;
                      _moveSourceDay = null;
                      _clipboardShift = null;
                    });
                  },
                  icon: const Icon(Icons.cancel, size: 18),
                  label: const Text('Cancel Move'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(126, 42),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String text, VoidCallback onPressed) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue.withOpacity(0.1),
        foregroundColor: _primaryBlue,
        elevation: 0,
        minimumSize: Size(0, isMobile ? 42 : 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 16,
          vertical: isMobile ? 9 : 8,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: isMobile ? 13 : 14),
      ),
    );
  }

  Widget _buildWeekSpecificNavigation() {
    final isMobile = ResponsiveHelper.isMobile(context);
    // Extract current week number from roster name (no year)
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

    // Calculate year for prev/next weeks based on current roster dates
    int currentYear = TimeService.nowSync().year;
    final employeeList = _getEmployeeList();
    if (employeeList.isNotEmpty && employeeList.first.rosterStartDate != null) {
      currentYear = employeeList.first.rosterStartDate!.year;
    }
    
    // Determine year for previous week
    int prevYear = currentYear;
    if (prevWeekNumber < 1) {
      prevYear = currentYear - 1;
    } else if (currentWeekNumber <= 10 && prevWeekNumber >= 45) {
      // Crossing from January back to December
      prevYear = currentYear - 1;
    }
    
    // Determine year for next week
    int nextYear = currentYear;
    if (nextWeekNumber > 53) {
      nextYear = currentYear + 1;
    } else if (currentWeekNumber >= 45 && nextWeekNumber <= 10) {
      // Crossing from December to January
      nextYear = currentYear + 1;
    }

    // Build prev/next names - only include year if crossing year boundary or week > 53
    final String prevWeekName = prevWeekNumber < 1 
        ? 'Week ${52 + prevWeekNumber}' 
        : (prevYear != currentYear ? 'Week $prevWeekNumber $prevYear' : 'Week $prevWeekNumber');
    final String nextWeekName = nextWeekNumber > 53 
        ? 'Week ${nextWeekNumber - 52}' 
        : (nextYear != currentYear ? 'Week $nextWeekNumber $nextYear' : 'Week $nextWeekNumber');

    final navRow = Row(
      children: [
        // Current week indicator
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 16,
            vertical: isMobile ? 10 : 8,
          ),
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
                  fontSize: isMobile ? 14 : 13,
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
            print('Getting roster names from RosterStorage (cloud or local)...');
            try {
              // Use robust one-shot fetch with timeout + local fallback
              final rosterNames = await RosterStorage.getRosterNamesOnce();
              print('Got roster names: ${rosterNames.join(", ")}');
              
              // Check for exact match first
              var exists = rosterNames.contains(prevWeekName);
              var targetName = prevWeekName;
              
              // If not found, try alternative format (with/without year)
              if (!exists) {
                final altName = _getAlternativeWeekName(prevWeekName, prevYear);
                print('Exact match not found, trying alternative: $altName');
                if (rosterNames.contains(altName)) {
                  exists = true;
                  targetName = altName;
                  print('Found alternative format: $altName');
                }
              }
              print('Does $targetName exist? $exists');

              if (exists) {
                print('Navigating to existing $targetName');
                _navigateToWeekRoster(targetName);
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
            minimumSize: Size(0, isMobile ? 42 : 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 12,
              vertical: isMobile ? 8 : 6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: isMobile ? 16 : 14),
              const SizedBox(width: 4),
              Text(
                '◄ $prevWeekName',
                style: TextStyle(fontSize: isMobile ? 13 : 12),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Next week button
        ElevatedButton(
          onPressed: () async {
            print('Next week button clicked for $nextWeekName');
            print('Getting roster names from RosterStorage (cloud or local)...');
            try {
              // Use robust one-shot fetch with timeout + local fallback
              final rosterNames = await RosterStorage.getRosterNamesOnce();
              print('Got roster names: ${rosterNames.join(", ")}');
              
              // Check for exact match first
              var exists = rosterNames.contains(nextWeekName);
              var targetName = nextWeekName;
              
              // If not found, try alternative format (with/without year)
              if (!exists) {
                final altName = _getAlternativeWeekName(nextWeekName, nextYear);
                print('Exact match not found, trying alternative: $altName');
                if (rosterNames.contains(altName)) {
                  exists = true;
                  targetName = altName;
                  print('Found alternative format: $altName');
                }
              }
              print('Does $targetName exist? $exists');

              if (exists) {
                print('Navigating to existing $targetName');
                _navigateToWeekRoster(targetName);
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
            minimumSize: Size(0, isMobile ? 42 : 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _primaryBlue.withOpacity(0.3)),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 12,
              vertical: isMobile ? 8 : 6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: isMobile ? 16 : 14),
              const SizedBox(width: 4),
              Text(
                '$nextWeekName ►',
                style: TextStyle(fontSize: isMobile ? 13 : 12),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: navRow,
      );
    }

    return navRow;
  }

  // Tips removed per request

  Widget _buildDayHeaders() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final employeeNameWidth = isMobile ? 140.0 : 180.0;
    
    return Container(
      color: _white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
      child: Row(
        children: [
          // Employee name column header
          Container(
            width: employeeNameWidth,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
            child: Text(
              'Staff',
              style: TextStyle(
                fontSize: isMobile ? 12 : 16,
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final bankHoliday =
        date != null ? IrishBankHolidays.getBankHoliday(date) : null;
    final isBankHoliday = bankHoliday != null;

    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
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
            isMobile ? day.substring(0, 2) : day,
            style: TextStyle(
              fontSize: isMobile ? 12 : 16,
              fontWeight: FontWeight.w600,
              color: isBankHoliday ? Colors.red : _primaryBlue,
            ),
          ),
          if (date != null) ...[
            SizedBox(height: isMobile ? 2 : 4),
            Text(
              isMobile 
                ? '${date.day}' // Just day number on mobile
                : '${date.day}${_getOrdinalSuffix(date.day)} ${_getMonthAbbr(date.month)}',
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: isBankHoliday ? Colors.red : _darkGray,
              ),
            ),
            if (isBankHoliday && !isMobile) ...[
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final employeeNameWidth = isMobile ? 140.0 : 180.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 20),
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
            width: employeeNameWidth,
            padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
            child: _buildEmployeeInfo(employee, index),
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

  Widget _buildEmployeeInfo(Employee employee, int index) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final avatarRadius = isMobile ? 12.0 : 12.0;
    final nameFontSize = isMobile ? 12.0 : 14.0;
    final hoursFontSize = isMobile ? 10.0 : 12.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: avatarRadius,
              backgroundColor: _primaryBlue,
              child: Text(
                _displayStaffName(employee.name).isNotEmpty
                    ? _displayStaffName(employee.name)[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: _white,
                  fontSize: isMobile ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _displayStaffName(employee.name),
                    style: TextStyle(
                      fontSize: nameFontSize,
                      fontWeight: FontWeight.w500,
                      color: _darkGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${employee.totalWorkedHours.toStringAsFixed(1)}hrs',
                    style: TextStyle(
                      fontSize: hoursFontSize,
                      color: _darkGray.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (Employee.isWeekStyleRosterName(widget.rosterName))
              SizedBox(
                width: isMobile ? 30 : 24,
                height: isMobile ? 30 : 24,
                child: IconButton(
                  onPressed: index > 0 ? () => _moveStaff(index, index - 1) : null,
                  tooltip: 'Move up',
                  icon: const Icon(Icons.keyboard_arrow_up),
                  iconSize: isMobile ? 18 : 14,
                  padding: EdgeInsets.zero,
                ),
              ),
            if (Employee.isWeekStyleRosterName(widget.rosterName))
              SizedBox(
                width: isMobile ? 30 : 24,
                height: isMobile ? 30 : 24,
                child: IconButton(
                  onPressed: () => _renameStaffMember(employee),
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  iconSize: isMobile ? 16 : 13,
                  padding: EdgeInsets.zero,
                ),
              ),
            if (Employee.isWeekStyleRosterName(widget.rosterName))
              SizedBox(
                width: isMobile ? 30 : 24,
                height: isMobile ? 30 : 24,
                child: IconButton(
                  onPressed: index < _independentEmployees.length - 1
                      ? () => _moveStaff(index, index + 1)
                      : null,
                  tooltip: 'Move down',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  iconSize: isMobile ? 18 : 14,
                  padding: EdgeInsets.zero,
                ),
              ),
            // Larger mobile tap target for delete action
            SizedBox(
              width: isMobile ? 40 : 32,
              height: isMobile ? 40 : 32,
              child: IconButton(
                onPressed: () {
                  print('🗑️ Delete button clicked for ${employee.name}');
                  _showDeleteEmployeeDialog(employee.name);
                },
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove ${employee.name}',
                iconSize: isMobile ? 20 : 16,
                color: Colors.red,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _showEmployeeProfile(employee),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              'View profile',
              style: TextStyle(
                fontSize: isMobile ? 13 : 12,
                color: _primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _moveStaff(int fromIndex, int toIndex) async {
    setState(() {
      final moved = _independentEmployees.removeAt(fromIndex);
      _independentEmployees.insert(toIndex, moved);
      Employee.compactSortIndices(_independentEmployees);
    });
    await _saveCurrentWeekData();
    await _syncStaffOrderAcrossWeekRosters();
  }

  Future<void> _renameStaffMember(Employee employee) async {
    final controller = TextEditingController(text: employee.name);
    final String? updatedName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Staff'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.of(context).pop(controller.text.trim()),
          decoration: const InputDecoration(
            labelText: 'Staff Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final newName = updatedName?.trim() ?? '';
    if (newName.isEmpty || newName == employee.name) return;

    final duplicate = _independentEmployees.any(
      (e) => !identical(e, employee) && e.name.toLowerCase() == newName.toLowerCase(),
    );
    if (duplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Staff member "$newName" already exists'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      final idx = _independentEmployees.indexOf(employee);
      if (idx == -1) return;
      _independentEmployees[idx] = Employee(
        name: newName,
        sortIndex: employee.sortIndex,
        shifts: Map<String, Shift>.from(employee.shifts),
        accumulatedWorkedHours: employee.accumulatedWorkedHours,
        accumulatedTotalHours: employee.accumulatedTotalHours,
        accumulatedHolidayHours: employee.accumulatedHolidayHours,
        accumulatedHolidayHoursUsed: employee.accumulatedHolidayHoursUsed,
        accumulatedHolidayHoursEarned: employee.accumulatedHolidayHoursEarned,
        employeeColor: employee.employeeColor,
        rosterStartDate: employee.rosterStartDate,
        rosterEndDate: employee.rosterEndDate,
        customAccumulatedHours: employee.customAccumulatedHours,
        customHolidayHours: employee.customHolidayHours,
        email: employee.email,
        contractType: employee.contractType,
        contractPdfPath: employee.contractPdfPath,
        contractPdfName: employee.contractPdfName,
        contractPdfBase64: employee.contractPdfBase64,
        documents: List<EmployeeDocument>.from(employee.documents),
      );
    });
    await _saveCurrentWeekData();
  }

  String _displayStaffName(String rawName) {
    final normalized = Employee.normalizeStaffNameForLeadingNumber(rawName);
    return normalized
        .replaceFirst(RegExp(r'^\d+\s*[.\uFF0E\)\u00B7]?\s*'), '')
        .trim();
  }

  /// Keep staff row positioning consistent across all week rosters.
  /// Uses current roster order as the source of truth.
  Future<void> _syncStaffOrderAcrossWeekRosters() async {
    try {
      final desiredOrder = _independentEmployees.map((e) => e.name).toList();
      if (desiredOrder.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final weekRosterNames = <String>{};

      // Include cloud/local roster names from storage service.
      try {
        final names = await RosterStorage.watchRosterNames().first;
        weekRosterNames.addAll(
          names.where((name) => Employee.isWeekStyleRosterName(name)),
        );
      } catch (_) {
        // Fall back to local key scan below.
      }

      // Include any local-only week rosters not currently in the name stream.
      weekRosterNames.addAll(
        prefs
            .getKeys()
            .where((k) => k.startsWith('roster_Week'))
            .map((k) => k.substring('roster_'.length)),
      );

      for (final rosterName in weekRosterNames) {
        try {
          final employees = await RosterStorage.loadRoster(rosterName);
          if (employees.isEmpty) continue;

          final beforeSignature = employees
              .map((e) => '${e.name}\x1f${e.sortIndex}')
              .join('|');

          // Sort by desired order; unknown names keep relative order at the end.
          employees.sort((a, b) {
            final ai = desiredOrder.indexOf(a.name);
            final bi = desiredOrder.indexOf(b.name);
            final aRank = ai == -1 ? desiredOrder.length + a.sortIndex : ai;
            final bRank = bi == -1 ? desiredOrder.length + b.sortIndex : bi;
            return aRank.compareTo(bRank);
          });
          Employee.compactSortIndices(employees);

          final afterSignature = employees
              .map((e) => '${e.name}\x1f${e.sortIndex}')
              .join('|');
          if (afterSignature != beforeSignature) {
            await RosterStorage.saveRoster(rosterName, employees);
          }
        } catch (_) {
          // Skip individual rosters without interrupting user flow.
          continue;
        }
      }
    } catch (e) {
      print('Staff order sync error: $e');
    }
  }

  void _confirmDeleteShift(Employee employee, String day, Shift shift) {
    showDialog(
      context: context,
      builder: (context) => Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                Navigator.of(context).pop();
                _deleteShift(employee, day, shift);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: AlertDialog(
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
          ),
        ),
      ),
    );
  }
  
  // Builds a shift cell, handling both empty cells and populated shifts
  Widget _buildShiftCell(Employee employee, String day, Shift? shift) {
    if (shift != null) {
      return _buildInteractiveShiftCell(employee, day, shift);
    }

    final cellKey = '${employee.name}|$day';
    final isSelected = _selectedCellsForPaste.contains(cellKey);

    // Wrap empty cell in DragTarget to accept dropped shifts
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        final sourceEmployee = data['employee'] as Employee;
        final sourceDay = data['day'] as String;
        final shift = data['shift'] as Shift;
        
        // Move the shift
        _moveShift(sourceEmployee.name, sourceDay, employee.name, day, shift);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragHovering = candidateData.isNotEmpty;
        
        return GestureDetector(
          onTap: () {
            if (_copyModeActive) {
              _toggleCellSelection(employee.name, day);
            } else if (_moveModeActive) {
              _addShiftToCell(employee, day);
            } else {
              _editShift(employee, day, null);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDragHovering
                  ? Colors.green.withOpacity(0.2)
                  : isSelected 
                    ? _primaryBlue.withOpacity(0.2)
                    : _moveModeActive
                      ? Colors.orange.withOpacity(0.05)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDragHovering
                    ? Colors.green
                    : isSelected 
                      ? _primaryBlue 
                      : _moveModeActive 
                        ? Colors.orange.withOpacity(0.4)
                        : _darkGray.withOpacity(0.2),
                width: isDragHovering ? 3 : (isSelected || _moveModeActive ? 2.5 : 0.5),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    _moveModeActive ? Icons.paste : Icons.add_circle,
                    color: _moveModeActive ? Colors.orange : _primaryBlue,
                    size: 24,
                  ),
                ),
            // Show blue dot when in copy mode (visual feedback that this cell can be selected)
            if (_copyModeActive)
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
            // Show outline icon when NOT in copy mode (visual hint for adding shifts)
            if (!_copyModeActive)
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

    // Get context-aware font sizes for mobile
    final baseFontSize = ResponsiveHelper.isMobile(context) ? 10.0 : 12.0;
    final roleFontSize = ResponsiveHelper.isMobile(context) ? 8.0 : 10.0;

    if (shift.isHoliday) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Holiday',
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w500,
                color: _darkGray,
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator,
            size: ResponsiveHelper.isMobile(context) ? 12 : 14,
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
                    fontSize: baseFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.brown[700],
                  ),
                ),
                if (shift.role?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    shift.role!,
                    style: TextStyle(
                      fontSize: roleFontSize,
                      color: Colors.brown[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.drag_indicator,
            size: ResponsiveHelper.isMobile(context) ? 12 : 14,
            color: Colors.brown[600]?.withOpacity(0.6),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Day Off',
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w500,
                color: _darkGray,
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator,
            size: ResponsiveHelper.isMobile(context) ? 12 : 14,
            color: _darkGray.withOpacity(0.6),
          ),
        ],
      );
    }
  }

  // Interactive shift cell with hover effects and quick actions
  Widget _buildInteractiveShiftCell(
      Employee employee, String day, Shift shift) {
    final cellKey = '${employee.name}|$day';
    final isSelected = _selectedCellsForPaste.contains(cellKey);
    final isBeingMoved = _moveModeActive && 
                         _moveSourceEmployee == employee.name && 
                         _moveSourceDay == day;
    
    // Wrap shift cell in DragTarget to accept other shifts dropped on it
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        final sourceEmployee = data['employee'] as Employee;
        final sourceDay = data['day'] as String;
        final draggedShift = data['shift'] as Shift;
        
        // Move the shift
        _moveShift(sourceEmployee.name, sourceDay, employee.name, day, draggedShift);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragHovering = candidateData.isNotEmpty;
        
        return Draggable<Map<String, dynamic>>(
          data: {
            'employee': employee,
            'day': day,
            'shift': shift,
          },
          feedback: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: 0.8,
              child: Container(
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getShiftCellColor(shift),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _primaryBlue, width: 2),
                ),
                child: _buildShiftContent(shift),
              ),
            ),
          ),
          childWhenDragging: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _lightGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _darkGray.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.open_with,
                color: _darkGray.withOpacity(0.5),
                size: 32,
              ),
            ),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    if (_copyModeActive) {
                      _toggleCellSelection(employee.name, day);
                    } else {
                      _editShift(employee, day, shift);
                    }
                  },
                  onLongPress: () => _showQuickActions(context, employee, day, shift),
                  child: Tooltip(
                    message: _copyModeActive 
                        ? 'Click to select for paste' 
                        : isBeingMoved
                          ? 'This shift is cut. Click another cell to move it there.'
                          : 'Click to edit • Drag to move',
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDragHovering
                            ? Colors.green.withOpacity(0.3)
                            : isSelected 
                              ? _primaryBlue.withOpacity(0.3)
                              : isBeingMoved
                                ? Colors.orange.withOpacity(0.2)
                                : _getShiftCellColor(shift),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDragHovering
                              ? Colors.green
                              : isSelected 
                                ? _primaryBlue
                                : isBeingMoved
                                  ? Colors.orange
                                  : _darkGray.withOpacity(0.2),
                          width: isDragHovering ? 3 : (isSelected || isBeingMoved ? 2.5 : 0.5),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Opacity(
                            opacity: isBeingMoved ? 0.5 : 1.0,
                            child: _buildShiftContent(shift),
                          ),
                          // Show "CUT" indicator when being moved
                          if (isBeingMoved)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CUT',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          // Quick action buttons on hover (desktop) or always visible (mobile)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildQuickActionButton(
                                  icon: Icons.content_copy,
                                  onTap: () => _activateCopyMode(shift),
                                  tooltip: 'Quick Copy',
                                ),
                                SizedBox(width: ResponsiveHelper.isMobile(context) ? 6 : 2),
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
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
    bool isDestructive = false,
  }) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final iconSize = isMobile ? 18.0 : 12.0;
    final tapSize = isMobile ? 38.0 : 18.0;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: tapSize,
          height: tapSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : _primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isMobile ? 10 : 4),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: isDestructive ? Colors.red : _primaryBlue,
          ),
        ),
      ),
    );
  }

  void _showQuickActions(
      BuildContext context, Employee employee, String day, Shift shift) {
    final isMobile = ResponsiveHelper.isMobile(context);

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: _primaryBlue),
                title: const Text('Edit shift'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _editShift(employee, day, shift);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: _primaryBlue),
                title: const Text('Copy shift'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _copyShiftToClipboard(employee, day, shift);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut, color: Colors.orange),
                title: const Text('Move shift', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cutShiftForMove(employee, day);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete shift', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDeleteShift(employee, day, shift);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      return;
    }

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
              Icon(Icons.content_cut, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              const Text('Move', style: TextStyle(color: Colors.orange)),
            ],
          ),
          onTap: () => _cutShiftForMove(employee, day),
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

  void _cutShiftForMove(Employee employee, String day) {
    setState(() {
      _moveModeActive = true;
      _moveSourceEmployee = employee.name;
      _moveSourceDay = day;
      _clipboardShift = employee.shifts[day]; // Store reference to the shift
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.content_cut, color: Colors.orange, size: 16),
            ),
            const SizedBox(width: 12),
            Text(
              'Shift cut. Click any cell to move it there.',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Cancel',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _moveModeActive = false;
              _moveSourceEmployee = null;
              _moveSourceDay = null;
              _clipboardShift = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _addShiftToCell(Employee employee, String day) async {
    if (_moveModeActive && _moveSourceEmployee != null && _moveSourceDay != null && _clipboardShift != null) {
      // Move mode: move shift from source to target
      final employeeList = _getEmployeeList();
      final sourceEmployee = employeeList.firstWhere((e) => e.name == _moveSourceEmployee);
      
      setState(() {
        // Remove shift from source
        sourceEmployee.shifts.remove(_moveSourceDay);
        
        // Add shift to target (create deep copy to avoid reference issues)
        final shiftJson = _clipboardShift!.toJson();
        final newShift = Shift.fromJson(shiftJson);
        employee.shifts[day] = newShift;
        
        // Clear move mode state
        _moveModeActive = false;
        _moveSourceEmployee = null;
        _moveSourceDay = null;
        _clipboardShift = null;
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
                child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Moved shift to ${employee.name} ($day)',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (_hasClipboard()) {
      // Copy mode: paste from clipboard
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

  // Quick Copy Mode Methods
  void _activateCopyMode(Shift shift) {
    setState(() {
      _copyModeActive = true;
      _copiedShift = Shift.fromJson(shift.toJson()); // Deep copy
      _selectedCellsForPaste.clear();
    });
  }

  void _toggleCellSelection(String employeeName, String day) {
    setState(() {
      final cellKey = '$employeeName|$day';
      if (_selectedCellsForPaste.contains(cellKey)) {
        _selectedCellsForPaste.remove(cellKey);
      } else {
        _selectedCellsForPaste.add(cellKey);
      }
    });
  }

  void _cancelCopyMode() {
    setState(() {
      _copyModeActive = false;
      _copiedShift = null;
      _selectedCellsForPaste.clear();
    });
  }

  Future<void> _applyCopyMode() async {
    if (_copiedShift == null || _selectedCellsForPaste.isEmpty) return;

    final employeeList = _getEmployeeList();
    int appliedCount = 0;
    // int skippedCount = 0; // no longer used

    setState(() {
      for (final cellKey in _selectedCellsForPaste) {
        final parts = cellKey.split('|');
        if (parts.length != 2) continue;
        
        final employeeName = parts[0];
        final day = parts[1];
        
        final employee = employeeList.firstWhere(
          (e) => e.name == employeeName,
          orElse: () => employeeList.first,
        );
        
        if (employee.name == employeeName) {
          // Create deep copy of the shift
          final shiftCopy = Shift.fromJson(_copiedShift!.toJson());
          employee.shifts[day] = shiftCopy;
          appliedCount++;
        }
      }
      
      // Reset copy mode
      _copyModeActive = false;
      _copiedShift = null;
      _selectedCellsForPaste.clear();
    });

    // Save and notify
    _saveCurrentWeekData();
    widget.onRosterChanged(employeeList);
    _notifyCurrentWeekDataChanged();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('Applied shift to $appliedCount cell${appliedCount != 1 ? 's' : ''}'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        Employee.isWeekStyleRosterName(widget.rosterName);
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
      builder: (context) => Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                Navigator.of(context).pop();
                _copyEntireRoster(newWeekKey, currentWeekShifts);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: AlertDialog(
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
          ),
        ),
      ),
    );
  }

  // Create fresh roster with only staff names (no shifts)
  void _createFreshRoster(String newWeekKey) async {
    print('🧹 Creating fresh roster for week: $newWeekKey');

    try {
      // CRITICAL: Save current roster first to ensure accumulated values are up-to-date
      await _saveToRosterStorage();
      print('💾 Saved current roster before creating new week');
      
      // Parse the correct dates for the new week
      DateTime mondayDate;
      DateTime sundayDate;
      
      final weekMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(newWeekKey);
      if (weekMatch != null) {
        final weekNumber = int.tryParse(weekMatch.group(1)!);
        if (weekNumber != null && weekNumber >= 1 && weekNumber <= 53) {
          // Infer year based on current roster dates to handle year rollover
          int year;
          final employeeList = _getEmployeeList();
          if (employeeList.isNotEmpty && employeeList.first.rosterStartDate != null) {
            final existingDate = employeeList.first.rosterStartDate!;
            year = existingDate.year;
            // If creating an early week (1-10) while current roster is in late year (Nov-Dec), move to next year
            if (weekNumber <= 10 && existingDate.month >= 11) {
              year = existingDate.year + 1;
              print('🔄 Year rollover detected: assigning $year for week $weekNumber');
            }
          } else {
            year = TimeService.nowSync().year;
          }
          
          // Find January 4th of the year (which is always in week 1)
          final jan4 = DateTime(year, 1, 4);
          // Find Monday of week 1 (Monday of the week containing January 4th)
          final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
          // Calculate the Monday of the target week
          mondayDate = week1Monday.add(Duration(days: (weekNumber - 1) * 7));
          sundayDate = mondayDate.add(Duration(days: 6));
          
          print('🔍 Calculated dates for fresh $newWeekKey: ${mondayDate.toIso8601String().split('T')[0]} to ${sundayDate.toIso8601String().split('T')[0]}');
        } else {
          // Fallback to current week if parsing fails
          final now = TimeService.nowSync();
          mondayDate = now.subtract(Duration(days: now.weekday - 1));
          sundayDate = mondayDate.add(Duration(days: 6));
          print('⚠️ Using fallback dates for fresh $newWeekKey');
        }
      } else {
        // Fallback to current week if no week number found
        final now = TimeService.nowSync();
        mondayDate = now.subtract(Duration(days: now.weekday - 1));
        sundayDate = mondayDate.add(Duration(days: 6));
        print('⚠️ Using fallback dates for fresh $newWeekKey (no week number)');
      }

      // Create new employees with only names (no shifts)
      final newEmployees = <Employee>[];
      final employeeList = _getEmployeeList();
      for (final employee in employeeList) {
        // Carry-forward accumulated values to next week (respect custom overrides)
        final baseAccumWorked = employee.customAccumulatedHours ?? employee.accumulatedWorkedHours;
        // Include both worked hours AND holiday hours (paid time off) in accumulation
        final carryAccumWorked = baseAccumWorked + employee.totalWorkedHours + employee.totalHolidayHoursUsed;
        final carryAccumTotal = baseAccumWorked + employee.totalWorkedHours + employee.totalHolidayHoursUsed;
        
        // Accumulate holiday hours used across weeks
        final carryAccumHolidayUsed = employee.accumulatedHolidayHoursUsed + employee.totalHolidayHoursUsed;
        
        // Accumulate holiday hours earned across weeks (8% of paid hours)
        final carryAccumHolidayEarned = employee.accumulatedHolidayHoursEarned + employee.holidayHoursEarnedThisWeek;
        
        // Validation: Accumulated hours should never decrease
        if (carryAccumWorked < baseAccumWorked) {
          print('⚠️ WARNING: ${employee.name} accumulated hours would decrease from $baseAccumWorked to $carryAccumWorked');
        }
        
        // Holiday hours: Simple formula - start with current balance, add earned, subtract used
        // accumulatedHolidayHours is the *remaining* available balance from previous week
        // Include customHolidayHours adjustment if set (it's an additive bonus)
        final baseHolidayBalance = employee.accumulatedHolidayHours + (employee.customHolidayHours ?? 0.0);
        final carryHoliday = (baseHolidayBalance + employee.holidayHoursEarnedThisWeek - employee.totalHolidayHoursUsed).clamp(0.0, double.infinity);

        final newEmployee = Employee(
          name: employee.name,
          sortIndex: employee.sortIndex, // Preserve insertion order
          shifts: <String, Shift>{}, // Empty shifts
          accumulatedWorkedHours: carryAccumWorked,
          accumulatedTotalHours: carryAccumTotal,
          accumulatedHolidayHours: carryHoliday, // Starting balance + earned - used
          accumulatedHolidayHoursUsed: carryAccumHolidayUsed, // Cumulative holiday hours used
          accumulatedHolidayHoursEarned: carryAccumHolidayEarned, // Cumulative holiday hours earned
          employeeColor: employee.employeeColor,
          rosterStartDate: mondayDate,
          rosterEndDate: sundayDate,
          // Carry forward custom accumulated hours with this week's work added
          customAccumulatedHours: carryAccumWorked,
          // Clear custom holiday to allow automatic earning in future weeks
          customHolidayHours: null,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      // CRITICAL: Save current roster first to ensure accumulated values are up-to-date
      await _saveToRosterStorage();
      print('💾 Saved current roster before copying');
      
      // Parse the correct dates for the new week
      DateTime? mondayDate;
      DateTime? sundayDate;
      
      final weekMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(newWeekKey);
      if (weekMatch != null) {
        final weekNumber = int.tryParse(weekMatch.group(1)!);
        if (weekNumber != null && weekNumber >= 1 && weekNumber <= 53) {
          // Infer year based on current roster dates to handle year rollover
          int year;
          final employeeList = _getEmployeeList();
          if (employeeList.isNotEmpty && employeeList.first.rosterStartDate != null) {
            final existingDate = employeeList.first.rosterStartDate!;
            year = existingDate.year;
            // If creating an early week (1-10) while current roster is in late year (Nov-Dec), move to next year
            if (weekNumber <= 10 && existingDate.month >= 11) {
              year = existingDate.year + 1;
              print('🔄 Year rollover detected: assigning $year for week $weekNumber');
            }
          } else {
            year = TimeService.nowSync().year;
          }
          
          // Find January 4th of the year (which is always in week 1)
          final jan4 = DateTime(year, 1, 4);
          // Find Monday of week 1 (Monday of the week containing January 4th)
          final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
          // Calculate the Monday of the target week
          mondayDate = week1Monday.add(Duration(days: (weekNumber - 1) * 7));
          sundayDate = mondayDate.add(Duration(days: 6));
          
          print('🔍 Calculated dates for $newWeekKey: ${mondayDate.toIso8601String().split('T')[0]} to ${sundayDate.toIso8601String().split('T')[0]}');
        }
      }
      
      // Fallback to current week if parsing fails
      if (mondayDate == null || sundayDate == null) {
        final now = TimeService.nowSync();
        mondayDate = now.subtract(Duration(days: now.weekday - 1));
        sundayDate = mondayDate.add(Duration(days: 6));
        print('⚠️ Using fallback dates for $newWeekKey');
      }

      // Create new employees with copied shifts
      final newEmployees = <Employee>[];
      final employeeList = _getEmployeeList();

      for (final employee in employeeList) {
        final employeeShifts =
            currentWeekShifts[employee.name] ?? <String, Shift>{};

        // Carry-forward accumulated values to next week (respect custom overrides)
        final baseAccumWorked = employee.customAccumulatedHours ?? employee.accumulatedWorkedHours;
        // Include both worked hours AND holiday hours (paid time off) in accumulation
        final carryAccumWorked = baseAccumWorked + employee.totalWorkedHours + employee.totalHolidayHoursUsed;
        final carryAccumTotal = baseAccumWorked + employee.totalWorkedHours + employee.totalHolidayHoursUsed;
        
        // Accumulate holiday hours used across weeks
        final carryAccumHolidayUsed = employee.accumulatedHolidayHoursUsed + employee.totalHolidayHoursUsed;
        
        // Accumulate holiday hours earned across weeks (8% of paid hours)
        final carryAccumHolidayEarned = employee.accumulatedHolidayHoursEarned + employee.holidayHoursEarnedThisWeek;
        
        // Validation: Accumulated hours should never decrease
        if (carryAccumWorked < baseAccumWorked) {
          print('⚠️ WARNING: ${employee.name} accumulated hours would decrease from $baseAccumWorked to $carryAccumWorked');
        }
        
        // Holiday hours: Simple formula - start with current balance, add earned, subtract used
        // accumulatedHolidayHours is the *remaining* available balance from previous week
        // Include customHolidayHours adjustment if set (it's an additive bonus)
        final baseHolidayBalance = employee.accumulatedHolidayHours + (employee.customHolidayHours ?? 0.0);
        final carryHoliday = (baseHolidayBalance + employee.holidayHoursEarnedThisWeek - employee.totalHolidayHoursUsed).clamp(0.0, double.infinity);

        final newEmployee = Employee(
          name: employee.name,
          sortIndex: employee.sortIndex, // Preserve insertion order
          shifts: Map<String, Shift>.from(employeeShifts), // Copy all shifts
          accumulatedWorkedHours: carryAccumWorked,
          accumulatedTotalHours: carryAccumTotal,
          accumulatedHolidayHours: carryHoliday, // Starting balance + earned - used
          accumulatedHolidayHoursUsed: carryAccumHolidayUsed, // Cumulative holiday hours used
          accumulatedHolidayHoursEarned: carryAccumHolidayEarned, // Cumulative holiday hours earned
          employeeColor: employee.employeeColor,
          rosterStartDate: mondayDate,
          rosterEndDate: sundayDate,
          // Carry forward custom accumulated hours with this week's work added
          customAccumulatedHours: carryAccumWorked,
          // Clear custom holiday to allow automatic earning in future weeks
          customHolidayHours: null,
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
        Employee.isWeekStyleRosterName(widget.rosterName);
    if (isWeekSpecificRoster) {
      // Removed emoji print statement
      return;
    }

    // Save current week's data before navigation
    _saveCurrentWeekData();

    final now = TimeService.nowSync();
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
    // Unlock orientation to allow portrait for comfortable editing
    await OrientationService.unlockOrientation();
    
    final editedShift = await widget.onEdit(context, shift);
    
    // Lock back to landscape after dialog closes
    await OrientationService.lockToLandscape();
    
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
    // Unlock orientation to allow portrait for comfortable viewing/editing
    OrientationService.unlockOrientation();
    
    showDialog(
      context: context,
      builder: (context) => EmployeeProfileDialog(
        employee: employee,
        weekDates: widget.weekDates,
        onEmployeeUpdated: () {
          setState(() {});
          _saveCurrentWeekData();
          final employeeList = _getEmployeeList();
          widget.onRosterChanged(employeeList);
          _notifyCurrentWeekDataChanged();
        },
      ),
    ).then((_) {
      // Lock back to landscape when dialog closes
      OrientationService.lockToLandscape();
    });
  }

  void _navigateToWeekRoster(String rosterName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RosterPage(rosterName: rosterName)),
    );
  }

  // Get alternative week name format (toggle between with/without year)
  String _getAlternativeWeekName(String weekName, int year) {
    final match = RegExp(r'Week (\d+)(?: (\d{4}))?').firstMatch(weekName);
    if (match == null) return weekName;
    
    final weekNum = match.group(1)!;
    final hasYear = match.group(2) != null;
    
    // If it has year, return without year; if no year, return with year
    return hasYear ? 'Week $weekNum' : 'Week $weekNum $year';
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
                _removeStaffMember(employeeName, false);
              },
              child: Text('Current Week Only'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close delete dialog
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
        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
            LogicalKeySet(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (intent) {
                  _addStaffMember(nameController.text.trim());
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: AlertDialog(
          title: Text('Add Staff Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addStaffMember(nameController.text.trim()),
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
              ),
            ),
          ),
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
        // Add with sortIndex = current length (so it goes to the end)
        _independentEmployees.add(Employee(
          name: name,
          sortIndex: _independentEmployees.length,
        ));
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
    try {
      setState(() {
        _independentEmployees.removeWhere((emp) => emp.name == name);
        Employee.compactSortIndices(_independentEmployees);
        print('Staff Management: Removed "$name" from ${widget.rosterName}');
        print(
            'Staff Management: Current staff count: ${_independentEmployees.length}');
      });

      // Save current week
      await _saveCurrentWeekData();

      if (removeFromFuture) {
        await _removeStaffFromFutureWeeks(name);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(removeFromFuture
                ? 'Removed "$name" from current and all future weeks'
                : 'Removed "$name" from ${widget.rosterName} only'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error removing staff member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing staff member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

                // Remove the employee and close gaps in numbering (sortIndex)
                employees.removeWhere((emp) => emp.name == name);
                Employee.compactSortIndices(employees);
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

  Widget _buildCopyModeActionBar() {
    return Positioned(
      top: 20,
      right: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.content_copy, color: _primaryBlue, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_selectedCellsForPaste.length} selected',
                  style: TextStyle(
                    color: _darkGray,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: _cancelCopyMode,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.close, size: 20, color: Colors.red.shade600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Apply button
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: _selectedCellsForPaste.isEmpty ? null : _applyCopyMode,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _selectedCellsForPaste.isEmpty 
                      ? Colors.grey.shade300 
                      : Colors.green.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.check, 
                  size: 20, 
                  color: _selectedCellsForPaste.isEmpty 
                      ? Colors.grey.shade500 
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
