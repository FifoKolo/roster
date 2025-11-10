import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';
import '../theme/app_theme.dart';
import '../models/employee_model.dart';

/// Responsive wrapper for the roster table that adapts to different screen sizes
class ResponsiveRosterTable extends StatelessWidget {
  final Widget rosterTable;
  final List<Employee> employees;
  final Map<String, DateTime> weekDates;
  final Function(BuildContext, Employee, String) onShiftTap;
  final Function(Employee) onEmployeeDelete;

  const ResponsiveRosterTable({
    Key? key,
    required this.rosterTable,
    required this.employees,
    required this.weekDates,
    required this.onShiftTap,
    required this.onEmployeeDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isLandscape = ResponsiveHelper.isLandscape(context);
    
    if (isMobile) {
      return _buildMobileLayout(context, isLandscape);
    } else {
      return _buildDesktopLayout(context);
    }
  }

  Widget _buildMobileLayout(BuildContext context, bool isLandscape) {
    if (isLandscape) {
      // Mobile landscape: Show condensed horizontal scrollable table
      return _buildLandscapeTable(context);
    } else {
      // Mobile portrait: Show card-based layout for better readability
      return _buildPortraitCards(context);
    }
  }

  Widget _buildDesktopLayout(BuildContext context) {
    // Desktop: Show full table with all features
    return Container(
      margin: ResponsiveHelper.getResponsiveMargin(context),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.borderPrimary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: rosterTable,
    );
  }

  Widget _buildLandscapeTable(BuildContext context) {
    // Mobile landscape: Condensed table with horizontal scrolling
    return Container(
      margin: ResponsiveHelper.getResponsiveMargin(context),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        children: [
          // Header with week navigation
          _buildWeekHeader(context),
          // Horizontal scrollable table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: rosterTable,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitCards(BuildContext context) {
    // Mobile portrait: Card-based layout for each employee
    return Column(
      children: [
        _buildWeekHeader(context),
        const SizedBox(height: 16),
        ...employees.map((employee) => _buildEmployeeCard(context, employee)),
        const SizedBox(height: 80), // Space for FAB
      ],
    );
  }

  Widget _buildWeekHeader(BuildContext context) {
    final firstDate = weekDates['Mon'] ?? DateTime.now();
    final lastDate = weekDates['Sun'] ?? DateTime.now();
    
    return Container(
      padding: ResponsiveHelper.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month,
            color: AppTheme.primaryBlue,
            size: ResponsiveHelper.getResponsiveIconSize(context, 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_formatDate(firstDate)} - ${_formatDate(lastDate)}',
              style: TextStyle(
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, Employee employee) {
    return Container(
      margin: ResponsiveHelper.getResponsiveMargin(context),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderPrimary),
        boxShadow: [
          BoxShadow(
            color: AppTheme.borderPrimary.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Employee header
          _buildEmployeeHeader(context, employee),
          // Weekly schedule
          _buildWeeklySchedule(context, employee),
          // Employee stats
          _buildEmployeeStats(context, employee),
        ],
      ),
    );
  }

  Widget _buildEmployeeHeader(BuildContext context, Employee employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppTheme.borderPrimary)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryBlue,
            radius: ResponsiveHelper.getResponsiveIconSize(context, 16),
            child: Text(
              employee.name.isNotEmpty ? employee.name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Total: ${employee.totalWorkedHours.toStringAsFixed(1)}h',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: AppTheme.textSecondary,
              size: ResponsiveHelper.getResponsiveIconSize(context, 20),
            ),
            onSelected: (value) {
              if (value == 'delete') {
                onEmployeeDelete(employee);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySchedule(BuildContext context, Employee employee) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Schedule',
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...weekDates.entries.map((entry) {
            final dayName = entry.key;
            final date = entry.value;
            final shift = employee.shifts[dayName] ?? Shift();
            
            return _buildDayRow(context, dayName, date, shift, employee);
          }),
        ],
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, String dayName, DateTime date, Shift shift, Employee employee) {
    final isToday = _isSameDay(date, DateTime.now());
    final isWeekend = dayName == 'Sat' || dayName == 'Sun';
    
    return InkWell(
      onTap: () => onShiftTap(context, employee, dayName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isToday 
            ? AppTheme.accentTeal.withOpacity(0.1)
            : (isWeekend ? AppTheme.backgroundSecondary : null),
          borderRadius: BorderRadius.circular(8),
          border: isToday ? Border.all(color: AppTheme.accentTeal, width: 1) : null,
        ),
        child: Row(
          children: [
            // Day and date
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppTheme.accentTeal : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getResponsiveFontSize(context, 10),
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Shift details
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getShiftColor(shift),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  shift.formatted(),
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 12),
                    fontWeight: FontWeight.w500,
                    color: _getShiftTextColor(shift),
                  ),
                ),
              ),
            ),
            
            // Hours badge
            if (shift.duration > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${shift.duration}h',
                  style: TextStyle(
                    fontSize: ResponsiveHelper.getResponsiveFontSize(context, 10),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.success,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeStats(BuildContext context, Employee employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, 'Worked', '${employee.totalWorkedHours}h', AppTheme.primaryBlue),
          _buildStatItem(context, 'Paid', '${employee.totalPaidHours}h', AppTheme.success),
          _buildStatItem(context, 'Break', '0h', AppTheme.warning),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 14),
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: ResponsiveHelper.getResponsiveFontSize(context, 10),
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getShiftColor(Shift shift) {
    if (shift.startTime == null && shift.endTime == null && !shift.isHoliday) return AppTheme.borderPrimary.withOpacity(0.3);
    if (shift.isHoliday) return AppTheme.warning.withOpacity(0.2);
    return AppTheme.primaryBlue.withOpacity(0.1);
  }

  Color _getShiftTextColor(Shift shift) {
    if (shift.startTime == null && shift.endTime == null && !shift.isHoliday) return AppTheme.textSecondary;
    if (shift.isHoliday) return AppTheme.warning;
    return AppTheme.primaryBlue;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}