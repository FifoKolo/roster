import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/employee_model.dart';
import '../utils/responsive_helper.dart';

class AddShiftDialog extends StatefulWidget {
  final Shift? shift;

  const AddShiftDialog({super.key, this.shift});

  @override
  State<AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  bool _isFormattingTime = false;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isHoliday = false;
  late TextEditingController roleController;
  late TextEditingController commentController;
  late TextEditingController startTimeController;
  late TextEditingController endTimeController;
  late TextEditingController holidayHoursController;
  late TextEditingController customBreakController; // NEW: custom break time in minutes
  late FocusNode startTimeFocus;
  late FocusNode endTimeFocus;
  Color? selectedColor;
  bool use24HourFormat = true; // Default to 24-hour format
  bool? enablePaidBreak; // null means use global setting, true/false overrides

  String _calculateDuration(TimeOfDay start, TimeOfDay end) {
    double startHours = start.hour + start.minute / 60;
    double endHours = end.hour + end.minute / 60;
    
    // Handle shifts that go past midnight
    if (endHours < startHours) {
      endHours += 24;
    }
    
    double duration = endHours - startHours;
    return duration.toStringAsFixed(1);
  }

  String _formatTimeForDisplay(TimeOfDay? time) {
    if (time == null) return '';
    
    if (use24HourFormat) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '${hour12.toString()}:${time.minute.toString().padLeft(2, '0')} $period';
    }
  }

  TimeOfDay? _parseTimeInput(String input) {
    if (input.trim().isEmpty) return null;
    
    try {
      // Remove any spaces
      input = input.trim();
      
      // Check if it's 12-hour format (contains AM/PM)
      bool isAMPM = input.toUpperCase().contains('AM') || input.toUpperCase().contains('PM');
      
      if (isAMPM) {
        // Parse 12-hour format
        final isPM = input.toUpperCase().contains('PM');
        final timeStr = input.toUpperCase().replaceAll(RegExp(r'[AP]M'), '').trim();
        final parts = timeStr.split(':');
        
        if (parts.length != 2) return null;
        
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        
        // Convert to 24-hour format
        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }
        
        if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      } else {
        // Parse 24-hour format or simple format
        final parts = input.split(':');
        if (parts.length != 2) return null;
        
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1]);
        
        if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (e) {
      return null;
    }
    
    return null;
  }

  void _updateTimeFromInput(String input, bool isStartTime) {
    if (_isFormattingTime) return;

    final controller = isStartTime ? startTimeController : endTimeController;

    // Normalize to digits only and rebuild with colon after HH
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    String formatted;
    if (limited.length >= 3) {
      formatted = '${limited.substring(0, 2)}:${limited.substring(2)}';
    } else {
      formatted = limited;
    }

    // If end time is being cleared, hop focus back to start time for quick re-entry
    if (!isStartTime && formatted.isEmpty) {
      _isFormattingTime = true;
      controller.clear();
      _isFormattingTime = false;
      setState(() => endTime = null);
      Future.delayed(const Duration(milliseconds: 80), () {
        startTimeFocus.requestFocus();
      });
      return;
    }

    _isFormattingTime = true;
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _isFormattingTime = false;

    // Auto-advance: when user completes time format, move focus
    if (formatted.length >= 5 && formatted.contains(':')) {
      final time = _parseTimeInput(formatted);
      if (time != null) {
        setState(() {
          if (isStartTime) {
            startTime = time;
            Future.delayed(const Duration(milliseconds: 100), () {
              endTimeFocus.requestFocus();
            });
          } else {
            endTime = time;
            Future.delayed(const Duration(milliseconds: 100), () {
              FocusScope.of(context).unfocus();
            });
          }
        });
      }
    } else {
      final time = _parseTimeInput(formatted);
      if (time != null) {
        setState(() {
          if (isStartTime) {
            startTime = time;
          } else {
            endTime = time;
          }
        });
      }
    }
  }

  bool _isStartBeforeEnd(TimeOfDay a, TimeOfDay b) {
    final ai = a.hour * 60 + a.minute;
    final bi = b.hour * 60 + b.minute;
    return ai < bi;
  }

  @override
  void initState() {
    super.initState();
    startTime = widget.shift?.startTime;
    endTime = widget.shift?.endTime;
    isHoliday = widget.shift?.isHoliday ?? false;
    selectedColor = widget.shift?.customColor;
    enablePaidBreak = widget.shift?.enablePaidBreak; // null means use global setting

    roleController = TextEditingController(text: widget.shift?.role ?? '');
    commentController = TextEditingController(text: widget.shift?.comment ?? '');
    startTimeController = TextEditingController(text: _formatTimeForDisplay(startTime));
    endTimeController = TextEditingController(text: _formatTimeForDisplay(endTime));
    holidayHoursController = TextEditingController(text: widget.shift?.customHolidayHours?.toString() ?? '8.0');
    customBreakController = TextEditingController(text: widget.shift?.customBreakMinutes?.toString() ?? ''); // NEW
    
    // Initialize focus nodes
    startTimeFocus = FocusNode();
    endTimeFocus = FocusNode();

    // Keep cursor at end on focus so the whole time is not highlighted
    startTimeFocus.addListener(() {
      if (startTimeFocus.hasFocus) {
        final text = startTimeController.text;
        startTimeController.selection =
            TextSelection.collapsed(offset: text.length);
      }
    });

    endTimeFocus.addListener(() {
      if (endTimeFocus.hasFocus) {
        final text = endTimeController.text;
        endTimeController.selection =
            TextSelection.collapsed(offset: text.length);
      }
    });

    // Update UI validation state when text changes
    roleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    roleController.dispose();
    commentController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    holidayHoursController.dispose();
    customBreakController.dispose(); // NEW
    startTimeFocus.dispose();
    endTimeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = isHoliday ||
        (startTime != null &&
            endTime != null &&
            _isStartBeforeEnd(startTime!, endTime!));

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = ResponsiveHelper.isMobile(context);
    final dialogWidth = isMobile ? screenWidth * 0.95 : 450.0;
    final maxDialogHeight = screenHeight * 0.85;

    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 8,
      insetPadding: isMobile 
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 24)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 16 : 12)),
      title: Container(
        padding: EdgeInsets.only(bottom: isMobile ? 12 : 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time, 
              color: Colors.blue.shade600,
              size: isMobile ? 20 : 24,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Text(
              'Add/Edit Shift',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isMobile ? 16 : 18,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: maxDialogHeight),
        padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Holiday toggle with clean styling
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 4, 
              vertical: isMobile ? 12 : 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Holiday',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                Transform.scale(
                  scale: isMobile ? 0.9 : 1.0,
                  child: Switch(
                    value: isHoliday,
                    onChanged: (value) => setState(() => isHoliday = value),
                    activeThumbColor: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          if (isHoliday) ...[
            // Holiday hours input field
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Holiday Hours',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 8),
                  TextField(
                    controller: holidayHoursController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '8.0',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade600),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 12, 
                        vertical: isMobile ? 16 : 14,
                      ),
                    ),
                    style: TextStyle(fontSize: isMobile ? 15 : 14),
                  ),
                  SizedBox(height: isMobile ? 6 : 4),
                  Text(
                    'Hours to deduct from accumulated holiday hours',
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 20 : 16),
          ],
          if (!isHoliday) ...[
            // Role field with clean styling
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role (Optional)',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 8),
                  TextField(
                    controller: roleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Manager, Server, Cook',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 14 : 12,
                        vertical: isMobile ? 16 : 16,
                      ),
                    ),
                    textInputAction: TextInputAction.next,
                    style: TextStyle(fontSize: isMobile ? 15 : 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            // Time selection with enhanced input options
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey.shade700, size: isMobile ? 18 : 20),
                          SizedBox(width: isMobile ? 6 : 8),
                          Text(
                            'Shift Times',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      // Format toggle
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                          vertical: isMobile ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  use24HourFormat = true;
                                  startTimeController.text = _formatTimeForDisplay(startTime);
                                  endTimeController.text = _formatTimeForDisplay(endTime);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 10 : 12,
                                  vertical: isMobile ? 5 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: use24HourFormat ? Colors.blue.shade600 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '24h',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: use24HourFormat ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isMobile ? 3 : 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  use24HourFormat = false;
                                  startTimeController.text = _formatTimeForDisplay(startTime);
                                  endTimeController.text = _formatTimeForDisplay(endTime);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 10 : 12,
                                  vertical: isMobile ? 5 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: !use24HourFormat ? Colors.blue.shade600 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'AM/PM',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: !use24HourFormat ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            TextField(
                              controller: startTimeController,
                              focusNode: startTimeFocus,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                hintText: use24HourFormat ? '09:00' : '9:00 AM',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.access_time, color: Colors.grey.shade600, size: isMobile ? 20 : 24),
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: startTime ?? TimeOfDay.now(),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        startTime = time;
                                        startTimeController.text = _formatTimeForDisplay(time);
                                      });
                                    }
                                  },
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 12,
                                  vertical: isMobile ? 14 : 16,
                                ),
                              ),
                              style: TextStyle(fontSize: isMobile ? 15 : 14),
                              onChanged: (value) {
                                _updateTimeFromInput(value, true);
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isMobile ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            TextField(
                              controller: endTimeController,
                              focusNode: endTimeFocus,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: use24HourFormat ? '17:00' : '5:00 PM',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.access_time, color: Colors.grey.shade600, size: isMobile ? 20 : 24),
                                  onPressed: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: endTime ?? TimeOfDay.now(),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        endTime = time;
                                        endTimeController.text = _formatTimeForDisplay(time);
                                      });
                                    }
                                  },
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isMobile ? 12 : 12,
                                  vertical: isMobile ? 14 : 16,
                                ),
                              ),
                              style: TextStyle(fontSize: isMobile ? 15 : 14),
                              onChanged: (value) {
                                _updateTimeFromInput(value, false);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 10 : 12),
                  // Format examples
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: isMobile ? 12 : 14, color: Colors.blue.shade700),
                        SizedBox(width: isMobile ? 4 : 6),
                        Expanded(
                          child: Text(
                            use24HourFormat 
                                ? 'Format: 24-hour (e.g., 09:00, 14:30, 23:45)'
                                : 'Format: 12-hour (e.g., 9:00 AM, 2:30 PM, 11:45 PM)',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (startTime != null && endTime != null) ...[
                    SizedBox(height: isMobile ? 12 : 16),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: isMobile ? 14 : 16, color: Colors.green.shade700),
                          SizedBox(width: isMobile ? 6 : 8),
                          Text(
                            'Duration: ${_calculateDuration(startTime!, endTime!)} hours',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            // Comment field with clean styling
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comment (Optional)',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'Add any notes about this shift...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 12,
                        vertical: isMobile ? 14 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isMobile ? 14 : 14),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            
            // Custom Break Time - only show for non-holiday shifts
            if (!isHoliday)
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom Break Time (Optional)',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    TextField(
                      controller: customBreakController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'e.g., 30 for 30 minutes',
                        suffixText: 'min',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 12,
                          vertical: isMobile ? 14 : 16,
                        ),
                      ),
                      style: TextStyle(fontSize: isMobile ? 15 : 14),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      'Leave empty to use automatic break calculation',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: isMobile ? 12 : 16),
            
            // Paid Break Toggle - only show for non-holiday shifts
            if (!isHoliday)
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paid Break Setting',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: isMobile ? 14 : 16, color: Colors.indigo.shade600),
                              SizedBox(width: isMobile ? 6 : 8),
                              Expanded(
                                child: Text(
                                  'Automatic: 4.5hrs = 15min • 6hrs+ = 30min',
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: Colors.indigo.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          Row(
                            children: [
                              Transform.scale(
                                scale: isMobile ? 0.9 : 1.0,
                                child: Radio<bool?>(
                                  value: null,
                                  groupValue: enablePaidBreak,
                                  onChanged: (value) {
                                    setState(() {
                                      enablePaidBreak = value;
                                    });
                                  },
                                  activeColor: Colors.indigo,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      enablePaidBreak = null;
                                    });
                                  },
                                  child: Text(
                                    'Use Global Setting',
                                    style: TextStyle(
                                      fontSize: isMobile ? 13 : 14,
                                      color: Colors.indigo.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Transform.scale(
                                scale: isMobile ? 0.9 : 1.0,
                                child: Radio<bool?>(
                                  value: true,
                                  groupValue: enablePaidBreak,
                                  onChanged: (value) {
                                    setState(() {
                                      enablePaidBreak = value;
                                    });
                                  },
                                  activeColor: Colors.green,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      enablePaidBreak = true;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, size: isMobile ? 14 : 16, color: Colors.green.shade600),
                                      SizedBox(width: isMobile ? 3 : 4),
                                      Expanded(
                                        child: Text(
                                          'Enable Break for This Shift',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Transform.scale(
                                scale: isMobile ? 0.9 : 1.0,
                                child: Radio<bool?>(
                                  value: false,
                                  groupValue: enablePaidBreak,
                                  onChanged: (value) {
                                    setState(() {
                                      enablePaidBreak = value;
                                    });
                                  },
                                  activeColor: Colors.orange,
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      enablePaidBreak = false;
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Icon(Icons.cancel, size: isMobile ? 14 : 16, color: Colors.orange.shade600),
                                      SizedBox(width: isMobile ? 3 : 4),
                                      Expanded(
                                        child: Text(
                                          'Disable Break for This Shift',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: isMobile ? 16 : 20),
            
            // Color picker with clean styling
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 4),
              child: Row(
                children: [
                  Container(
                    width: isMobile ? 28 : 32,
                    height: isMobile ? 28 : 32,
                    decoration: BoxDecoration(
                      color: selectedColor ?? Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  TextButton.icon(
                    icon: Icon(Icons.palette, color: Colors.blue.shade600, size: isMobile ? 18 : 20),
                    label: Text(
                      'Pick color',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.blue.shade600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 8 : 10,
                      ),
                    ),
                    onPressed: () async {
                    final c = await _pickColor(context, selectedColor);
                    if (c != null) setState(() => selectedColor = c);
                  },
                ),
                if (selectedColor != null)
                  TextButton(
                    onPressed: () => setState(() => selectedColor = null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 8 : 10,
                      ),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isHoliday &&
              startTime != null &&
              endTime != null &&
              !_isStartBeforeEnd(startTime!, endTime!))
            Padding(
              padding: EdgeInsets.only(top: isMobile ? 12 : 16),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: isMobile ? 14 : 16),
                    SizedBox(width: isMobile ? 6 : 8),
                    Expanded(
                      child: Text(
                        'End time must be after start time.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ), // Column closing
      ), // SingleChildScrollView closing
      ), // Container closing
      actions: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 20,
                    vertical: isMobile ? 10 : 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: isMobile ? 6 : 8),
              ElevatedButton(
                onPressed: canSave
                    ? () {
                        Navigator.pop(
                          context,
                          Shift(
                            startTime: isHoliday ? null : startTime,
                            endTime: isHoliday ? null : endTime,
                            role: isHoliday ? null : roleController.text.trim(),
                            comment: commentController.text.trim().isEmpty
                                ? null
                                : commentController.text.trim(),
                            isHoliday: isHoliday,
                            customColor: selectedColor,
                            customHolidayHours: isHoliday 
                                ? (double.tryParse(holidayHoursController.text) ?? 8.0)
                                : null,
                            enablePaidBreak: enablePaidBreak,
                            customBreakMinutes: customBreakController.text.trim().isEmpty
                                ? null
                                : double.tryParse(customBreakController.text),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave ? Colors.blue.shade600 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Save',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color? initial) async {
    final presets = <Color>[
      Colors.white,
      Colors.grey.shade200,
      Colors.grey.shade400,
      Colors.red.shade100,
      Colors.red.shade300,
      Colors.orange.shade100,
      Colors.orange.shade300,
      Colors.amber.shade100,
      Colors.amber.shade300,
      Colors.yellow.shade100,
      Colors.yellow.shade300,
      Colors.green.shade100,
      Colors.green.shade300,
      Colors.teal.shade100,
      Colors.teal.shade300,
      Colors.blue.shade100,
      Colors.blue.shade300,
      Colors.indigo.shade100,
      Colors.indigo.shade300,
      Colors.purple.shade100,
      Colors.purple.shade300,
      Colors.pink.shade100,
      Colors.pink.shade300,
    ];
    Color? selected = initial;
    return showDialog<Color?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select color'),
        content: SizedBox(
          width: 320,
          height: 220,
          child: StatefulBuilder(
            builder: (context, setStateColor) => GridView.count(
              crossAxisCount: 6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: presets.map((c) {
                final isSel = selected?.value == c.value;
                return InkWell(
                  onTap: () => setStateColor(() => selected = c),
                  onDoubleTap: () => Navigator.pop(context, c),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c,
                      border: Border.all(
                        color: isSel ? Colors.black : Colors.grey.shade400,
                        width: isSel ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }
}

// AddShiftDialog:
// - Presents inputs to edit a single Shift: start time, end time, role, comment, holiday flag.
// - Uses showTimePicker for picking times.
// - On Save returns a Shift object (or null if cancelled).
// - Caller should persist the returned Shift into the employee's shifts map and save roster.
//
// UX tip: If you set isHoliday the dialog returns a Shift with isHoliday=true and null times.
