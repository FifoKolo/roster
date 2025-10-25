import 'package:flutter/material.dart';
import '../models/employee_model.dart';

class AddShiftDialog extends StatefulWidget {
  final Shift? shift;

  const AddShiftDialog({super.key, this.shift});

  @override
  State<AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  late TimeOfDay? startTime;
  late TimeOfDay? endTime;
  late String? role;
  late bool isHoliday;
  Color? selectedColor;

  // Controllers to prefill and validate inputs
  late final TextEditingController roleController;
  late final TextEditingController commentController;

  @override
  void initState() {
    super.initState();
    startTime = widget.shift?.startTime;
    endTime = widget.shift?.endTime;
    role = widget.shift?.role;
    isHoliday = widget.shift?.isHoliday ?? false;
    selectedColor = widget.shift?.customColor;

    roleController = TextEditingController(text: widget.shift?.role ?? '');
    // If Shift has a comment field, prefill it; otherwise this remains empty.
    commentController = TextEditingController(text: widget.shift?.comment ?? '');

    // Update UI validation state when text changes
    roleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    roleController.dispose();
    commentController.dispose();
    super.dispose();
  }

  bool _isStartBeforeEnd(TimeOfDay a, TimeOfDay b) {
    final ai = a.hour * 60 + a.minute;
    final bi = b.hour * 60 + b.minute;
    return ai < bi;
  }

  @override
  Widget build(BuildContext context) {
    final canSave = isHoliday ||
        ((roleController.text.trim().isNotEmpty) &&
            startTime != null &&
            endTime != null &&
            _isStartBeforeEnd(startTime!, endTime!));

    return AlertDialog(
      title: const Text('Add/Edit Shift'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('Holiday'),
            value: isHoliday,
            onChanged: (value) => setState(() => isHoliday = value),
          ),
          if (!isHoliday) ...[
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: 'Role'),
              textInputAction: TextInputAction.next,
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (time != null) setState(() => startTime = time);
                    },
                    child: Text(startTime?.format(context) ?? 'Start Time'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: endTime ?? TimeOfDay.now(),
                      );
                      if (time != null) setState(() => endTime = time);
                    },
                    child: Text(endTime?.format(context) ?? 'End Time'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(labelText: 'Comment (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selectedColor ?? Colors.transparent,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.color_lens_outlined),
                  label: const Text('Pick color'),
                  onPressed: () async {
                    final c = await _pickColor(context, selectedColor);
                    if (c != null) setState(() => selectedColor = c);
                  },
                ),
                if (selectedColor != null)
                  TextButton(
                    onPressed: () => setState(() => selectedColor = null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
          if (!isHoliday &&
              startTime != null &&
              endTime != null &&
              !_isStartBeforeEnd(startTime!, endTime!))
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'End time must be after start time.',
                style: TextStyle(color: Colors.red),
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
          onPressed: canSave
              ? () {
                  Navigator.pop(
                    context,
                    Shift(
                      startTime: isHoliday ? null : startTime,
                      endTime: isHoliday ? null : endTime,
                      role: isHoliday ? null : roleController.text.trim(),
                      // If your Shift model has 'comment', this will populate it.
                      comment: commentController.text.trim().isEmpty
                          ? null
                          : commentController.text.trim(),
                      isHoliday: isHoliday,
                      customColor: selectedColor,
                    ),
                  );
                }
              : null,
          child: const Text('Save'),
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
