import 'package:flutter/material.dart';
import '../models/employee_model.dart';

class AddShiftDialog extends StatefulWidget {
  final Shift? shift;

  const AddShiftDialog({super.key, this.shift});

  @override
  State<AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  bool isHoliday = false;
  late TextEditingController roleController;
  late TextEditingController commentController;
  late TextEditingController startTimeController;
  late TextEditingController endTimeController;
  late TextEditingController holidayHoursController;
  late FocusNode startTimeFocus;
  late FocusNode endTimeFocus;
  Color? selectedColor;
  bool use24HourFormat = true; // Default to 24-hour format

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
    // Auto-format: add colon when user types 2 digits
    if (input.length == 2 && !input.contains(':')) {
      final controller = isStartTime ? startTimeController : endTimeController;
      final formattedInput = input + ':';
      controller.value = TextEditingValue(
        text: formattedInput,
        selection: TextSelection.collapsed(offset: formattedInput.length),
      );
      return; // Don't parse yet, let user finish typing
    }
    
    // Auto-advance: when user completes time format, move to next field
    if (input.length >= 5 && input.contains(':')) {
      final time = _parseTimeInput(input);
      if (time != null) {
        setState(() {
          if (isStartTime) {
            startTime = time;
            // Auto-focus to end time field
            Future.delayed(const Duration(milliseconds: 100), () {
              endTimeFocus.requestFocus();
            });
          } else {
            endTime = time;
            // Auto-focus away from time fields when both are complete
            Future.delayed(const Duration(milliseconds: 100), () {
              FocusScope.of(context).unfocus();
            });
          }
        });
      }
    } else {
      // Try to parse partial input
      final time = _parseTimeInput(input);
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

    roleController = TextEditingController(text: widget.shift?.role ?? '');
    commentController = TextEditingController(text: widget.shift?.comment ?? '');
    startTimeController = TextEditingController(text: _formatTimeForDisplay(startTime));
    endTimeController = TextEditingController(text: _formatTimeForDisplay(endTime));
    holidayHoursController = TextEditingController(text: widget.shift?.customHolidayHours?.toString() ?? '8.0');
    
    // Initialize focus nodes
    startTimeFocus = FocusNode();
    endTimeFocus = FocusNode();

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

    return AlertDialog(
      backgroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text(
              'Add/Edit Shift',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600), // Add height constraint
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SingleChildScrollView( // Make content scrollable
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Holiday toggle with clean styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Holiday',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
                Switch(
                  value: isHoliday,
                  onChanged: (value) => setState(() => isHoliday = value),
                  activeThumbColor: Colors.blue.shade600,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (isHoliday) ...[
            // Holiday hours input field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Holiday Hours',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hours to deduct from accumulated holiday hours',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!isHoliday) ...[
            // Role field with clean styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Role (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Time selection with enhanced input options
            Container(
              padding: const EdgeInsets.all(20),
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
                          Icon(Icons.access_time, color: Colors.grey.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Shift Times',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                      // Format toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: use24HourFormat ? Colors.blue.shade600 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '24h',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: use24HourFormat ? Colors.white : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  use24HourFormat = false;
                                  startTimeController.text = _formatTimeForDisplay(startTime);
                                  endTimeController.text = _formatTimeForDisplay(endTime);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: !use24HourFormat ? Colors.blue.shade600 : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'AM/PM',
                                  style: TextStyle(
                                    fontSize: 12,
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  icon: Icon(Icons.access_time, color: Colors.grey.shade600),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              onChanged: (value) {
                                _updateTimeFromInput(value, true);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
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
                                  icon: Icon(Icons.access_time, color: Colors.grey.shade600),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              ),
                              onChanged: (value) {
                                _updateTimeFromInput(value, false);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Format examples
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            use24HourFormat 
                                ? 'Format: 24-hour (e.g., 09:00, 14:30, 23:45)'
                                : 'Format: 12-hour (e.g., 9:00 AM, 2:30 PM, 11:45 PM)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (startTime != null && endTime != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Duration: ${_calculateDuration(startTime!, endTime!)} hours',
                            style: TextStyle(
                              fontSize: 14,
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
            const SizedBox(height: 8),
            // Comment field with clean styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comment (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Color picker with clean styling
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selectedColor ?? Colors.grey.shade100,
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: Icon(Icons.palette, color: Colors.blue.shade600),
                    label: Text(
                      'Pick color',
                      style: TextStyle(color: Colors.blue.shade600),
                    ),
                    onPressed: () async {
                    final c = await _pickColor(context, selectedColor);
                    if (c != null) setState(() => selectedColor = c);
                  },
                ),
                if (selectedColor != null)
                  TextButton(
                    onPressed: () => setState(() => selectedColor = null),
                    child: Text(
                      'Clear',
                      style: TextStyle(color: Colors.grey.shade600),
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
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'End time must be after start time.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave ? Colors.blue.shade600 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w600),
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
