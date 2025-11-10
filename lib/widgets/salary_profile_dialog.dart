import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../theme/app_theme.dart';

class SalaryProfileDialog extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final SalaryProfile? existingProfile;

  const SalaryProfileDialog({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.existingProfile,
  });

  @override
  State<SalaryProfileDialog> createState() => _SalaryProfileDialogState();
}

class _SalaryProfileDialogState extends State<SalaryProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _baseSalaryController = TextEditingController();
  final _sundayBonusController = TextEditingController();
  final _bankHolidayBonusController = TextEditingController();
  final _christmasBonusController = TextEditingController();

  bool _useGlobalDefaults = true;
  GlobalSalarySettings? _globalSettings;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _globalSettings = await SalaryService.loadGlobalSettings();
    
    if (widget.existingProfile != null) {
      final profile = widget.existingProfile!;
      _baseSalaryController.text = profile.baseSalaryPerHour.toString();
      _sundayBonusController.text = profile.sundayBonusPercentage.toString();
      _bankHolidayBonusController.text = profile.bankHolidayBonusPercentage.toString();
      _christmasBonusController.text = profile.christmasBonusPercentage.toString();
      _useGlobalDefaults = false;
    } else if (_globalSettings != null) {
      _sundayBonusController.text = _globalSettings!.defaultSundayBonusPercentage.toString();
      _bankHolidayBonusController.text = _globalSettings!.defaultBankHolidayBonusPercentage.toString();
      _christmasBonusController.text = _globalSettings!.defaultChristmasBonusPercentage.toString();
    }
    
    setState(() {});
  }

  void _toggleGlobalDefaults(bool? value) {
    setState(() {
      _useGlobalDefaults = value ?? false;
      if (_useGlobalDefaults && _globalSettings != null) {
        _sundayBonusController.text = _globalSettings!.defaultSundayBonusPercentage.toString();
        _bankHolidayBonusController.text = _globalSettings!.defaultBankHolidayBonusPercentage.toString();
        _christmasBonusController.text = _globalSettings!.defaultChristmasBonusPercentage.toString();
      }
    });
  }

  Future<void> _saveSalaryProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = SalaryProfile(
      employeeId: widget.employeeId,
      baseSalaryPerHour: double.parse(_baseSalaryController.text),
      sundayBonusPercentage: double.parse(_sundayBonusController.text),
      bankHolidayBonusPercentage: double.parse(_bankHolidayBonusController.text),
      christmasBonusPercentage: double.parse(_christmasBonusController.text),
    );

    await SalaryService.saveSalaryProfile(profile);
    
    if (mounted) {
      Navigator.of(context).pop(profile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salary profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _baseSalaryController.dispose();
    _sundayBonusController.dispose();
    _bankHolidayBonusController.dispose();
    _christmasBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.attach_money, color: Colors.green.shade700),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Salary Profile',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.employeeName,
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
              
              // Base Salary
              TextFormField(
                controller: _baseSalaryController,
                decoration: const InputDecoration(
                  labelText: 'Base Salary per Hour (€)',
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(),
                  helperText: 'Base hourly rate before bonuses',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter base salary';
                  }
                  final salary = double.tryParse(value);
                  if (salary == null || salary <= 0) {
                    return 'Please enter a valid salary amount';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Use Global Defaults Toggle
              Row(
                children: [
                  Checkbox(
                    value: _useGlobalDefaults,
                    onChanged: _toggleGlobalDefaults,
                  ),
                  const Text('Use global bonus defaults'),
                  const Spacer(),
                  if (_globalSettings != null)
                    TextButton.icon(
                      onPressed: () => _showGlobalSettingsInfo(context),
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('View defaults'),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Bonus Percentages
              Text(
                'Bonus Percentages',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Sunday Bonus
              TextFormField(
                controller: _sundayBonusController,
                enabled: !_useGlobalDefaults,
                decoration: const InputDecoration(
                  labelText: 'Sunday Bonus (%)',
                  prefixIcon: Icon(Icons.weekend),
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final bonus = double.tryParse(value);
                  if (bonus == null || bonus < 0) return 'Invalid percentage';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Bank Holiday Bonus
              TextFormField(
                controller: _bankHolidayBonusController,
                enabled: !_useGlobalDefaults,
                decoration: const InputDecoration(
                  labelText: 'Bank Holiday Bonus (%)',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final bonus = double.tryParse(value);
                  if (bonus == null || bonus < 0) return 'Invalid percentage';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Christmas Bonus
              TextFormField(
                controller: _christmasBonusController,
                enabled: !_useGlobalDefaults,
                decoration: const InputDecoration(
                  labelText: 'Christmas Day Bonus (%)',
                  prefixIcon: Icon(Icons.celebration),
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final bonus = double.tryParse(value);
                  if (bonus == null || bonus < 0) return 'Invalid percentage';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveSalaryProfile,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGlobalSettingsInfo(BuildContext context) {
    if (_globalSettings == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Global Bonus Defaults'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingRow('Sunday Bonus', '${_globalSettings!.defaultSundayBonusPercentage}%'),
            _buildSettingRow('Bank Holiday Bonus', '${_globalSettings!.defaultBankHolidayBonusPercentage}%'),
            _buildSettingRow('Christmas Bonus', '${_globalSettings!.defaultChristmasBonusPercentage}%'),
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

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}