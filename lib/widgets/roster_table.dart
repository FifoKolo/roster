import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/irish_bank_holidays.dart';

class RosterTable extends StatefulWidget {
  final List<Employee> employees;
  final Map<String, DateTime> weekDates;
  final Future<Shift?> Function(BuildContext, Shift?) onEdit;
  final Future<void> Function(List<Employee>) onRosterChanged; // persist callback

  // NEW: optional appearance customization
  final Color? headerColor;
  final Color? headerTextColor;
  final Color? cellBorderColor;
  final Color? dayOffBgColor;
  final Color? holidayBgColor;

  const RosterTable({
    super.key,
    required this.employees,
    required this.weekDates,
    required this.onEdit,
    required this.onRosterChanged,
    this.headerColor,
    this.headerTextColor,
    this.cellBorderColor,
    this.dayOffBgColor,
    this.holidayBgColor,
  });

  @override
  State<RosterTable> createState() => _RosterTableState();
}

class _RosterTableState extends State<RosterTable> with TickerProviderStateMixin {
  // Selection + clipboard state
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const double _rowHeight = 60.0; // Consistent height for all row elements
  String? _selectedEmpName;
  String? _selectedDay;

  Shift? _clipboard;
  bool _clipboardIsCut = false;
  String? _clipboardFromEmp;
  String? _clipboardFromDay;

  // Animation for copy feedback
  late AnimationController _copyAnimationController;
  late Animation<double> _copyAnimation;
  String? _copyAnimationEmp;
  String? _copyAnimationDay;

  @override
  void initState() {
    super.initState();
    _copyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _copyAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _copyAnimationController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _copyAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.headerColor ?? Colors.blueGrey.shade100;
    final headerFg = widget.headerTextColor ?? Colors.black87;
    final borderCol = widget.cellBorderColor ?? Colors.grey.shade400;
    final dayOffBg = widget.dayOffBgColor ?? Colors.grey.shade100;
    final holidayBg = widget.holidayBgColor ?? Colors.red.shade50;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            // ===== HEADER ROW (Days of the Week) =====
            Container(
              color: headerBg,
              child: Row(
                children: [
                  _buildHeaderCell('Employee', width: 140, bg: headerBg, fg: headerFg, border: borderCol),
                  for (final day in _days) _buildDayHeaderCell(day, widget.weekDates[day], headerBg, headerFg, borderCol),
                  _buildHeaderCell('Holiday Hours', width: 140, bg: headerBg, fg: headerFg, border: borderCol),
                ],
              ),
            ),
            // ===== EMPLOYEE ROWS =====
            for (final emp in widget.employees) _buildEmployeeRow(emp, _days, borderCol, dayOffBg, holidayBg),
          ],
        ),
    );
  }

  Widget _buildHeaderCell(String text, {double width = 120, required Color bg, required Color fg, required Color border}) {
    return Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: border),
        color: bg,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDayHeaderCell(String day, DateTime? date, Color bg, Color fg, Color border) {
    if (date == null) {
      return _buildHeaderCell(day, bg: bg, fg: fg, border: border);
    }

    // Check for bank holiday
    final bankHoliday = IrishBankHolidays.getBankHoliday(date);
    final isBankHoliday = bankHoliday != null;
    
    // Get styling for bank holidays
    BankHolidayStyle? holidayStyle;
    if (isBankHoliday) {
      holidayStyle = IrishBankHolidays.getHolidayStyle(bankHoliday);
    }

    return Container(
      width: 120,
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: isBankHoliday ? holidayStyle!.borderColor : border,
          width: isBankHoliday ? 2 : 1,
        ),
        color: isBankHoliday ? holidayStyle!.backgroundColor : bg,
        gradient: isBankHoliday ? LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            holidayStyle!.backgroundColor,
            holidayStyle.backgroundColor.withOpacity(0.7),
          ],
        ) : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBankHoliday) ...[
                Icon(
                  holidayStyle!.icon,
                  size: 16,
                  color: holidayStyle.textColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isBankHoliday ? holidayStyle!.textColor : fg,
                ),
              ),
            ],
          ),
          if (isBankHoliday) ...[
            const SizedBox(height: 2),
            Text(
              bankHoliday.formattedDate,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: holidayStyle!.textColor.withOpacity(0.8),
              ),
            ),
            Text(
              'Bank Holiday',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: holidayStyle.textColor,
              ),
            ),
          ] else ...[
            const SizedBox(height: 2),
            Text(
              '${date.day}/${date.month}',
              style: TextStyle(
                fontSize: 10,
                color: fg.withOpacity(0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Employee emp, List<String> days, Color borderCol, Color dayOffBg, Color holidayBg) {
    return SizedBox(
      height: _rowHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // Employee Name (tap to set color)
        GestureDetector(
          onTap: () async {
            final c = await _pickColor(context, emp.employeeColor);
            if (c != null) {
              setState(() => emp.employeeColor = c);
              await widget.onRosterChanged(widget.employees);
            }
          },
          onLongPress: () async {
            setState(() => emp.employeeColor = null);
            await widget.onRosterChanged(widget.employees);
          },
          child: Container(
            width: 140, // match header
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: borderCol),
              color: (emp.employeeColor ?? Colors.transparent).withOpacity(emp.employeeColor == null ? 0 : 0.2),
            ),
            child: Text(emp.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        // Shifts for Each Day
        for (final day in days) _buildShiftCell(emp, day, borderCol, dayOffBg, holidayBg),
        // Holiday Hours (tap to edit accumulated hours)
        GestureDetector(
          onTap: () => _editAccumulatedHolidayHours(emp),
          child: Container(
            width: 140,
            height: _rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: borderCol),
              color: Colors.blue.shade50, // Light blue background to indicate it's clickable
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, size: 14, color: Colors.blue.shade600),
                Text(
                  '${emp.remainingAccumulatedHolidayHours.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    fontSize: 11,
                    color: emp.remainingAccumulatedHolidayHours < 0 ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Remaining',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildShiftCell(Employee emp, String day, Color borderCol, Color dayOffBg, Color holidayBg) {
    final shift = emp.shifts[day];
    final text = shift?.formatted() ?? 'Day Off';
    
    // Check if this date is a bank holiday
    final date = widget.weekDates[day];
    final bankHoliday = date != null ? IrishBankHolidays.getBankHoliday(date) : null;
    final isBankHoliday = bankHoliday != null;
    
    Color bgColor;
    Color borderColor = borderCol;
    
    if (shift == null) {
      if (isBankHoliday) {
        final holidayStyle = IrishBankHolidays.getHolidayStyle(bankHoliday);
        bgColor = holidayStyle.backgroundColor.withOpacity(0.3);
        borderColor = holidayStyle.borderColor;
      } else {
        bgColor = dayOffBg;
      }
    } else if (shift.isHoliday) {
      bgColor = holidayBg;
    } else {
      if (isBankHoliday) {
        final holidayStyle = IrishBankHolidays.getHolidayStyle(bankHoliday);
        final shiftColor = shift.customColor ?? emp.employeeColor ?? Colors.white;
        // Blend shift color with bank holiday styling
        bgColor = Color.alphaBlend(holidayStyle.backgroundColor.withOpacity(0.4), shiftColor);
        borderColor = holidayStyle.borderColor;
      } else {
        bgColor = shift.customColor ?? emp.employeeColor ?? Colors.white;
      }
    }

    final isSelected = emp.name == _selectedEmpName && day == _selectedDay;
    final isCopyAnimating = emp.name == _copyAnimationEmp && day == _copyAnimationDay;

    return AnimatedBuilder(
      animation: _copyAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCopyAnimating ? _copyAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () async {
              final newShift = await widget.onEdit(context, shift);
              if (newShift != null) {
                setState(() {
                  emp.shifts[day] = newShift;
                });
                await widget.onRosterChanged(widget.employees); // persist after edit
              }
            },
            onLongPress: () async {
              if (shift != null) {
                // Start drag detection for movable cells
                await _handleLongPressWithDrag(emp, day, shift);
              } else {
                // No shift to drag, show normal menu
                await _showNormalLongPressMenu(emp, day, shift);
              }
            },
            child: Container(
              width: 120,
              height: _rowHeight,
              alignment: Alignment.center,
              margin: const EdgeInsets.all(0.2),
              decoration: BoxDecoration(
                color: isCopyAnimating ? Colors.green.shade100 : bgColor.withOpacity(0.9),
                border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
              ),
              child: Text(
                text.isEmpty ? '-' : text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: (shift?.isHoliday == true) ? Colors.redAccent : Colors.black87,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showShiftActions(BuildContext context, Employee emp, String day, {required bool hasShift}) async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasShift)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit'),
                  onTap: () => Navigator.pop(context, 'edit'),
                ),
              if (hasShift)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copy'),
                  onTap: () => Navigator.pop(context, 'copy'),
                ),
              if (hasShift)
                ListTile(
                  leading: const Icon(Icons.content_cut),
                  title: const Text('Cut (move)'),
                  onTap: () => Navigator.pop(context, 'cut'),
                ),
              if (_clipboard != null)
                ListTile(
                  leading: const Icon(Icons.paste),
                  title: const Text('Paste here (replace)'),
                  onTap: () => Navigator.pop(context, 'paste'),
                ),
              if (hasShift)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Move to...'),
                  onTap: () => Navigator.pop(context, 'move_to'),
                ),
              if (hasShift) const Divider(height: 1),
              if (hasShift)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Delete shift'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<(Employee, String)?> _chooseTargetCell(BuildContext context) async {
    if (widget.employees.isEmpty) return null;

    Employee selectedEmp = widget.employees.first;
    String selectedDay = _days.first;

    return showDialog<(Employee, String)?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Select target cell'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<Employee>(
                isExpanded: true,
                value: selectedEmp,
                items: [
                  for (final e in widget.employees)
                    DropdownMenuItem<Employee>(
                      value: e,
                      child: Text(e.name),
                    )
                ],
                onChanged: (v) => setLocal(() {
                  if (v != null) selectedEmp = v;
                }),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: selectedDay,
                items: [
                  for (final d in _days)
                    DropdownMenuItem<String>(
                      value: d,
                      child: Text(d),
                    )
                ],
                onChanged: (v) => setLocal(() {
                  if (v != null) selectedDay = v;
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, (selectedEmp, selectedDay)),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performPasteHere(Employee targetEmp, String targetDay) async {
    if (_clipboard == null) return;
    final isSameCell = _clipboardIsCut &&
        _clipboardFromEmp == targetEmp.name &&
        _clipboardFromDay == targetDay;

    setState(() {
      targetEmp.shifts[targetDay] = _clipboard!;
      if (_clipboardIsCut && !isSameCell) {
        final srcEmp = widget.employees.firstWhere(
          (e) => e.name == _clipboardFromEmp,
          orElse: () => targetEmp,
        );
        srcEmp.shifts.remove(_clipboardFromDay);
        // Clear clipboard after move
        _clipboard = null;
        _clipboardIsCut = false;
        _clipboardFromEmp = null;
        _clipboardFromDay = null;
      }
    });
    await widget.onRosterChanged(widget.employees);
  }

  Future<void> _performMove(Employee fromEmp, String fromDay, Employee toEmp, String toDay) async {
    final shift = fromEmp.shifts[fromDay];
    if (shift == null) return;
    setState(() {
      toEmp.shifts[toDay] = shift;
      fromEmp.shifts.remove(fromDay);
      // Clear clipboard (explicit move)
      _clipboard = null;
      _clipboardIsCut = false;
      _clipboardFromEmp = null;
      _clipboardFromDay = null;
    });
    await widget.onRosterChanged(widget.employees);
  }

  Future<void> _editAccumulatedHolidayHours(Employee emp) async {
    final controller = TextEditingController(text: emp.accumulatedHolidayHours.toString());
    
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.access_time, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text('Set Holiday Hours — ${emp.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Status:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                  const SizedBox(height: 4),
                  Text('Used this roster: ${emp.totalHolidayHoursUsed.toStringAsFixed(1)} hours'),
                  Text('Remaining: ${emp.remainingAccumulatedHolidayHours.toStringAsFixed(1)} hours', 
                       style: TextStyle(color: emp.remainingAccumulatedHolidayHours < 0 ? Colors.red : Colors.green.shade700,
                                       fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Total Accumulated Holiday Hours:', 
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Enter total holiday hours available',
                hintText: 'e.g., 120.0',
                prefixIcon: Icon(Icons.schedule, color: Colors.blue.shade600),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Tips:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('• This is the staff member\'s total holiday entitlement', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('• Each holiday deducts hours (default 8, customizable per shift)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('• Remaining hours update automatically as holidays are scheduled', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newValue = double.tryParse(controller.text) ?? emp.accumulatedHolidayHours;
              setState(() {
                emp.accumulatedHolidayHours = newValue;
              });
              Navigator.pop(context);
              await widget.onRosterChanged(widget.employees);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Reuse the same simple color picker used in AddShiftDialog, with live highlight
  Future<Color?> _pickColor(BuildContext context, Color? initial) async {
    final presets = <Color>[
      Colors.white, Colors.grey.shade200, Colors.grey.shade400,
      Colors.red.shade100, Colors.red.shade300,
      Colors.orange.shade100, Colors.orange.shade300,
      Colors.amber.shade100, Colors.amber.shade300,
      Colors.yellow.shade100, Colors.yellow.shade300,
      Colors.green.shade100, Colors.green.shade300,
      Colors.teal.shade100, Colors.teal.shade300,
      Colors.blue.shade100, Colors.blue.shade300,
      Colors.indigo.shade100, Colors.indigo.shade300,
      Colors.purple.shade100, Colors.purple.shade300,
      Colors.pink.shade100, Colors.pink.shade300,
    ];
    return showDialog<Color?>(
      context: context,
      builder: (_) {
        Color? selected = initial;
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: const Text('Select color'),
            content: SizedBox(
              width: 320,
              height: 220,
              child: GridView.count(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: presets.map((c) {
                  final isSel = selected?.value == c.value;
                  return InkWell(
                    onTap: () => setLocal(() => selected = c),
                    onDoubleTap: () => Navigator.pop(context, c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c,
                        border: Border.all(color: isSel ? Colors.black : Colors.grey.shade400, width: isSel ? 2 : 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Select')),
            ],
          ),
        );
      },
    );
  }

  // Drag and drop handling methods
  Future<void> _handleLongPressWithDrag(Employee emp, String day, Shift shift) async {
    // Start a timer for 2 seconds
    bool longPressReleased = false;
    
    // Start the timer
    final timer = Future.delayed(const Duration(seconds: 2));
    
    // Wait for either timer completion or when the user releases
    await Future.any([
      timer.then((_) async {
        if (!longPressReleased) {
          // Still holding after 2 seconds - copy with animation
          await _performCopyWithAnimation(emp, day, shift);
        }
      }),
      // In a real implementation, you'd detect gesture release here
      // For now, we'll just wait for the timer
      Future.delayed(const Duration(milliseconds: 1500)).then((_) {
        longPressReleased = true;
        // Show normal menu since drag wasn't completed
        _showNormalLongPressMenu(emp, day, shift);
      }),
    ]);
  }

  Future<void> _performCopyWithAnimation(Employee emp, String day, Shift shift) async {
    // Set animation state
    setState(() {
      _copyAnimationEmp = emp.name;
      _copyAnimationDay = day;
      // Copy to clipboard
      _clipboard = shift;
      _clipboardIsCut = false;
      _clipboardFromEmp = emp.name;
      _clipboardFromDay = day;
    });

    // Run the copy animation
    await _copyAnimationController.forward();
    await _copyAnimationController.reverse();

    // Clear animation state
    setState(() {
      _copyAnimationEmp = null;
      _copyAnimationDay = null;
    });
  }

  Future<void> _showNormalLongPressMenu(Employee emp, String day, Shift? shift) async {
    setState(() {
      _selectedEmpName = emp.name;
      _selectedDay = day;
    });
    final action = await _showShiftActions(context, emp, day, hasShift: shift != null);
    switch (action) {
      case 'edit':
        final newShift = await widget.onEdit(context, shift);
        if (newShift != null) {
          setState(() {
            emp.shifts[day] = newShift;
          });
          await widget.onRosterChanged(widget.employees);
        }
        break;
      case 'copy':
        setState(() {
          _clipboard = shift;
          _clipboardIsCut = false;
          _clipboardFromEmp = emp.name;
          _clipboardFromDay = day;
        });
        break;
      case 'cut':
        setState(() {
          _clipboard = shift;
          _clipboardIsCut = true;
          _clipboardFromEmp = emp.name;
          _clipboardFromDay = day;
        });
        break;
      case 'paste':
        await _performPasteHere(emp, day);
        break;
      case 'move_to':
        final target = await _chooseTargetCell(context);
        if (target != null) {
          await _performMove(emp, day, target.$1, target.$2);
        }
        break;
      case 'delete':
        setState(() {
          emp.shifts.remove(day);
        });
        await widget.onRosterChanged(widget.employees);
        break;
      default:
        break;
    }
  }
}
