import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/employee_model.dart';
import '../services/roster_storage.dart';
import '../services/pdf_service.dart';
import '../widgets/modern_roster_table.dart';
import '../widgets/add_shift_dialog.dart';
import '../widgets/global_salary_settings_dialog.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_theme.dart';

/// A responsive wrapper for the roster page that adapts to mobile devices
class ResponsiveRosterPage extends StatefulWidget {
  final String rosterName;

  const ResponsiveRosterPage({
    super.key,
    required this.rosterName,
  });

  @override
  State<ResponsiveRosterPage> createState() => _ResponsiveRosterPageState();
}

class _ResponsiveRosterPageState extends State<ResponsiveRosterPage> {
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
      resizeToAvoidBottomInset: true, // Allow proper keyboard handling
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
    // Portrait-friendly menu with all actions
    return [
      // Schedule/PDF Menu
      PopupMenuButton<String>(
        icon: Icon(
          Icons.calendar_month,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        tooltip: 'Schedule Actions',
        onSelected: _handleScheduleAction,
        itemBuilder: (context) => [
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
      // Settings
      IconButton(
        icon: Icon(
          Icons.settings,
          color: Colors.white,
          size: ResponsiveHelper.getResponsiveIconSize(context, 24),
        ),
        onPressed: _showSettings,
        tooltip: 'Settings',
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
    // Show the roster table with horizontal and vertical scrolling on all devices
    return SafeArea(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
      onCurrentWeekDataChanged: _onCurrentWeekDataChanged,
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

  // PDF and Schedule Actions
  void _handleScheduleAction(String action) {
    switch (action) {
      case 'preview_public':
        _previewPublicPdf();
        break;
      case 'download_public':
        _exportPublicPdf();
        break;
      case 'preview_private':
        _previewPrivatePdf();
        break;
      case 'download_private':
        _exportPrivatePdf();
        break;
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => GlobalSalarySettingsDialog(),
    );
  }

  Future<void> _previewPublicPdf() async {
    try {
      final pdf = await PdfService.buildPublicRosterPdf(
        currentWeekEmployees.isEmpty ? employees : currentWeekEmployees,
        weekDates,
      );
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Staff Schedule Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdf,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error previewing PDF: $e')),
      );
    }
  }

  Future<void> _previewPrivatePdf() async {
    try {
      final pdf = await PdfService.buildPrivateRosterPdf(
        currentWeekEmployees.isEmpty ? employees : currentWeekEmployees,
        weekDates,
      );
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Management Report Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: PdfPreview(
                    build: (format) => pdf,
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error previewing PDF: $e')),
      );
    }
  }

  Future<void> _exportPublicPdf() async {
    try {
      await PdfService.sharePublicRosterPdf(
        context,
        currentWeekEmployees.isEmpty ? employees : currentWeekEmployees,
        weekDates,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff schedule PDF downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  Future<void> _exportPrivatePdf() async {
    try {
      await PdfService.sharePrivateRosterPdf(
        context,
        currentWeekEmployees.isEmpty ? employees : currentWeekEmployees,
        weekDates,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Management report PDF downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting PDF: $e')),
      );
    }
  }

  void _onCurrentWeekDataChanged(List<Employee> weekEmployees, DateTime weekDate) {
    setState(() {
      currentWeekEmployees = weekEmployees;
      currentWeekDate = weekDate;
    });
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