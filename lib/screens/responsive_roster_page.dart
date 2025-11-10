import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/roster_storage.dart';
import '../widgets/modern_roster_table.dart';
import '../widgets/responsive_roster_table.dart';
import '../widgets/add_shift_dialog.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_theme.dart';

/// A responsive wrapper for the roster page that adapts to mobile devices
class ResponsiveRosterPage extends StatefulWidget {
  final String rosterName;

  const ResponsiveRosterPage({
    Key? key,
    required this.rosterName,
  }) : super(key: key);

  @override
  State<ResponsiveRosterPage> createState() => _ResponsiveRosterPageState();
}

class _ResponsiveRosterPageState extends State<ResponsiveRosterPage> {
  List<Employee> employees = [];
  Map<String, DateTime> weekDates = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRosterData();
    _initWeekDates();
  }

  Future<void> _loadRosterData() async {
    try {
      final loadedEmployees = await RosterStorage.loadRoster(widget.rosterName);
      setState(() {
        employees = loadedEmployees;
        isLoading = false;
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
    final isMobile = ResponsiveHelper.isMobile(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    if (isMobile && isLandscape) {
      // Show minimal actions in mobile landscape
      return [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Colors.white,
            size: ResponsiveHelper.getResponsiveIconSize(context, 24),
          ),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Export'),
                ],
              ),
            ),
          ],
        ),
      ];
    }
    
    // Full actions for other layouts
    return [
      IconButton(
        icon: Icon(
          Icons.settings,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        onPressed: () => _handleMenuAction('settings'),
        tooltip: 'Settings',
      ),
      IconButton(
        icon: Icon(
          Icons.download,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        onPressed: () => _handleMenuAction('export'),
        tooltip: 'Export',
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
    final isMobile = ResponsiveHelper.isMobile(context);
    
    if (isMobile) {
      // Use responsive table wrapper for mobile
      return SafeArea(
        child: ResponsiveRosterTable(
          rosterTable: _buildOriginalTable(),
          employees: employees,
          weekDates: weekDates,
          onShiftTap: _handleShiftTap,
          onEmployeeDelete: _deleteEmployee,
        ),
      );
    } else {
      // Use original table for desktop/tablet
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildWeekHeader(),
            _buildOriginalTable(),
          ],
        ),
      );
    }
  }

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
      employees: employees,
      weekDates: weekDates,
      rosterName: widget.rosterName,
      onEdit: _showAddShiftDialog,
      onRosterChanged: _updateRoster,
      onAddStaff: _addStaff,
    );
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
        // TODO: Open settings dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings coming soon')),
        );
        break;
      case 'export':
        // TODO: Export functionality
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export coming soon')),
        );
        break;
    }
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
      final weeksAgo = ((currentWeekStart.difference(monday).inDays) / 7).floor();
      return '$weeksAgo week${weeksAgo == 1 ? '' : 's'} ago';
    } else {
      final weeksAhead = ((monday.difference(currentWeekStart).inDays) / 7).floor();
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