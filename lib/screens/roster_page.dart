import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import '../services/pdf_service.dart';
import '../widgets/add_shift_dialog.dart';
import '../widgets/roster_table.dart';
import '../services/roster_storage.dart';


class RosterPage extends StatefulWidget {
  final String rosterName;
  const RosterPage({super.key, required this.rosterName});

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  List<Employee> employees = [];
  Map<String, DateTime> weekDates = {};

  // NEW: appearance state
  Color? headerColor;
  Color? headerTextColor;
  Color? cellBorderColor;
  Color? dayOffBgColor;
  Color? holidayBgColor;

  @override
  void initState() {
    print('🔍 RosterPage initState started for: ${widget.rosterName}');
    super.initState();
    // _futureRoster = RosterStorage.loadRoster(widget.rosterName).then((data) { return data; });
    print('🔍 Initializing week dates...');
    _initWeekDates();
    print('🔍 Loading style...');
    _loadStyle(); // NEW
    print('✅ RosterPage initState completed');
  }

  Future<void> _loadStyle() async {
    final map = await RosterStorage.loadStyle(widget.rosterName);
    if (map == null) return;
    setState(() {
      headerColor = _c(map['headerColor']);
      headerTextColor = _c(map['headerTextColor']);
      cellBorderColor = _c(map['cellBorderColor']);
      dayOffBgColor = _c(map['dayOffBgColor']);
      holidayBgColor = _c(map['holidayBgColor']);
    });
  }

  Future<void> _saveStyle() async {
    await RosterStorage.saveStyle(widget.rosterName, {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    });
  }

  Color? _c(Object? v) => (v is int) ? Color(v) : null;

  void _initWeekDates() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    for (int i = 0; i < 7; i++) {
      weekDates[_dayName(i)] = monday.add(Duration(days: i));
    }
  }

  String _dayName(int i) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[i];
  }

  Future<void> _saveRoster(List<Employee> employees) async {
    await RosterStorage.saveRoster(widget.rosterName, employees);
  }

  Future<void> _exportPublicPdf(List<Employee> employees) async {
    // Public PDF for staff - only shows schedule information
    final style = {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    };
    await PdfService.sharePublicRosterPdf(context, employees, weekDates, style: style);
  }

  Future<void> _exportPrivatePdf(List<Employee> employees) async {
    // Private PDF for management - includes hours and accumulated data
    final style = {
      'headerColor': headerColor?.value,
      'headerTextColor': headerTextColor?.value,
      'cellBorderColor': cellBorderColor?.value,
      'dayOffBgColor': dayOffBgColor?.value,
      'holidayBgColor': holidayBgColor?.value,
    };
    await PdfService.sharePrivateRosterPdf(context, employees, weekDates, style: style);
  }

  Future<Shift?> _openEditDialog(BuildContext context, Shift? currentShift) async {
    return await showDialog<Shift>(
      context: context,
      builder: (_) => AddShiftDialog(shift: currentShift),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rosterName),
        actions: [
          // NEW: palette customization
          IconButton(
            tooltip: 'Customize appearance',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _openCustomizeDialog,
          ),
          // Staff Schedule PDF (Public)
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Export Staff Schedule',
            onPressed: () => _exportPublicPdf(employees),
          ),
          // Management Report PDF (Private)
          IconButton(
            icon: const Icon(Icons.analytics),
            tooltip: 'Export Management Report',
            onPressed: () => _exportPrivatePdf(employees),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await _showAddEmployeeDialog(context);
          final name = result?.$1 ?? '';
          final customHoliday = result?.$2 ?? 0.0;
          if (name.isNotEmpty) {
            setState(() {
              employees.add(Employee(name: name, manualHolidayHours: customHoliday));
            });
            await _saveRoster(employees); // persist after add
          }
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Employee>>(
        stream: RosterStorage.watchRoster(widget.rosterName),
        builder: (context, snapshot) {
          print('🔍 StreamBuilder state - hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}, connectionState: ${snapshot.connectionState}');
          
          if (snapshot.hasData) {
            employees = snapshot.data!;
            print('✅ StreamBuilder received ${employees.length} employees');
            return RosterTable(
              employees: employees,
              weekDates: weekDates,
              onEdit: _openEditDialog,
              onRosterChanged: (list) => _saveRoster(list),
              headerColor: headerColor,
              headerTextColor: headerTextColor,
              cellBorderColor: cellBorderColor,
              dayOffBgColor: dayOffBgColor,
              holidayBgColor: holidayBgColor,
            );
          }
          if (snapshot.hasError) {
            print('❌ StreamBuilder error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          print('🔍 StreamBuilder showing loading spinner...');
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  // NEW: appearance customization dialog
  Future<void> _openCustomizeDialog() async {
    Color? h = headerColor ?? Colors.blueGrey.shade100;
    Color? ht = headerTextColor ?? Colors.black87;
    Color? cb = cellBorderColor ?? Colors.grey.shade400;
    Color? dof = dayOffBgColor ?? Colors.grey.shade100;
    Color? hol = holidayBgColor ?? Colors.red.shade50;

    Color? pick = await _pickColor(context, h, title: 'Header background');
    if (pick != null) h = pick;
    pick = await _pickColor(context, ht, title: 'Header text color');
    if (pick != null) ht = pick;
    pick = await _pickColor(context, cb, title: 'Cell border color');
    if (pick != null) cb = pick;
    pick = await _pickColor(context, dof, title: 'Day-off background');
    if (pick != null) dof = pick;
    pick = await _pickColor(context, hol, title: 'Holiday background');
    if (pick != null) hol = pick;

    setState(() {
      headerColor = h;
      headerTextColor = ht;
      cellBorderColor = cb;
      dayOffBgColor = dof;
      holidayBgColor = hol;
    });
    await _saveStyle();
  }

  Future<Color?> _pickColor(BuildContext context, Color? initial, {String? title}) async {
    final presets = <Color>[
      Colors.white, Colors.black, Colors.grey.shade200, Colors.grey.shade600,
      Colors.red.shade100, Colors.red.shade300, Colors.red.shade600,
      Colors.orange.shade100, Colors.orange.shade300, Colors.orange.shade600,
      Colors.amber.shade100, Colors.amber.shade300, Colors.amber.shade600,
      Colors.yellow.shade100, Colors.yellow.shade300, Colors.yellow.shade600,
      Colors.green.shade100, Colors.green.shade300, Colors.green.shade700,
      Colors.teal.shade100, Colors.teal.shade300, Colors.teal.shade700,
      Colors.blue.shade100, Colors.blue.shade300, Colors.blue.shade700,
      Colors.indigo.shade100, Colors.indigo.shade300, Colors.indigo.shade700,
      Colors.purple.shade100, Colors.purple.shade300, Colors.purple.shade700,
      Colors.pink.shade100, Colors.pink.shade300, Colors.pink.shade700,
    ];
    Color? selected = initial;
    return showDialog<Color?>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title ?? 'Select color'),
        content: SizedBox(
          width: 340,
          height: 240,
          child: GridView.count(
            crossAxisCount: 6,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: presets.map((c) {
              final isSel = selected?.value == c.value;
              return InkWell(
                onTap: () => selected = c,
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
  }

  Future<(String, double)?> _showAddEmployeeDialog(BuildContext context) {
    final nameCtl = TextEditingController();
    final holidayCtl = TextEditingController(text: '0');
    return showDialog<(String, double)?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              decoration: const InputDecoration(
                labelText: 'Employee Name',
                hintText: 'Enter employee name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: holidayCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Custom holiday hours (optional)',
                hintText: 'e.g. 2.5',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtl.text.trim();
              final custom = double.tryParse(holidayCtl.text.trim()) ?? 0.0;
              Navigator.pop(context, (name, custom));
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
