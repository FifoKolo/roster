import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/salary_model.dart';
import '../services/salary_service.dart';
import '../theme/app_theme.dart';

class GlobalSalarySettingsDialog extends StatefulWidget {
  const GlobalSalarySettingsDialog({super.key});

  @override
  State<GlobalSalarySettingsDialog> createState() => _GlobalSalarySettingsDialogState();
}

class _GlobalSalarySettingsDialogState extends State<GlobalSalarySettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _sundayBonusController = TextEditingController();
  final _bankHolidayBonusController = TextEditingController();
  final _christmasBonusController = TextEditingController();

  GlobalSalarySettings? _currentSettings;
  bool _enableIrishBankHolidayEntitlement = true;
  bool _enableAutomaticBreaks = true;
  String _breakBehavior = 'per_shift_toggle';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _currentSettings = await SalaryService.loadGlobalSettings();
    
    _sundayBonusController.text = _currentSettings!.defaultSundayBonusPercentage.toString();
    _bankHolidayBonusController.text = _currentSettings!.defaultBankHolidayBonusPercentage.toString();
    _christmasBonusController.text = _currentSettings!.defaultChristmasBonusPercentage.toString();
    _enableIrishBankHolidayEntitlement = _currentSettings!.enableIrishBankHolidayEntitlement;
    _enableAutomaticBreaks = _currentSettings!.enableAutomaticBreaks;
    _breakBehavior = _currentSettings!.breakBehavior;
    
    setState(() {});
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final settings = GlobalSalarySettings(
      defaultSundayBonusPercentage: double.parse(_sundayBonusController.text),
      defaultBankHolidayBonusPercentage: double.parse(_bankHolidayBonusController.text),
      defaultChristmasBonusPercentage: double.parse(_christmasBonusController.text),
      defaultPaidBreakMinutesPerShift: 30.0, // Use default since breaks are automatic
      enableIrishBankHolidayEntitlement: _enableIrishBankHolidayEntitlement,
      enableAutomaticBreaks: _enableAutomaticBreaks,
      breakBehavior: _breakBehavior,
    );

    await SalaryService.saveGlobalSettings(settings);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Global settings saved successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _resetToDefaults() {
    setState(() {
      _sundayBonusController.text = '25';
      _bankHolidayBonusController.text = '50';
      _christmasBonusController.text = '100';
      _enableIrishBankHolidayEntitlement = true;
      _enableAutomaticBreaks = true;
      _breakBehavior = 'per_shift_toggle';
    });
  }

  @override
  void dispose() {
    _sundayBonusController.dispose();
    _bankHolidayBonusController.dispose();
    _christmasBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: screenHeight * 0.75, // Reduced to 75% for more margin
        ),
        child: Container(
          decoration: AppTheme.elevatedCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with new theme
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryIndigoBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.radiusXl),
                    topRight: Radius.circular(AppTheme.radiusXl),
                  ),
                ),
                child: Row(
                  children: [
                    AppTheme.iconContainer(
                      icon: Icons.settings,
                      backgroundColor: AppTheme.secondaryIndigo,
                      iconColor: AppTheme.textInverse,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Global Salary Settings',
                          style: AppTheme.titleLarge.copyWith(
                            color: AppTheme.secondaryIndigo,
                          ),
                        ),
                        Text(
                          'Default bonus percentages for all employees',
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Scrollable Content with new theme
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingSm),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Notice with new theme
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSm),
                        decoration: BoxDecoration(
                          color: AppTheme.infoLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            AppTheme.iconContainer(
                              icon: Icons.info,
                              backgroundColor: AppTheme.info.withOpacity(0.1),
                              iconColor: AppTheme.info,
                              size: 18,
                              padding: 4,
                            ),
                            const SizedBox(width: AppTheme.spacingSm),
                            Expanded(
                              child: Text(
                                'These settings will be used as defaults when creating new salary profiles for employees.',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.info,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingSm),

                      // Break Behavior Section
                      _buildBreakBehaviorSection(),
                      
                      const SizedBox(height: AppTheme.spacingSm),

                      // Bonus Settings
                      _buildBonusSection(),

                      const SizedBox(height: AppTheme.spacingSm),

                      // Irish Employment Law Section
                      _buildIrishLawSection(),

                      const SizedBox(height: AppTheme.spacingSm),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons with new theme
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: AppTheme.backgroundSecondary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppTheme.radiusXl),
                  bottomRight: Radius.circular(AppTheme.radiusXl),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.borderPrimary),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _resetToDefaults,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset to Defaults'),
                      style: AppTheme.warningButtonStyle.copyWith(
                        backgroundColor: WidgetStateProperty.all(AppTheme.warningBackground),
                        foregroundColor: WidgetStateProperty.all(AppTheme.warning),
                        elevation: WidgetStateProperty.all(0),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: AppTheme.secondaryButtonStyle.copyWith(
                            backgroundColor: WidgetStateProperty.all(Colors.transparent),
                            side: WidgetStateProperty.all(BorderSide.none),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Settings'),
                          style: AppTheme.successButtonStyle,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildBreakBehaviorSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.secondaryIndigoBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.secondaryIndigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTheme.iconContainer(
                icon: Icons.schedule,
                backgroundColor: AppTheme.secondaryIndigo,
                iconColor: AppTheme.textInverse,
                size: 16,
                padding: 6,
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Text(
                'Break Behavior',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.secondaryIndigo,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          
          // Always Calculate Breaks
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: _breakBehavior == 'always_on' 
                ? AppTheme.secondaryIndigoLight.withOpacity(0.2)
                : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _breakBehavior == 'always_on' 
                  ? AppTheme.secondaryIndigo
                  : AppTheme.borderPrimary,
                width: _breakBehavior == 'always_on' ? 2 : 1,
              ),
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  AppTheme.iconContainer(
                    icon: Icons.check_circle,
                    backgroundColor: AppTheme.success.withOpacity(0.1),
                    iconColor: AppTheme.success,
                    size: 14,
                    padding: 4,
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text('Always Calculate Breaks', style: AppTheme.titleSmall.copyWith(fontSize: 12)),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  'All eligible shifts get automatic breaks',
                  style: AppTheme.bodySmall.copyWith(fontSize: 10),
                ),
              ),
              value: 'always_on',
              groupValue: _breakBehavior,
              onChanged: (value) {
                setState(() {
                  _breakBehavior = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingSm),
          
          // Never Calculate Breaks
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: _breakBehavior == 'always_off'
                ? AppTheme.secondaryIndigoLight.withOpacity(0.2)
                : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _breakBehavior == 'always_off'
                  ? AppTheme.secondaryIndigo
                  : AppTheme.borderPrimary,
                width: _breakBehavior == 'always_off' ? 2 : 1,
              ),
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  AppTheme.iconContainer(
                    icon: Icons.cancel,
                    backgroundColor: AppTheme.error.withOpacity(0.1),
                    iconColor: AppTheme.error,
                    size: 16,
                    padding: 6,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Text('Never Calculate Breaks', style: AppTheme.titleSmall),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  'No automatic breaks for any shifts',
                  style: AppTheme.bodySmall,
                ),
              ),
              value: 'always_off',
              groupValue: _breakBehavior,
              onChanged: (value) {
                setState(() {
                  _breakBehavior = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingSm),
          
          // Per-Shift Toggle (Recommended)
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: _breakBehavior == 'per_shift_toggle'
                ? AppTheme.secondaryIndigoLight.withOpacity(0.2)
                : AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _breakBehavior == 'per_shift_toggle'
                  ? AppTheme.secondaryIndigo
                  : AppTheme.borderPrimary,
                width: _breakBehavior == 'per_shift_toggle' ? 2 : 1,
              ),
            ),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  AppTheme.iconContainer(
                    icon: Icons.tune,
                    backgroundColor: AppTheme.accentTeal.withOpacity(0.1),
                    iconColor: AppTheme.accentTeal,
                    size: 16,
                    padding: 6,
                  ),
                  const SizedBox(width: AppTheme.spacingMd),
                  Text('Per-Shift Toggle (Recommended)', style: AppTheme.titleSmall),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  'Allow individual shift break control',
                  style: AppTheme.bodySmall,
                ),
              ),
              value: 'per_shift_toggle',
              groupValue: _breakBehavior,
              onChanged: (value) {
                setState(() {
                  _breakBehavior = value!;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBonusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sunday Bonus
        _buildPercentageField(
          'Default Sunday Bonus (%)',
          _sundayBonusController,
          'Additional percentage for Sunday shifts',
          Icons.weekend,
        ),
        
        const SizedBox(height: AppTheme.spacingSm),
        
        // Bank Holiday Bonus
        _buildPercentageField(
          'Default Bank Holiday Bonus (%)',
          _bankHolidayBonusController,
          'Additional percentage for bank holiday shifts',
          Icons.flag,
        ),
        
        const SizedBox(height: AppTheme.spacingSm),
        
        // Christmas Bonus
        _buildPercentageField(
          'Default Christmas Day Bonus (%)',
          _christmasBonusController,
          'Additional percentage for Christmas Day shifts',
          Icons.celebration,
        ),
      ],
    );
  }

  Widget _buildIrishLawSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.successBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppTheme.successIconContainer(
                icon: Icons.gavel,
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Text(
                'Irish Employment Law',
                style: AppTheme.titleMedium.copyWith(
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                AppTheme.iconContainer(
                  icon: Icons.info_outline,
                  backgroundColor: AppTheme.info.withOpacity(0.1),
                  iconColor: AppTheme.info,
                  size: 18,
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    'Staff get paid 1/5th of previous week\'s hours when not working on bank holidays',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPercentageField(String label, TextEditingController controller, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppTheme.iconContainer(
              icon: icon,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              iconColor: AppTheme.primaryBlue,
              size: 18,
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Text(
              label,
              style: AppTheme.titleSmall.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        TextFormField(
          controller: controller,
          decoration: AppTheme.inputDecoration(
            hint: hint,
            suffixText: '%',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a percentage';
            }
            final percentage = double.tryParse(value);
            if (percentage == null) {
              return 'Please enter a valid number';
            }
            if (percentage < 0 || percentage > 200) {
              return 'Percentage must be between 0 and 200';
            }
            return null;
          },
        ),
      ],
    );
  }
}