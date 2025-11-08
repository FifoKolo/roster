import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/irish_bank_holidays.dart';

class ModernRosterTable extends StatefulWidget {
  final List<Employee> employees;
  final Map<String, DateTime> weekDates;
  final Future<Shift?> Function(BuildContext, Shift?) onEdit;
  final Future<void> Function(List<Employee>) onRosterChanged;

  const ModernRosterTable({
    super.key,
    required this.employees,
    required this.weekDates,
    required this.onEdit,
    required this.onRosterChanged,
  });

  @override
  State<ModernRosterTable> createState() => _ModernRosterTableState();
}

class _ModernRosterTableState extends State<ModernRosterTable> {
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _viewBy = 'Employee'; // 'Employee' or 'Day'
  DateTime _currentWeek = DateTime.now();
  
  // Color scheme matching ScheduleBee
  static const Color _primaryOrange = Color(0xFFFF6B35);
  static const Color _lightGray = Color(0xFFF5F5F5);
  static const Color _darkGray = Color(0xFF666666);
  static const Color _white = Colors.white;
  static const Color _yellow = Color(0xFFF5E6A3);
  static const Color _lightBlue = Color(0xFFB8D4F1);

  @override
  void initState() {
    super.initState();
    _initCurrentWeek();
  }

  void _initCurrentWeek() {
    if (widget.weekDates.isNotEmpty) {
      final mondayDate = widget.weekDates['Mon'];
      if (mondayDate != null) {
        _currentWeek = mondayDate;
      }
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
        children: [
          _buildHeader(),
          _buildWeekNavigation(),
          _buildDayHeaders(),
          Expanded(
            child: _buildRosterContent(),
          ),
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
                  color: _primaryOrange,
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
                'RosterBee',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryOrange,
                ),
              ),
            ],
          ),
          const Spacer(),
          
          // View by dropdown
          Row(
            children: [
              const Text(
                'View by:',
                style: TextStyle(
                  fontSize: 16,
                  color: _darkGray,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _darkGray.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _viewBy,
                  underline: const SizedBox(),
                  items: ['Employee', 'Day'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _viewBy = newValue;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNavigation() {
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
          
          // Navigation buttons
          _buildNavButton('◄◄ Prev Week', () => _navigateWeek(-1)),
          const SizedBox(width: 8),
          _buildNavButton('Current Week', () => _goToCurrentWeek()),
          const SizedBox(width: 8),
          _buildNavButton('Next Week ►►', () => _navigateWeek(1)),
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

  Widget _buildDayHeaders() {
    return Container(
      color: _white,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Employee name column header (if viewing by employee)
          if (_viewBy == 'Employee')
            Container(
              width: 180,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                'Open Shifts',
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
    final bankHoliday = date != null ? IrishBankHolidays.getBankHoliday(date) : null;
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
              color: isBankHoliday ? Colors.red : _primaryOrange,
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
    return Container(
      color: _white,
      child: Column(
        children: [
          // Open shifts row
          _buildOpenShiftsRow(),
          
          // Employee rows
          Expanded(
            child: ListView.builder(
              itemCount: widget.employees.length,
              itemBuilder: (context, index) {
                final employee = widget.employees[index];
                return _buildEmployeeRow(employee, index);
              },
            ),
          ),
          
          // Add shift row
          _buildAddShiftRow(),
        ],
      ),
    );
  }

  Widget _buildOpenShiftsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _darkGray.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 180,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Text(
              'Open Shifts',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _darkGray,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: _days.map((day) {
                return Expanded(
                  child: _buildOpenShiftCell(day),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftCell(String day) {
    // Check if there are any unassigned shifts for this day
    // For now, show example open shifts
    final hasOpenShift = day == 'Mon' || day == 'Tue'; // Example logic
    
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: hasOpenShift ? _yellow : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _darkGray.withOpacity(0.2)),
      ),
      child: hasOpenShift
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '2pm - 5:45pm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.brown[700],
                  ),
                ),
                Text(
                  'Manager',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.brown[600],
                  ),
                ),
              ],
            )
          : const SizedBox(height: 40),
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
              backgroundColor: _primaryOrange,
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
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _showEmployeeProfile(employee),
          child: Text(
            'View profile',
            style: TextStyle(
              fontSize: 12,
              color: _primaryOrange,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCell(Employee employee, String day, Shift? shift) {
    return GestureDetector(
      onTap: () => _editShift(employee, day, shift),
      child: Container(
        padding: const EdgeInsets.all(8),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _getShiftCellColor(shift),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _darkGray.withOpacity(0.2),
            width: 0.5,
          ),
        ),
        child: _buildShiftContent(shift),
      ),
    );
  }

  Color _getShiftCellColor(Shift? shift) {
    if (shift == null) return Colors.transparent;
    
    if (shift.isHoliday) return Colors.green[100]!;
    
    // For work shifts, use role-based colors
    return shift.role?.toLowerCase().contains('manager') == true 
        ? _yellow 
        : _lightBlue;
  }

  Widget _buildShiftContent(Shift? shift) {
    if (shift == null) {
      return const SizedBox(height: 40);
    }

    if (shift.isHoliday) {
      return const Center(
        child: Text(
          'Holiday',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _darkGray,
          ),
        ),
      );
    } else if (shift.startTime != null && shift.endTime != null) {
      return Column(
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
      );
    } else {
      return Center(
        child: Text(
          'Day Off',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _darkGray,
          ),
        ),
      );
    }
  }

  Widget _buildAddShiftRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _addShift,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _lightGray,
              foregroundColor: _darkGray,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _darkGray.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _pasteShift,
            icon: const Icon(Icons.content_paste, size: 16),
            label: const Text('Paste'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _lightGray,
              foregroundColor: _darkGray,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: _darkGray.withOpacity(0.3)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  String _getMonthAbbr(int month) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month];
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // Action methods
  void _navigateWeek(int direction) {
    setState(() {
      _currentWeek = _currentWeek.add(Duration(days: 7 * direction));
      // Update week dates
      for (int i = 0; i < 7; i++) {
        widget.weekDates[_days[i]] = _currentWeek.add(Duration(days: i));
      }
    });
    // Notify parent of week change
    widget.onRosterChanged(widget.employees);
  }

  void _goToCurrentWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    setState(() {
      _currentWeek = monday;
      for (int i = 0; i < 7; i++) {
        widget.weekDates[_days[i]] = monday.add(Duration(days: i));
      }
    });
    // Notify parent of week change
    widget.onRosterChanged(widget.employees);
  }

  Future<void> _editShift(Employee employee, String day, Shift? shift) async {
    final editedShift = await widget.onEdit(context, shift);
    if (editedShift != null) {
      setState(() {
        employee.shifts[day] = editedShift;
      });
      widget.onRosterChanged(widget.employees);
    }
  }

  void _showEmployeeProfile(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${employee.name} Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Hours: ${employee.totalWorkedHours.toStringAsFixed(1)}'),
            Text('Paid Hours: ${employee.totalPaidHours.toStringAsFixed(1)}'),
            Text('Holiday Hours: ${employee.holidayHoursEarnedThisWeek.toStringAsFixed(1)}'),
            Text('Break Hours: ${employee.breakHours.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addShift() async {
    // Show dialog to select employee and day first
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _AddShiftTargetDialog(employees: widget.employees),
    );
    
    if (result != null) {
      final employeeName = result['employee']!;
      final day = result['day']!;
      final employee = widget.employees.firstWhere((e) => e.name == employeeName);
      
      final newShift = await widget.onEdit(context, null);
      if (newShift != null) {
        setState(() {
          employee.shifts[day] = newShift;
        });
        widget.onRosterChanged(widget.employees);
      }
    }
  }

  void _pasteShift() {
    // For now, show a message that this feature is coming soon
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paste shift functionality coming soon')),
    );
  }
}

// Helper dialog for selecting where to add a shift
class _AddShiftTargetDialog extends StatefulWidget {
  final List<Employee> employees;
  
  const _AddShiftTargetDialog({required this.employees});

  @override
  State<_AddShiftTargetDialog> createState() => _AddShiftTargetDialogState();
}

class _AddShiftTargetDialogState extends State<_AddShiftTargetDialog> {
  String? selectedEmployee;
  String? selectedDay;
  
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Shift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Employee'),
            value: selectedEmployee,
            items: widget.employees.map((employee) {
              return DropdownMenuItem(
                value: employee.name,
                child: Text(employee.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedEmployee = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Day'),
            value: selectedDay,
            items: _days.map((day) {
              return DropdownMenuItem(
                value: day,
                child: Text(day),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedDay = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: selectedEmployee != null && selectedDay != null
            ? () {
                Navigator.of(context).pop({
                  'employee': selectedEmployee!,
                  'day': selectedDay!,
                });
              }
            : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}