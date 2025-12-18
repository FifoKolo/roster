import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import '../models/employee_model.dart';
import '../services/roster_storage.dart';
import '../services/pdf_service.dart';
import '../widgets/modern_roster_table.dart';
import '../widgets/add_shift_dialog.dart';
import '../widgets/global_salary_settings_dialog.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_theme.dart';

/// A responsive wrapper for the roster page that adapts to mobile devices
class RosterPage extends StatefulWidget {
  final String rosterName;

  const RosterPage({
    super.key,
    required this.rosterName,
  });

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  List<Employee> employees = [];
  Map<String, DateTime> weekDates = {};
  bool isLoading = true;
  
  // Current week's data for PDF generation
  List<Employee> currentWeekEmployees = [];
  DateTime currentWeekDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRosterData();
    _initWeekDates();
  }

  Future<void> _loadRosterData() async {
    try {
      final loadedEmployees = await RosterStorage.loadRoster(widget.rosterName);
      
      // Fix incorrect dates for week-specific rosters
      var correctedEmployees = _fixWeekDatesIfNeeded(loadedEmployees);
      
      // Fix missing accumulated values from previous week
      correctedEmployees = await _fixMissingAccumulatedValues(correctedEmployees);
      
      setState(() {
        employees = correctedEmployees;
        isLoading = false;
        _updateWeekDatesFromRoster(correctedEmployees);
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading roster: $e')),
        );
      }
    }
  }

  List<Employee> _fixWeekDatesIfNeeded(List<Employee> employees) {
    // Check if this is a week-specific roster
    final weekMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(widget.rosterName);
    if (weekMatch == null || employees.isEmpty) {
      return employees;
    }

    var weekNumber = int.tryParse(weekMatch.group(1)!);
    if (weekNumber == null || weekNumber < 1) {
      return employees;
    }

    // Calculate what the correct dates should be for this week number
    // Infer year from stored dates if available, otherwise use current year
    int year = DateTime.now().year;
    
    // Handle weeks > 53 by wrapping to next year
    // Week 54 = Week 1 of next year, Week 55 = Week 2 of next year, etc.
    if (weekNumber > 53) {
      year = year + 1;
      weekNumber = weekNumber - 52; // Adjust to valid week number for next year
      if (weekNumber > 53) weekNumber = 1; // Safety
    }
    
    // If employees have stored dates, try to infer the intended year from them
    if (employees.isNotEmpty && employees.first.rosterStartDate != null) {
      final storedDate = employees.first.rosterStartDate!;
      // Check if the stored date's week number matches our expected week
      final storedWeekDate = DateTime(storedDate.year, 1, 4);
      final storedWeek1Monday = storedWeekDate.subtract(Duration(days: storedWeekDate.weekday - 1));
      final storedWeekMonday = storedWeek1Monday.add(Duration(days: (weekNumber - 1) * 7));
      
      // If stored date is close to where it should be for this week/year, use stored year
      if (storedDate.difference(storedWeekMonday).inDays.abs() < 7) {
        year = storedDate.year;
      } else if (weekNumber <= 4) {
        // Early weeks might belong to previous year in ISO calendar
        // Check if January dates would make sense
        final jan1 = DateTime(year, 1, 1);
        if (jan1.weekday > 4) {
          // If Jan 1 is Thu+ (Thu/Fri/Sat/Sun), week 1 starts in December previous year
          year = year - 1;
        }
      }
    } else if (weekNumber <= 4) {
      // No stored dates; check if early weeks should be previous year
      final jan1 = DateTime(year, 1, 1);
      if (jan1.weekday > 4) {
        year = year - 1;
      }
    }
    
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final correctMonday = week1Monday.add(Duration(days: (weekNumber - 1) * 7));
    final correctSunday = correctMonday.add(Duration(days: 6));

    // Check if the stored dates are incorrect
    final storedMonday = employees.first.rosterStartDate;
    if (storedMonday != null && storedMonday.difference(correctMonday).inDays.abs() > 0) {
      print('🔧 Fixing incorrect dates for ${widget.rosterName} (Week $weekNumber, Year $year)');
      print('   Old: ${storedMonday.toIso8601String().split('T')[0]}');
      print('   New: ${correctMonday.toIso8601String().split('T')[0]}');
      
      final fixedEmployees = employees.map((emp) => Employee(
        name: emp.name,
        shifts: emp.shifts,
        accumulatedWorkedHours: emp.accumulatedWorkedHours,
        accumulatedTotalHours: emp.accumulatedTotalHours,
        accumulatedHolidayHours: emp.accumulatedHolidayHours,
        employeeColor: emp.employeeColor,
        rosterStartDate: correctMonday,
        rosterEndDate: correctSunday,
        customAccumulatedHours: emp.customAccumulatedHours,
        customHolidayHours: emp.customHolidayHours,
      )).toList();
      
      // Save the corrected dates back to storage
      RosterStorage.saveRoster(widget.rosterName, fixedEmployees);
      
      return fixedEmployees;
    }

    return employees;
  }

  Future<List<Employee>> _fixMissingAccumulatedValues(List<Employee> employees) async {
    // Check if this is a week-specific roster
    final weekMatch = RegExp(r'Week\s+(\d+)', caseSensitive: false).firstMatch(widget.rosterName);
    if (weekMatch == null || employees.isEmpty) {
      return employees;
    }

    final currentWeekNumber = int.tryParse(weekMatch.group(1)!);
    if (currentWeekNumber == null || currentWeekNumber <= 1) {
      return employees; // No previous week to check
    }

    // Check if any employee has suspiciously low accumulated values (all zeros)
    final hasZeroAccumulated = employees.any((emp) => 
      emp.accumulatedWorkedHours == 0 && 
      emp.accumulatedTotalHours == 0 && 
      emp.accumulatedHolidayHours == 0
    );

    if (!hasZeroAccumulated) {
      return employees; // Values look fine
    }

    // Try to load previous week to get accumulated values (avoid waiting on streams)
    try {
      final prevWeekNumber = currentWeekNumber - 1;
      final prevWeekName = 'Week $prevWeekNumber';
      print('🔍 Attempting previous-week restore from $prevWeekName');
      final prevWeekEmployees = await RosterStorage.loadRoster(prevWeekName);
      
      if (prevWeekEmployees.isNotEmpty) {
        print('🔍 Detected missing accumulated values, loaded ${prevWeekEmployees.length} employees from $prevWeekName');
        
        // Create a map of previous week's accumulated values
        final prevAccumulated = <String, Map<String, double>>{};
        for (final prevEmp in prevWeekEmployees) {
          prevAccumulated[prevEmp.name] = {
            'worked': prevEmp.accumulatedWorkedHours,
            'total': prevEmp.accumulatedTotalHours,
            'holiday': prevEmp.accumulatedHolidayHours,
          };
        }
        
        // Update employees with accumulated values from previous week
        final fixedEmployees = employees.map((emp) {
          final prevValues = prevAccumulated[emp.name];
          if (prevValues != null && emp.accumulatedWorkedHours == 0) {
            print('  ✅ Restored accumulated values for ${emp.name}');
            return Employee(
              name: emp.name,
              shifts: emp.shifts,
              accumulatedWorkedHours: prevValues['worked']!,
              accumulatedTotalHours: prevValues['total']!,
              accumulatedHolidayHours: prevValues['holiday']!,
              employeeColor: emp.employeeColor,
              rosterStartDate: emp.rosterStartDate,
              rosterEndDate: emp.rosterEndDate,
            );
          }
          return emp;
        }).toList();
        
        // Save the fixed values back to storage
        await RosterStorage.saveRoster(widget.rosterName, fixedEmployees);
        print('💾 Saved restored accumulated values to ${widget.rosterName}');
        
        return fixedEmployees;
      }
    } catch (e) {
      print('⚠️ Could not restore accumulated values from previous week: $e');
    }

    return employees;
  }

  void _updateWeekDatesFromRoster(List<Employee> employees) {
    // Get the week dates from the first employee (all should have the same dates)
    if (employees.isNotEmpty && 
        employees.first.rosterStartDate != null && 
        employees.first.rosterEndDate != null) {
      final monday = employees.first.rosterStartDate!;
      print('📅 RosterPage: Updating week dates from employee data - Monday: ${monday.toIso8601String().split('T')[0]}');
      for (int i = 0; i < 7; i++) {
        final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        weekDates[dayNames[i]] = monday.add(Duration(days: i));
        print('  ${dayNames[i]}: ${weekDates[dayNames[i]]!.toIso8601String().split('T')[0]}');
      }
    } else {
      // Fallback to current week if no dates stored
      print('⚠️ RosterPage: No dates in employee data, using current week fallback');
      _initWeekDates();
    }
  }

  void _initWeekDates() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      weekDates[dayNames[i]] = monday.add(Duration(days: i));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // Handle keyboard properly
      appBar: _buildAppBar(),
      body: isLoading ? _buildLoadingView() : _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final appBarHeight = ResponsiveHelper.getResponsiveAppBarHeight(context);
    
    return PreferredSize(
      preferredSize: Size.fromHeight(appBarHeight),
      child: AppBar(
        title: Text(
          widget.rosterName,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 4,
        actions: _buildAppBarActions(),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        toolbarHeight: appBarHeight,
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    // Show schedule menu and settings for all devices
    return [
      // Settings
      IconButton(
        icon: Icon(
          Icons.settings,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        onPressed: () => _handleMenuAction('settings'),
        tooltip: 'Settings',
      ),
      // Schedule/PDF Menu
      PopupMenuButton<String>(
        icon: Icon(
          Icons.calendar_month,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        tooltip: 'Schedule Options',
        onSelected: (String value) {
          if (value == 'preview_public') {
            _previewPublicPdf(employees);
          } else if (value == 'download_public') {
            _exportPublicPdf(employees);
          } else if (value == 'preview_private') {
            _previewPrivatePdf(employees);
          } else if (value == 'download_private') {
            _exportPrivatePdf(employees);
          }
        },
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
            value: 'preview_public',
            child: Row(
              children: [
                Icon(Icons.visibility, size: 20, color: Colors.blue),
                SizedBox(width: 12),
                Text('Preview Staff Schedule'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'download_public',
            child: Row(
              children: [
                Icon(Icons.download, size: 20, color: Colors.green),
                SizedBox(width: 12),
                Text('Download Staff Schedule'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'preview_private',
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 20, color: Colors.orange),
                SizedBox(width: 12),
                Text('Preview Management Report'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'download_private',
            child: Row(
              children: [
                Icon(Icons.file_download, size: 20, color: Colors.deepOrange),
                SizedBox(width: 12),
                Text('Download Management Report'),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading roster...',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // Use the same layout for all devices - full roster table with scrolling
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicWidth(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: _buildOriginalTable(),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWeekHeader() {
    final firstDate = weekDates['Mon'] ?? DateTime.now();
    final lastDate = weekDates['Sun'] ?? DateTime.now();
    
    return Container(
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
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.blue.shade700,
                  size: ResponsiveHelper.getResponsiveIconSize(context, 20),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Week Period',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatDate(firstDate)} - ${_formatDate(lastDate)}',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getWeekDescription(firstDate),
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              color: Colors.blue.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOriginalTable() {
    return ModernRosterTable(
      key: ValueKey(widget.rosterName), // Force rebuild when roster changes
      employees: employees,
      weekDates: weekDates,
      rosterName: widget.rosterName,
      onEdit: _showAddShiftDialog,
      onRosterChanged: _updateRoster,
      onCurrentWeekDataChanged: _onCurrentWeekDataChanged,
      onAddStaff: _addStaff,
    );
  }

  // Callback to receive current week data from ModernRosterTable
  void _onCurrentWeekDataChanged(List<Employee> weekEmployees, DateTime weekDate) {
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

  Widget _buildFloatingActionButton() {
    final fabSize = ResponsiveHelper.getResponsiveFABSize(context);
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return SizedBox(
      width: fabSize,
      height: fabSize,
      child: FloatingActionButton(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: isMobile ? 6 : 8,
        tooltip: 'Add Staff Member',
        onPressed: _addStaff,
        child: Icon(
          Icons.add,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
      ),
    );
  }

  Future<void> _addStaff() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _AddStaffDialog(),
    );

    if (result != null && result.isNotEmpty) {
      // Prevent duplicate staff names (case-insensitive)
      final exists = employees.any((e) => e.name.trim().toLowerCase() == result.trim().toLowerCase());
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staff member "$result" already exists'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final newEmployee = Employee(
        name: result,
        rosterStartDate: weekDates['Mon'],
        rosterEndDate: weekDates['Sun'],
      );

      setState(() {
        employees.add(newEmployee);
      });

      await RosterStorage.saveRoster(widget.rosterName, employees);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added staff member: $result'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  // ignore: unused_element
  Future<void> _deleteEmployee(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: AppTheme.dangerButtonStyle,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        employees.removeWhere((e) => e.name == employee.name);
      });
      await RosterStorage.saveRoster(widget.rosterName, employees);
    }
  }

  // ignore: unused_element
  void _handleShiftTap(BuildContext context, Employee employee, String day) async {
    final currentShift = employee.shifts[day];
    final result = await _showAddShiftDialog(context, currentShift);
    
    if (result != null) {
      setState(() {
        employee.shifts[day] = result;
        employee.calculateHours(); // Recalculate hours after shift change
      });
      await RosterStorage.saveRoster(widget.rosterName, employees);
    }
  }

  Future<Shift?> _showAddShiftDialog(BuildContext context, Shift? currentShift) async {
    final result = await showDialog<Shift>(
      context: context,
      builder: (context) => AddShiftDialog(shift: currentShift),
    );
    return result;
  }

  Future<void> _updateRoster(List<Employee> updatedEmployees) async {
    setState(() {
      employees = updatedEmployees;
    });
    await RosterStorage.saveRoster(widget.rosterName, employees);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'settings':
        _openGlobalSalarySettings();
        break;
    }
  }

  Future<void> _previewPublicPdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;

    print('📄 Previewing Public PDF with ${employeesToUse.length} employees');
    
    try {
      final pdfBytes = await PdfService.buildPublicRosterPdf(
        employeesToUse, 
        weekDates,
      );
      
      _showPdfPreviewDialog(pdfBytes, 'Staff Schedule Preview', false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating preview: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _previewPrivatePdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;

    print('📄 Previewing Private PDF with ${employeesToUse.length} employees');
    
    try {
      final pdfBytes = await PdfService.buildPrivateRosterPdf(
        employeesToUse, 
        weekDates,
      );
      
      _showPdfPreviewDialog(pdfBytes, 'Management Report Preview', true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating preview: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPdfPreviewDialog(Uint8List pdfBytes, String title, bool isPrivate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      isPrivate ? Icons.admin_panel_settings : Icons.schedule,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 16),
                // PDF Preview
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: PdfPreview(
                      build: (format) => pdfBytes,
                      canChangePageFormat: false,
                      canDebug: false,
                      initialPageFormat: PdfPageFormat.a4,
                      pdfFileName: "${title.replaceAll(' ', '_')}.pdf",
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        // Download the PDF
                        final employeeList = currentWeekEmployees.isNotEmpty 
                            ? currentWeekEmployees 
                            : employees;
                        if (isPrivate) {
                          _exportPrivatePdf(employeeList);
                        } else {
                          _exportPublicPdf(employeeList);
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPublicPdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;
    await PdfService.sharePublicRosterPdf(context, employeesToUse, weekDates);
  }

  Future<void> _exportPrivatePdf(List<Employee> fallbackEmployees) async {
    // Use current week's data if available, otherwise fallback to state employees
    final employeesToUse = currentWeekEmployees.isNotEmpty ? currentWeekEmployees : fallbackEmployees;
    await PdfService.sharePrivateRosterPdf(context, employeesToUse, weekDates);
  }

  Future<void> _openGlobalSalarySettings() async {
    await showDialog(
      context: context,
      builder: (context) => const GlobalSalarySettingsDialog(),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getWeekDescription(DateTime monday) {
    final now = DateTime.now();
    final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
    
    if (_isSameWeek(monday, currentWeekStart)) {
      return 'Current Week';
    } else if (monday.isBefore(currentWeekStart)) {
      final weeksAgo = ((currentWeekStart.difference(monday).inDays) / 7).ceil();
      return '$weeksAgo week${weeksAgo == 1 ? '' : 's'} ago';
    } else {
      final daysAhead = monday.difference(currentWeekStart).inDays;
      if (daysAhead == 7) {
        return 'Next Week';
      }
      final weeksAhead = (daysAhead / 7).ceil();
      return 'In $weeksAhead week${weeksAhead == 1 ? '' : 's'}';
    }
  }

  bool _isSameWeek(DateTime a, DateTime b) {
    return a.year == b.year &&
           a.month == b.month &&
           a.day == b.day;
  }
}

class _AddStaffDialog extends StatefulWidget {
  @override
  _AddStaffDialogState createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final dialogWidth = ResponsiveHelper.getResponsiveDialogWidth(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: dialogWidth,
        padding: ResponsiveHelper.getResponsivePadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Staff Member',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Staff Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: AppTheme.primaryButtonStyle,
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      Navigator.of(context).pop(name);
                    }
                  },
                  child: Text(
                    'Add',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}