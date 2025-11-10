import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../widgets/salary_profile_dialog.dart';

class EmployeeProfileDialog extends StatefulWidget {
  final Employee employee;
  final Map<String, DateTime> weekDates;

  const EmployeeProfileDialog({
    super.key,
    required this.employee,
    required this.weekDates,
  });

  @override
  State<EmployeeProfileDialog> createState() => _EmployeeProfileDialogState();
}

class _EmployeeProfileDialogState extends State<EmployeeProfileDialog> {
  SalaryProfile? _salaryProfile;
  Map<String, double>? _weeklyEarnings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    setState(() => _isLoading = true);
    
    // Load salary profile
    _salaryProfile = await SalaryService.loadSalaryProfile(widget.employee.name);
    
    // Calculate weekly earnings if salary profile exists
    if (_salaryProfile != null) {
      _weeklyEarnings = await SalaryService.calculateEarningsFromEmployee(
        widget.employee,
        widget.weekDates,
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _openSalaryProfileDialog() async {
    final result = await showDialog<SalaryProfile>(
      context: context,
      builder: (context) => SalaryProfileDialog(
        employeeId: widget.employee.name,
        employeeName: widget.employee.name,
        existingProfile: _salaryProfile,
      ),
    );

    if (result != null) {
      await _loadEmployeeData(); // Refresh data
    }
  }

  Future<void> _deleteSalaryProfile() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Salary Profile'),
        content: Text('Are you sure you want to delete the salary profile for ${widget.employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SalaryService.deleteSalaryProfile(widget.employee.name);
      await _loadEmployeeData(); // Refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salary profile deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Employee Profile',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information
                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.person,
                        color: Colors.blue,
                        child: Column(
                          children: [
                            _buildInfoRow('Name', widget.employee.name),
                            _buildInfoRow('Total Worked Hours', '${widget.employee.totalWorkedHours.toStringAsFixed(1)} hrs'),
                            _buildInfoRow('Total Paid Hours', '${widget.employee.totalPaidHours.toStringAsFixed(1)} hrs'),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Salary calculations use Paid Hours',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow('Holiday Hours Earned', '${widget.employee.holidayHoursEarnedThisWeek.toStringAsFixed(1)} hrs'),
                            _buildInfoRow('Remaining Holiday Hours', '${widget.employee.remainingAccumulatedHolidayHours.toStringAsFixed(1)} hrs'),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Salary Information
                      _buildSectionCard(
                        title: 'Salary Information',
                        icon: Icons.attach_money,
                        color: Colors.green,
                        child: _salaryProfile == null 
                          ? _buildNoSalaryProfile()
                          : _buildSalaryInformation(),
                      ),

                      if (_weeklyEarnings != null) ...[
                        const SizedBox(height: 16),
                        // Weekly Earnings
                        _buildSectionCard(
                          title: 'This Week\'s Earnings',
                          icon: Icons.account_balance_wallet,
                          color: Colors.purple,
                          child: _buildWeeklyEarnings(),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Weekly Schedule
                      _buildSectionCard(
                        title: 'Weekly Schedule',
                        icon: Icons.schedule,
                        color: Colors.orange,
                        child: _buildWeeklySchedule(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNoSalaryProfile() {
    return Column(
      children: [
        Icon(Icons.money_off, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          'No salary profile set',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create a salary profile to track earnings and bonuses',
          style: TextStyle(color: Colors.grey[500]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openSalaryProfileDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create Salary Profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryInformation() {
    return Column(
      children: [
        _buildInfoRow('Base Salary/Hour', '€${_salaryProfile!.baseSalaryPerHour.toStringAsFixed(2)}'),
        _buildInfoRow('Sunday Bonus', '${_salaryProfile!.sundayBonusPercentage.toStringAsFixed(1)}%'),
        _buildInfoRow('Bank Holiday Bonus', '${_salaryProfile!.bankHolidayBonusPercentage.toStringAsFixed(1)}%'),
        _buildInfoRow('Christmas Bonus', '${_salaryProfile!.christmasBonusPercentage.toStringAsFixed(1)}%'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openSalaryProfileDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _deleteSalaryProfile,
                icon: const Icon(Icons.delete),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyEarnings() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Based on ${widget.employee.totalPaidHours.toStringAsFixed(1)} paid hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.purple[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInfoRow('Base Earnings', '€${_weeklyEarnings!['baseEarnings']!.toStringAsFixed(2)}'),
        if (_weeklyEarnings!['paidBreakTime']! > 0)
          _buildInfoRow('Paid Break Time', '€${_weeklyEarnings!['paidBreakTime']!.toStringAsFixed(2)}'),
        if (_weeklyEarnings!['sundayBonus']! > 0)
          _buildInfoRow('Sunday Bonus', '€${_weeklyEarnings!['sundayBonus']!.toStringAsFixed(2)}'),
        if (_weeklyEarnings!['bankHolidayBonus']! > 0)
          _buildInfoRow('Bank Holiday Bonus', '€${_weeklyEarnings!['bankHolidayBonus']!.toStringAsFixed(2)}'),
        if (_weeklyEarnings!['christmasBonus']! > 0)
          _buildInfoRow('Christmas Bonus', '€${_weeklyEarnings!['christmasBonus']!.toStringAsFixed(2)}'),
        if (_weeklyEarnings!['irishBankHolidayEntitlement']! > 0)
          _buildInfoRow('Irish Bank Holiday Entitlement', '€${_weeklyEarnings!['irishBankHolidayEntitlement']!.toStringAsFixed(2)}'),
        const Divider(),
        _buildInfoRow('Total Earnings', '€${_weeklyEarnings!['totalEarnings']!.toStringAsFixed(2)}'),
      ],
    );
  }

  Widget _buildWeeklySchedule() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Column(
      children: days.map((day) {
        final shift = widget.employee.shifts[day];
        final date = widget.weekDates[day];
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  day,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              if (date != null)
                SizedBox(
                  width: 80,
                  child: Text(
                    '${date.day}/${date.month}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              Expanded(
                child: shift != null && shift.startTime != null && shift.endTime != null
                  ? Row(
                      children: [
                        Text('${shift.startTime!.format(context)} - ${shift.endTime!.format(context)}'),
                        const SizedBox(width: 8),
                        Text('(${shift.duration}h)', style: TextStyle(color: Colors.grey[600])),
                        if (shift.isHoliday)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Holiday',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    )
                  : Text('Day off', style: TextStyle(color: Colors.grey[500])),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}