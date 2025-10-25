import 'package:flutter/material.dart';
import '../models/employee_model.dart';

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

class _RosterTableState extends State<RosterTable> {
  // Selection + clipboard state
  static const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String? _selectedEmpName;
  String? _selectedDay;

  Shift? _clipboard;
  bool _clipboardIsCut = false;
  String? _clipboardFromEmp;
  String? _clipboardFromDay;

  @override
  Widget build(BuildContext context) {
    final headerBg = widget.headerColor ?? Colors.blueGrey.shade100;
    final headerFg = widget.headerTextColor ?? Colors.black87;
    final borderCol = widget.cellBorderColor ?? Colors.grey.shade400;
    final dayOffBg = widget.dayOffBgColor ?? Colors.grey.shade100;
    final holidayBg = widget.holidayBgColor ?? Colors.red.shade50;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        // vertical scroll for many employees
        child: Column(
          children: [
            // ===== HEADER ROW (Days of the Week) =====
            Container(
              color: headerBg,
              child: Row(
                children: [
                  _buildHeaderCell('Employee', width: 140, bg: headerBg, fg: headerFg, border: borderCol),
                  for (final day in _days) _buildHeaderCell(day, width: 120, bg: headerBg, fg: headerFg, border: borderCol),
                  _buildHeaderCell('Holiday Hours', width: 140, bg: headerBg, fg: headerFg, border: borderCol),
                ],
              ),
            ),
            // ===== EMPLOYEE ROWS =====
            for (final emp in widget.employees) _buildEmployeeRow(emp, _days, borderCol, dayOffBg, holidayBg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {double width = 120, required Color bg, required Color fg, required Color border}) {
    return Container(
      width: width,
      height: 50,
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

  Widget _buildEmployeeRow(Employee emp, List<String> days, Color borderCol, Color dayOffBg, Color holidayBg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
            height: 50,
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
        // Holiday Hours (tap to edit)
        GestureDetector(
          onTap: () => _editHolidayHours(emp),
          child: Container(
            width: 140,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: borderCol),
            ),
            child: Text('${emp.totalHolidayThisRoster.toStringAsFixed(1)} hrs'),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftCell(Employee emp, String day, Color borderCol, Color dayOffBg, Color holidayBg) {
    final shift = emp.shifts[day];
    final text = shift?.formatted() ?? 'Day Off';
    Color bgColor;

    if (shift == null) {
      bgColor = dayOffBg;
    } else if (shift.isHoliday) {
      bgColor = holidayBg;
    } else {
      bgColor = shift.customColor ?? emp.employeeColor ?? Colors.white;
    }

    final isSelected = emp.name == _selectedEmpName && day == _selectedDay;

    return GestureDetector(
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
      },
      child: Container(
        width: 120,
        height: 70,
        alignment: Alignment.center,
        margin: const EdgeInsets.all(0.2),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.9),
          border: Border.all(color: borderCol, width: isSelected ? 2 : 1),
        ),
        child: Text(
          text.isEmpty ? '-' : text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: (shift?.isHoliday == true) ? Colors.redAccent : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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

  Future<void> _editHolidayHours(Employee emp) async {
    final manualCtl = TextEditingController(text: emp.manualHolidayHours.toString());
    final carryCtl = TextEditingController(text: emp.carryOverHolidayHours.toString());
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Holiday hours — ${emp.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: manualCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Manual holiday hours (this roster)'),
            ),
            TextField(
              controller: carryCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Carry-over holiday hours (from previous)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                emp.manualHolidayHours = double.tryParse(manualCtl.text) ?? emp.manualHolidayHours;
                emp.carryOverHolidayHours = double.tryParse(carryCtl.text) ?? emp.carryOverHolidayHours;
              });
              Navigator.pop(context);
              await widget.onRosterChanged(widget.employees); // persist after change
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
}
