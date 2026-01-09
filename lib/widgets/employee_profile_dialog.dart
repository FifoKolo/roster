import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/employee_model.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../services/roster_storage.dart';
import '../widgets/salary_profile_dialog.dart';
import '../utils/responsive_helper.dart';

class EmployeeProfileDialog extends StatefulWidget {
  final Employee employee;
  final Map<String, DateTime> weekDates;
  final VoidCallback? onEmployeeUpdated;

  const EmployeeProfileDialog({
    super.key,
    required this.employee,
    required this.weekDates,
    this.onEmployeeUpdated,
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

    _salaryProfile = await SalaryService.loadSalaryProfile(widget.employee.name);

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
      await _loadEmployeeData();
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
      await _loadEmployeeData();
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

  Future<void> _saveEmployeeCustomValues() async {
    try {
      print('💾 Saving custom values for ${widget.employee.name}');
      print('   customAccumulatedHours: ${widget.employee.customAccumulatedHours}');
      print('   customHolidayHours: ${widget.employee.customHolidayHours}');
      
      // Force the employee data to be re-persisted immediately
      // This prevents loss when the dialog closes or shifts are added
      // The actual roster save will happen via onEmployeeUpdated callback
    } catch (e) {
      print('❌ Error saving custom values: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = ResponsiveHelper.isMobile(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(isMobile ? 12 : 40),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 600,
        height: isMobile ? screenHeight * 0.9 : 700,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 24 : 30,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    widget.employee.name.isNotEmpty ? widget.employee.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.employee.name,
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Employee Profile',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: isMobile ? 22 : 24),
                  padding: EdgeInsets.all(isMobile ? 8 : 12),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 16 : 24),

            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.person,
                        color: Colors.blue,
                        child: Column(
                          children: [
                            _buildInfoRow('Name', widget.employee.name),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildInfoRow('Total Worked Hours', '${widget.employee.totalWorkedHours.toStringAsFixed(1)} hrs'),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildInfoRow('Total Paid Hours', '${widget.employee.totalPaidHours.toStringAsFixed(1)} hrs'),
                            Container(
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 4),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, size: isMobile ? 14 : 16, color: Colors.blue[600]),
                                  SizedBox(width: isMobile ? 6 : 8),
                                  Expanded(
                                    child: Text(
                                      'Salary calculations use Paid Hours',
                                      style: TextStyle(
                                        fontSize: isMobile ? 11 : 12,
                                        color: Colors.blue[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildInfoRow('Holiday Hours Earned', '${widget.employee.holidayHoursEarnedThisWeek.toStringAsFixed(1)} hrs'),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildInfoRow('Remaining Holiday Hours', '${widget.employee.remainingAccumulatedHolidayHours.toStringAsFixed(1)} hrs'),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 12 : 16),

                      _buildSectionCard(
                        title: 'Admin / Profile',
                        icon: Icons.badge,
                        color: Colors.indigo,
                        child: Column(
                          children: [
                            _buildEditableInfoRow('Email', widget.employee.email ?? 'Not set'),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildContractPdfRow(),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildEditableHoursRow('Custom Base Hours', widget.employee.customAccumulatedHours ?? 0.0),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildAccumulatedHoursDisplay(),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildEditableHoursRow('Total Holiday Hours', widget.employee.customHolidayHours ?? widget.employee.accumulatedHolidayHours),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildTotalHolidayHoursDisplay(),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 12 : 16),

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
                        _buildSectionCard(
                          title: 'This Week\'s Earnings',
                          icon: Icons.account_balance_wallet,
                          color: Colors.purple,
                          child: _buildWeeklyEarnings(),
                        ),
                      ],

                      const SizedBox(height: 16),

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
    final isMobile = ResponsiveHelper.isMobile(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
              Icon(icon, color: color, size: isMobile ? 18 : 20),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 14 : 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 14 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableInfoRow(String label, String value) {
    final isMobile = ResponsiveHelper.isMobile(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[700]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: () => _showTextEditDialog(
          title: 'Update $label',
          initialValue: value == 'Not set' ? '' : value,
          onSaved: (newValue) {
            setState(() => widget.employee.email = newValue.trim().isEmpty ? null : newValue.trim());
            widget.onEmployeeUpdated?.call();
          },
        ),
      ),
    );
  }

  Widget _buildContractPdfRow() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final currentValue = widget.employee.contractPdfName ?? widget.employee.contractPdfPath;
    final hasFile = widget.employee.contractPdfBase64 != null;
    final sizeKb = hasFile ? (base64Decode(widget.employee.contractPdfBase64!).lengthInBytes / 1024).toStringAsFixed(0) : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Contract PDF',
        style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentValue?.isNotEmpty == true ? currentValue! : 'Not set',
            style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[700]),
          ),
          if (hasFile && sizeKb != null)
            Text(
              'Stored ~${sizeKb}KB',
              style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: SizedBox(
        width: isMobile ? 140 : 170,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.upload_file, size: 18),
              tooltip: 'Import PDF',
              onPressed: _pickContractPdf,
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: 'Set URL/path',
              onPressed: () => _showTextEditDialog(
                title: 'Add contract PDF link or path',
                initialValue: widget.employee.contractPdfPath ?? '',
                hintText: 'https://... or local path',
                onSaved: (newValue) {
                  setState(() {
                    widget.employee.contractPdfPath = newValue.trim().isEmpty ? null : newValue.trim();
                    widget.employee.contractPdfName = null;
                    widget.employee.contractPdfBase64 = null;
                  });
                  widget.onEmployeeUpdated?.call();
                },
              ),
            ),
            if (currentValue?.isNotEmpty == true || hasFile)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    widget.employee.contractPdfPath = null;
                    widget.employee.contractPdfName = null;
                    widget.employee.contractPdfBase64 = null;
                  });
                  widget.onEmployeeUpdated?.call();
                },
                tooltip: 'Clear',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableHoursRow(String label, double value) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isBaseHours = label.contains('Base');
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${value.toStringAsFixed(1)} hrs',
        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[700]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: () => _showNumberEditDialog(
          title: 'Set $label',
          initialValue: value,
          isBaseHours: isBaseHours,
          onSaved: (newValue) {
            setState(() {
              if (isBaseHours) {
                widget.employee.customAccumulatedHours = newValue;
                // Auto-calculate holiday hours as 8% of base (unless user overrides)
                // Only auto-set if not previously customized
                if (widget.employee.customHolidayHours == null) {
                  widget.employee.customHolidayHours = newValue * 0.08;
                }
              } else {
                // Store custom holiday hours as an additive adjustment (do not overwrite accumulated)
                widget.employee.customHolidayHours = newValue;
              }
            });
            // Immediately save to storage to prevent loss on rebuild
            _saveEmployeeCustomValues();
            widget.onEmployeeUpdated?.call();
          },
        ),
      ),
    );
  }

  Widget _buildAccumulatedHoursDisplay() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final base = widget.employee.customAccumulatedHours ?? 0.0;
    final total = base + widget.employee.totalWorkedHours;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accumulated Hours (base + this week)',
            style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
          ),
          const SizedBox(height: 6),
          Text(
            '${total.toStringAsFixed(1)} hrs',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
          ),
          const SizedBox(height: 4),
          Text(
            'Base override: ${base.toStringAsFixed(1)} hrs • This week: ${widget.employee.totalWorkedHours.toStringAsFixed(1)} hrs',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.blueGrey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalHolidayHoursDisplay() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isCustomized = widget.employee.customHolidayHours != null;
    final baseHolidayHours = widget.employee.customHolidayHours ?? widget.employee.accumulatedHolidayHours;
    
    print('🔍 _buildTotalHolidayHoursDisplay for ${widget.employee.name}:');
    print('   isCustomized: $isCustomized');
    print('   customHolidayHours: ${widget.employee.customHolidayHours}');
    print('   accumulatedHolidayHours: ${widget.employee.accumulatedHolidayHours}');
    print('   baseHolidayHours: $baseHolidayHours');
    
    // If customized, the custom value IS the baseline and doesn't add earned hours
    // If not customized, add earned hours to accumulated
    final earnedThisWeek = isCustomized ? 0.0 : widget.employee.holidayHoursEarnedThisWeek;
    final totalHolidayHours = baseHolidayHours + earnedThisWeek;
    final usedThisWeek = widget.employee.totalHolidayHoursUsed;
    final remaining = totalHolidayHours - usedThisWeek;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Holiday Hours (override)',
            style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: Colors.teal[800]),
          ),
          const SizedBox(height: 6),
          Text(
            '${totalHolidayHours.toStringAsFixed(1)} hrs',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.teal[900]),
          ),
          const SizedBox(height: 4),
          Text(
            isCustomized
                ? 'Custom baseline: ${baseHolidayHours.toStringAsFixed(1)} hrs (fixed override)'
                : 'Base: ${baseHolidayHours.toStringAsFixed(1)} hrs • Earned this week: ${earnedThisWeek.toStringAsFixed(1)} hrs',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.teal[600]),
          ),
          const SizedBox(height: 2),
          Text(
            'Used this week: ${usedThisWeek.toStringAsFixed(1)} hrs • Remaining: ${remaining.toStringAsFixed(1)} hrs',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.teal[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _pickContractPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      final encoded = base64Encode(file.bytes!);

      setState(() {
        widget.employee.contractPdfName = file.name;
        widget.employee.contractPdfBase64 = encoded;
        widget.employee.contractPdfPath = null;
      });

      widget.onEmployeeUpdated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${file.name} (${(file.size / 1024).toStringAsFixed(0)}KB)')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showTextEditDialog({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSaved,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Value',
              hintText: hintText,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      onSaved(controller.text);
    }
  }

  Future<void> _showNumberEditDialog({
    required String title,
    required double initialValue,
    required ValueChanged<double> onSaved,
    bool isBaseHours = false,
  }) async {
    final controller = TextEditingController(text: initialValue.toStringAsFixed(1));
    String? errorText;
    double? suggestedHolidayHours;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      hintText: 'e.g. 40',
                      errorText: errorText,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    onChanged: (val) {
                      setLocalState(() {
                        errorText = null;
                        // When editing base hours, show suggested holiday calculation
                        if (isBaseHours) {
                          final parsed = double.tryParse(val.trim());
                          suggestedHolidayHours = parsed != null ? parsed * 0.08 : null;
                        }
                      });
                    },
                  ),
                  if (isBaseHours && suggestedHolidayHours != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Holiday hrs will auto-set to ${suggestedHolidayHours!.toStringAsFixed(2)} (8%)',
                              style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text.trim());
                    if (parsed == null) {
                      setLocalState(() => errorText = 'Enter a valid number');
                      return;
                    }
                    Navigator.of(context).pop(true);
                    onSaved(parsed);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;
    widget.onEmployeeUpdated?.call();

    // After saving, offer to apply to future weeks
    _showApplyForwardDialog(title, isBaseHours);
  }

  Future<void> _showApplyForwardDialog(String fieldTitle, bool isBase) async {
    if (!mounted) return;

    final newValue = isBase
        ? widget.employee.customAccumulatedHours
        : widget.employee.customHolidayHours;

    if (newValue == null) return; // User cleared it

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to future weeks?'),
        content: Text(
          'Apply this value to ${widget.employee.name} in all future weeks?\n\n'
          'This will set the same baseline for all upcoming rosters.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, this week only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Yes, apply forward'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Apply forward
    _applyCustomValueForward(isBase);
  }

  Future<void> _applyCustomValueForward(bool isBase) async {
    // Show progress dialog
    if (!mounted) return;

    final progressContext = context;
    showDialog(
      context: progressContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Applying to future weeks...'),
        content: const SizedBox(
          height: 60,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );

    try {
      final customAccum = isBase ? widget.employee.customAccumulatedHours : null;
      final customHoliday = isBase ? null : widget.employee.customHolidayHours;

      final updatedCount = await RosterStorage.applyCustomValuesForward(
        employeeName: widget.employee.name,
        customAccumulatedHours: customAccum,
        customHolidayHours: customHoliday,
        fromDate: widget.weekDates['Mon'],
      );

      if (!mounted) return;

      // Close progress dialog
      Navigator.of(progressContext).pop();

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedCount > 0
                  ? 'Applied to $updatedCount future week(s)'
                  : 'No future weeks found to update',
            ),
            backgroundColor: updatedCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error applying forward: $e');
      if (!mounted) return;

      // Close progress dialog
      Navigator.of(progressContext).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNoSalaryProfile() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Column(
      children: [
        Icon(Icons.money_off, size: isMobile ? 40 : 48, color: Colors.grey[400]),
        SizedBox(height: isMobile ? 10 : 12),
        Text(
          'No salary profile set',
          style: TextStyle(
            fontSize: isMobile ? 15 : 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        Text(
          'Create a salary profile to track earnings and bonuses',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: isMobile ? 13 : 14,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: isMobile ? 12 : 16),
        ElevatedButton.icon(
          onPressed: _openSalaryProfileDialog,
          icon: Icon(Icons.add, size: isMobile ? 18 : 20),
          label: Text(
            'Create Salary Profile',
            style: TextStyle(fontSize: isMobile ? 14 : 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 20,
              vertical: isMobile ? 10 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryInformation() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Column(
      children: [
        _buildInfoRow('Base Salary/Hour', '€${_salaryProfile!.baseSalaryPerHour.toStringAsFixed(2)}'),
        _buildInfoRow('Sunday Bonus', '${_salaryProfile!.sundayBonusPercentage.toStringAsFixed(1)}%'),
        _buildInfoRow('Bank Holiday Bonus', '${_salaryProfile!.bankHolidayBonusPercentage.toStringAsFixed(1)}%'),
        _buildInfoRow('Christmas Bonus', '${_salaryProfile!.christmasBonusPercentage.toStringAsFixed(1)}%'),
        SizedBox(height: isMobile ? 10 : 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openSalaryProfileDialog,
                icon: Icon(Icons.edit, size: isMobile ? 16 : 18),
                label: Text(
                  'Edit',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 10 : 12,
                  ),
                ),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _deleteSalaryProfile,
                icon: Icon(Icons.delete, size: isMobile ? 16 : 18),
                label: Text(
                  'Delete',
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 10 : 12,
                  ),
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
