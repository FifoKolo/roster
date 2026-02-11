import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/employee_model.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../services/roster_storage.dart';
import '../widgets/salary_profile_dialog.dart';
import '../widgets/document_management_dialog.dart';
import '../utils/responsive_helper.dart';

// Conditional imports for web
import 'dart:html' as html show window;

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

  Future<void> _openDocumentManagementDialog() async {
    await showDialog(
      context: context,
      builder: (context) => DocumentManagementDialog(
        employeeName: widget.employee.name,
        documents: widget.employee.documents,
        onDocumentsChanged: (updatedDocuments) {
          setState(() {
            widget.employee.documents.clear();
            widget.employee.documents.addAll(updatedDocuments);
          });
          widget.onEmployeeUpdated?.call();
        },
      ),
    );
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
                            _buildInfoRow('Holiday Hours Earned', '${widget.employee.holidayHoursEarnedThisWeek.toStringAsFixed(2)} hrs'),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildInfoRow('Remaining Holiday Hours', '${widget.employee.remainingAccumulatedHolidayHours.toStringAsFixed(2)} hrs'),
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
                            _buildContractTypeRow(),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildContractPdfRow(),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildEditableHoursRow('Custom Base Hours', widget.employee.customAccumulatedHours ?? 0.0),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildAccumulatedHoursDisplay(),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildEditableHoursRow('Total Holiday Hours Available', widget.employee.accumulatedHolidayHours + (widget.employee.customHolidayHours ?? 0.0) + widget.employee.holidayHoursEarnedThisWeek),
                            SizedBox(height: isMobile ? 12 : 8),
                            _buildTotalHolidayHoursDisplay(),
                          ],
                        ),
                      ),

                      SizedBox(height: isMobile ? 12 : 16),

                      _buildSectionCard(
                        title: 'Personal Documents',
                        icon: Icons.folder_open,
                        color: Colors.deepPurple,
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.insert_drive_file, size: isMobile ? 18 : 20, color: Colors.grey[600]),
                                SizedBox(width: isMobile ? 8 : 10),
                                Expanded(
                                  child: Text(
                                    '${widget.employee.documents.length} document${widget.employee.documents.length != 1 ? 's' : ''} stored',
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 10 : 12),
                            // Show document category badges
                            if (widget.employee.documents.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                                child: Wrap(
                                  spacing: isMobile ? 6 : 8,
                                  runSpacing: isMobile ? 6 : 8,
                                  children: _getUniqueDocumentCategories()
                                      .map((category) => _buildCategoryBadge(category, isMobile))
                                      .toList(),
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
                                child: Text(
                                  'No documents uploaded yet',
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 13,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              'Store training certificates, medical notes, doctor\'s sick leave documentation, and other important documents.',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            ElevatedButton.icon(
                              onPressed: _openDocumentManagementDialog,
                              icon: Icon(Icons.folder_open, size: isMobile ? 16 : 18),
                              label: Text(
                                'Manage Documents',
                                style: TextStyle(fontSize: isMobile ? 14 : 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 16 : 20,
                                  vertical: isMobile ? 10 : 12,
                                ),
                              ),
                            ),
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

  Widget _buildContractTypeRow() {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    // Irish employment contract types
    final contractTypes = [
      'Full-Time Permanent',
      'Part-Time Permanent',
      'Fixed-Term Contract',
      'Casual/Temporary',
      'Apprenticeship',
      'Agency Worker',
    ];
    
    final currentType = widget.employee.contractType ?? 'Not set';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'Contract Type',
        style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        currentType,
        style: TextStyle(
          fontSize: isMobile ? 13 : 14, 
          color: currentType == 'Not set' ? Colors.grey[700] : Colors.blue[700],
          fontWeight: currentType == 'Not set' ? FontWeight.normal : FontWeight.w500,
        ),
      ),
      trailing: SizedBox(
        width: isMobile ? 140 : 170,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.work_outline, size: 18),
              tooltip: 'Select contract type',
              onPressed: () => _showContractTypeDialog(contractTypes),
            ),
            if (currentType != 'Not set')
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    widget.employee.contractType = null;
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
    final isHolidayHours = label.contains('Holiday');
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: TextStyle(fontSize: isMobile ? 14 : 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${value.toStringAsFixed(2)} hrs',
        style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[700]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: () => _showNumberEditDialog(
          title: 'Set $label',
          initialValue: value,
          isBaseHours: isBaseHours,
          isHolidayHours: isHolidayHours,
          onSaved: (newValue) {
            setState(() {
              if (isBaseHours) {
                widget.employee.customAccumulatedHours = newValue;
                // Auto-calculate holiday hours as 8% of base (unless user overrides)
                // Only auto-set if not previously customized
                if (widget.employee.customHolidayHours == null) {
                  widget.employee.customHolidayHours = newValue * 0.08;
                }
              } else if (isHolidayHours) {
                // For holiday hours, calculate the custom adjustment needed
                // Total = accumulated + custom + earned this week
                // So: custom = Total - accumulated - earned this week
                final earnedThisWeek = widget.employee.holidayHoursEarnedThisWeek;
                final customAdjustment = newValue - widget.employee.accumulatedHolidayHours - earnedThisWeek;
                widget.employee.customHolidayHours = customAdjustment.clamp(0.0, double.infinity);
              } else {
                // Other cases (fallback)
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
            '${total.toStringAsFixed(2)} hrs',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
          ),
          const SizedBox(height: 4),
          Text(
            'Base override: ${base.toStringAsFixed(2)} hrs • This week: ${widget.employee.totalWorkedHours.toStringAsFixed(2)} hrs',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.blueGrey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalHolidayHoursDisplay() {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isCustomized = widget.employee.customHolidayHours != null;
    // Custom holiday hours is ADDITIVE to accumulated, not a replacement
    final baseHolidayHours = widget.employee.accumulatedHolidayHours + (widget.employee.customHolidayHours ?? 0.0);
    
    print('🔍 _buildTotalHolidayHoursDisplay for ${widget.employee.name}:');
    print('   isCustomized: $isCustomized');
    print('   customHolidayHours: ${widget.employee.customHolidayHours}');
    print('   accumulatedHolidayHours: ${widget.employee.accumulatedHolidayHours}');
    print('   baseHolidayHours: $baseHolidayHours');
    
    // ALWAYS add earned hours (8% of paid hours) to the pool, regardless of customization
    // The custom adjustment is just an additional amount given by management
    final earnedThisWeek = widget.employee.holidayHoursEarnedThisWeek;
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
            'Holiday Hours Summary',
            style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w600, color: Colors.teal[800]),
          ),
          const SizedBox(height: 6),
          Text(
            '${totalHolidayHours.toStringAsFixed(2)} hrs',
            style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold, color: Colors.teal[900]),
          ),
          const SizedBox(height: 4),
          Text(
            isCustomized
                ? 'Base: ${widget.employee.accumulatedHolidayHours.toStringAsFixed(2)} + Custom: ${widget.employee.customHolidayHours!.toStringAsFixed(2)} + Earned: ${earnedThisWeek.toStringAsFixed(2)} hrs'
                : 'Base: ${widget.employee.accumulatedHolidayHours.toStringAsFixed(2)} hrs • Earned this week: ${earnedThisWeek.toStringAsFixed(2)} hrs',
            style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.teal[600]),
          ),
          const SizedBox(height: 2),
          Text(
            'Used this week: ${usedThisWeek.toStringAsFixed(2)} hrs (deducted from pool) • Remaining: ${remaining.toStringAsFixed(2)} hrs',
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

  Future<void> _showContractTypeDialog(List<String> contractTypes) async {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Contract Type'),
          content: SizedBox(
            width: isMobile ? 280 : 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose the employment contract type for this employee:',
                    style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 16),
                  ...contractTypes.map((type) {
                    final isSelected = widget.employee.contractType == type;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isSelected ? Colors.blue[50] : null,
                      child: ListTile(
                        dense: isMobile,
                        leading: Icon(
                          _getContractTypeIcon(type),
                          color: isSelected ? Colors.blue : Colors.grey[600],
                          size: isMobile ? 20 : 24,
                        ),
                        title: Text(
                          type,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue[800] : null,
                          ),
                        ),
                        subtitle: Text(
                          _getContractTypeDescription(type),
                          style: TextStyle(fontSize: isMobile ? 11 : 12),
                        ),
                        trailing: isSelected 
                          ? Icon(Icons.check_circle, color: Colors.blue, size: isMobile ? 18 : 20)
                          : null,
                        onTap: () => Navigator.of(context).pop(type),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        widget.employee.contractType = result;
      });
      widget.onEmployeeUpdated?.call();
      
      // Show template download dialog
      await _showTemplateDownloadDialog(result);
    }
  }

  Future<void> _showTemplateDownloadDialog(String contractType) async {
    final isMobile = ResponsiveHelper.isMobile(context);
    final templateUrl = _getContractTemplateUrl(contractType);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.download, color: Colors.blue, size: isMobile ? 20 : 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Download Template',
                  style: TextStyle(fontSize: isMobile ? 16 : 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? 280 : 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contract Type: $contractType',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: isMobile ? 16 : 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Next Steps:',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Click "Download Template" below\n'
                        '2. The contract template will download/open automatically\n'
                        '3. Fill it out with employee details\n'
                        '4. Save/Export as PDF\n'
                        '5. Return here and click upload (📄) to import it',
                        style: TextStyle(fontSize: isMobile ? 12 : 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.link, size: isMobile ? 14 : 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          templateUrl,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey[700],
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download Template'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      // Import url_launcher dynamically
      try {
        await _launchUrl(templateUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open browser. Please visit: $templateUrl'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  // Copy to clipboard functionality would go here
                },
              ),
            ),
          );
        }
      }
    }
  }

  String _getContractTemplateUrl(String contractType) {
    // Direct links to Irish employment contract templates and resources
    switch (contractType) {
      case 'Full-Time Permanent':
      case 'Part-Time Permanent':
      case 'Fixed-Term Contract':
        // Direct link to Sample Terms of Employment template (Word format)
        return 'https://www.workplacerelations.ie/en/what_you_should_know/employer-obligations/terms-of-employment/sample-statements-of-terms-of-employment.docx';
      case 'Casual/Temporary':
        return 'https://www.workplacerelations.ie/en/publications_forms/guides_booklets/';
      case 'Apprenticeship':
        return 'https://www.apprenticeship.ie/';
      case 'Agency Worker':
        return 'https://www.citizensinformation.ie/en/employment/types-of-employment/';
      default:
        return 'https://www.workplacerelations.ie/en/what_you_should_know/employer-obligations/terms-of-employment/sample-statements-of-terms-of-employment.docx';
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      if (kIsWeb) {
        // For web platform, open in new tab
        html.window.open(urlString, '_blank');
      } else {
        // For other platforms, show the URL
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Template URL'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please open this URL in your browser:'),
                  const SizedBox(height: 16),
                  SelectableText(
                    urlString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
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
      }
    } catch (e) {
      // Fallback: show URL in dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Template URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please open this URL in your browser:'),
                const SizedBox(height: 16),
                SelectableText(
                  urlString,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
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
    }
  }

  IconData _getContractTypeIcon(String type) {
    switch (type) {
      case 'Full-Time Permanent':
        return Icons.work;
      case 'Part-Time Permanent':
        return Icons.work_outline;
      case 'Fixed-Term Contract':
        return Icons.event_note;
      case 'Casual/Temporary':
        return Icons.schedule;
      case 'Apprenticeship':
        return Icons.school;
      case 'Agency Worker':
        return Icons.business_center;
      default:
        return Icons.work;
    }
  }

  String _getContractTypeDescription(String type) {
    switch (type) {
      case 'Full-Time Permanent':
        return 'Standard 35-40 hours/week, ongoing employment';
      case 'Part-Time Permanent':
        return 'Less than 35 hours/week, ongoing employment';
      case 'Fixed-Term Contract':
        return 'Temporary position with specified end date';
      case 'Casual/Temporary':
        return 'Irregular hours, as-needed basis';
      case 'Apprenticeship':
        return 'Training contract with education component';
      case 'Agency Worker':
        return 'Employed through recruitment agency';
      default:
        return '';
    }
  }

  Future<void> _showNumberEditDialog({
    required String title,
    required double initialValue,
    required ValueChanged<double> onSaved,
    bool isBaseHours = false,
    bool isHolidayHours = false,
  }) async {
    final controller = TextEditingController(text: initialValue.toStringAsFixed(2));
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
                      helperText: isHolidayHours ? 'Total available holiday hours (will subtract automatically when used)' : null,
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

    // After saving, offer to apply to future weeks (only for base hours, not holiday hours)
    if (isBaseHours) {
      _showApplyForwardDialog(title, isBaseHours);
    }
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

  List<String> _getUniqueDocumentCategories() {
    final categories = <String>{};
    for (final doc in widget.employee.documents) {
      categories.add(doc.category);
    }
    return categories.toList()..sort();
  }

  Widget _buildCategoryBadge(String category, bool isMobile) {
    IconData icon;
    Color color;
    
    switch (category) {
      case 'Training':
        icon = Icons.school;
        color = Colors.blue;
        break;
      case 'Medical':
        icon = Icons.medical_services;
        color = Colors.red;
        break;
      case 'Contract':
        icon = Icons.description;
        color = Colors.green;
        break;
      case 'Identification':
        icon = Icons.badge;
        color = Colors.purple;
        break;
      case 'Certification':
        icon = Icons.verified;
        color = Colors.orange;
        break;
      case 'Right to Work':
        icon = Icons.verified_user;
        color = Colors.teal;
        break;
      case 'PPS Number':
        icon = Icons.numbers;
        color = Colors.indigo;
        break;
      case 'Tax Declaration':
        icon = Icons.receipt;
        color = Colors.amber;
        break;
      case 'Health & Safety':
        icon = Icons.security;
        color = Colors.pink;
        break;
      case 'Induction':
        icon = Icons.assignment;
        color = Colors.cyan;
        break;
      case 'Sick Leave':
        icon = Icons.sick;
        color = Colors.red;
        break;
      case 'Parental Leave':
        icon = Icons.child_care;
        color = Colors.lime;
        break;
      case 'Vaccination Records':
        icon = Icons.favorite;
        color = Colors.deepOrange;
        break;
      case 'Garda Vetting':
        icon = Icons.verified_user;
        color = Colors.blueGrey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    final docCount = widget.employee.documents.where((doc) => doc.category == category).length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isMobile ? 14 : 16, color: color),
          SizedBox(width: isMobile ? 4 : 6),
          Text(
            '$category ($docCount)',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  // Converts TimeOfDay to a 24-hour formatted string (e.g., "14:30").
  String format24Hour() {
    final hour = this.hour.toString().padLeft(2, '0');
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Parses a 24-hour formatted string (nullable-safe).
  static TimeOfDay? from24Hour(String? time) {
    if (time == null) return null;
    final reg = RegExp(r'^\d{2}:\d{2}$');
    if (!reg.hasMatch(time)) return null;
    final parts = time.split(':');
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}
