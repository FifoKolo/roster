import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../utils/responsive_helper.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = ResponsiveHelper.isMobile(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(isMobile ? 12 : 40),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 500,
        constraints: BoxConstraints(
          maxHeight: isMobile ? screenHeight * 0.9 : double.infinity,
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: SingleChildScrollView(
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
                      padding: EdgeInsets.all(isMobile ? 6 : 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.attach_money, 
                        color: Colors.green.shade700,
                        size: isMobile ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary Profile',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.employeeName,
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
                
                SizedBox(height: isMobile ? 16 : 24),                // Base Salary
                TextFormField(
                  controller: _baseSalaryController,
                  decoration: InputDecoration(
                    labelText: 'Base Salary per Hour (€)',
                    labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                    prefixIcon: Icon(Icons.euro, size: isMobile ? 20 : 24),
                    border: const OutlineInputBorder(),
                    helperText: 'Base hourly rate before bonuses',
                    helperStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 14 : 16,
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 15 : 16),
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

                SizedBox(height: isMobile ? 16 : 20),

                // Use Global Defaults Toggle
                Row(
                  children: [
                    Transform.scale(
                      scale: isMobile ? 0.9 : 1.0,
                      child: Checkbox(
                        value: _useGlobalDefaults,
                        onChanged: _toggleGlobalDefaults,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Use global bonus defaults',
                        style: TextStyle(fontSize: isMobile ? 14 : 16),
                      ),
                    ),
                    if (_globalSettings != null)
                      TextButton.icon(
                        onPressed: () => _showGlobalSettingsInfo(context),
                        icon: Icon(Icons.info_outline, size: isMobile ? 14 : 16),
                        label: Text(
                          'View defaults',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 8 : 12,
                            vertical: isMobile ? 6 : 8,
                          ),
                        ),
                      ),
                  ],
                ),

                SizedBox(height: isMobile ? 12 : 16),

                // Bonus Percentages
                Text(
                  'Bonus Percentages',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isMobile ? 10 : 12),

                // Sunday Bonus
                TextFormField(
                  controller: _sundayBonusController,
                  enabled: !_useGlobalDefaults,
                  decoration: InputDecoration(
                    labelText: 'Sunday Bonus (%)',
                    labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                    prefixIcon: Icon(Icons.weekend, size: isMobile ? 20 : 24),
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 14 : 16,
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 15 : 16),
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

                SizedBox(height: isMobile ? 14 : 12),

                // Bank Holiday Bonus
                TextFormField(
                  controller: _bankHolidayBonusController,
                  enabled: !_useGlobalDefaults,
                  decoration: InputDecoration(
                    labelText: 'Bank Holiday Bonus (%)',
                    labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                    prefixIcon: Icon(Icons.event, size: isMobile ? 20 : 24),
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 14 : 16,
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 15 : 16),
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

                SizedBox(height: isMobile ? 14 : 12),

                // Christmas Bonus
                TextFormField(
                  controller: _christmasBonusController,
                  enabled: !_useGlobalDefaults,
                  decoration: InputDecoration(
                    labelText: 'Christmas Day Bonus (%)',
                    labelStyle: TextStyle(fontSize: isMobile ? 14 : 16),
                    prefixIcon: Icon(Icons.celebration, size: isMobile ? 20 : 24),
                    border: const OutlineInputBorder(),
                    suffixText: '%',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 14 : 16,
                    ),
                  ),
                  style: TextStyle(fontSize: isMobile ? 15 : 16),
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

                SizedBox(height: isMobile ? 18 : 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 10 : 12,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: isMobile ? 14 : 15),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    ElevatedButton.icon(
                      onPressed: _saveSalaryProfile,
                      icon: Icon(Icons.save, size: isMobile ? 18 : 20),
                      label: Text(
                        'Save Profile',
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
                ),
              ],
            ),
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