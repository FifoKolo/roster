import 'package:flutter/material.dart';
import '../models/employee_model.dart';
import 'roster_page.dart';
import '../services/roster_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class RosterManager extends StatefulWidget {
  const RosterManager({super.key});

  @override
  State<RosterManager> createState() => _RosterManagerState();
}

class _RosterManagerState extends State<RosterManager> {
  List<String> rosterNames = [];

  @override
  void initState() {
    super.initState();
    _loadRosters();
  }

  Future<void> _loadRosters() async {
    // Keep local initial state; UI will be driven by stream below
    final names = await RosterStorage.watchRosterNames().first;
    setState(() => rosterNames = names);
  }

  /// Create a new roster (remove default staff)
  Future<void> _createRoster() async {
    print('🔍 _createRoster: Starting...');
    try {
      // Use current week instead of asking user to select
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      
      // Calculate week number for default name
      final firstDayOfYear = DateTime(monday.year, 1, 1);
      final weekNumber = ((monday.difference(firstDayOfYear).inDays +
              firstDayOfYear.weekday - 1) / 7)
          .ceil();

      // Simple default name without dates (dates are shown in the app UI)
      final defaultName = 'Week $weekNumber';

      print('🔍 Showing name dialog...');
      // Show dialog with pre-filled name
      final customName = await _showNewRosterDialog(defaultName);
      if (customName == null || customName.isEmpty) {
        print('❌ User cancelled name dialog');
        return;
      }
      print('✅ Got roster name: $customName');

      // Skip the choice dialog and go directly to staff names
      print('🔍 Getting initial staff names...');
      final names = await _askInitialStaffNames();
      List<Employee> newEmployees = [];
      
      if (names != null && names.trim().isNotEmpty) {
        newEmployees = names
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map((n) => Employee(
              name: n,
              rosterStartDate: monday,
              rosterEndDate: sunday,
            ))
            .toList();
        print('✅ Created ${newEmployees.length} employees from names');
      }

      print('🔍 Creating roster with ${newEmployees.length} employees...');
      await RosterStorage.createRoster(customName, newEmployees);
      print('✅ Roster created successfully');
      
      print('🔍 Opening roster...');
      if (mounted) _openRoster(customName);
      print('✅ Navigation initiated');
      
    } catch (e, stackTrace) {
      print('❌ Error in _createRoster: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  Future<String?> _showNewRosterDialog(String defaultName) async {
    final controller = TextEditingController(text: defaultName);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          elevation: 24,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.all(24),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          title: Container(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade200,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_circle, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Create New Roster',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade50, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.label, color: Colors.indigo.shade700, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Roster Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.indigo.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Roster Name',
                            hintText: 'Enter roster name or use suggested name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.blue.shade500, width: 2.5),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit, color: Colors.blue.shade600, size: 20),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          autofocus: true,
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade50, Colors.indigo.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.lightbulb, size: 16, color: Colors.blue.shade700),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tip: Use simple descriptive names like "Week 42" or "October Roster"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Validation message
                if (controller.text.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade100,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.warning, size: 16, color: Colors.blue.shade700),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Please enter a roster name',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: controller.text.trim().isNotEmpty
                        ? [
                            BoxShadow(
                              color: Colors.blue.shade300,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () => Navigator.pop(context, controller.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: controller.text.trim().isEmpty 
                          ? Colors.grey.shade300 
                          : Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      elevation: controller.text.trim().isEmpty ? 0 : 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.add_circle, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    );
  }



  Future<String?> _askInitialStaffNames() async {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.people, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Initial Staff',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add staff members to your roster (optional)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Staff Names',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctl,
                        decoration: InputDecoration(
                          labelText: 'Staff Names',
                          hintText: 'e.g. Alice, Bob, Carol, Diana',
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
                          prefixIcon: Icon(Icons.edit, color: Colors.grey.shade600),
                        ),
                        maxLines: 3,
                        onChanged: (value) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Separate names with commas. You can add more staff later.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (ctl.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            '${ctl.text.split(',').where((s) => s.trim().isNotEmpty).length} staff members will be added',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Skip',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, ctl.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_add, size: 18),
                  const SizedBox(width: 6),
                  Text(ctl.text.trim().isEmpty ? 'Continue' : 'Add Staff'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestoreDialog() async {
    try {
      final deletedRosters = await RosterStorage.getDeletedRosters();
      
      if (deletedRosters.isEmpty) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.info, color: Colors.blue.shade700, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('No deleted rosters to restore'),
              ],
            ),
            backgroundColor: Colors.blue.shade50,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        return;
      }

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            elevation: 24,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.all(24),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            title: Container(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.restore_from_trash, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Restore Deleted Rosters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Select rosters to restore or permanently delete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: ListView.builder(
                      itemCount: deletedRosters.length,
                      itemBuilder: (context, index) {
                        final item = deletedRosters[index];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey.shade50,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Color(0xFF1A1A1A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Deleted: ${item.formattedDeleteDate}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.green.shade200,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            await RosterStorage.restoreRoster(item);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text('Restored "${item.displayName}"'),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green.shade50,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                margin: const EdgeInsets.all(16),
                                              ),
                                            );
                                            Navigator.pop(context);
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error restoring roster: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          elevation: 2,
                                        ),
                                        icon: const Icon(Icons.restore, size: 16),
                                        label: const Text(
                                          'Restore',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.shade200,
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Confirm Permanent Delete'),
                                              content: Text('Are you sure you want to permanently delete "${item.displayName}"? This cannot be undone.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  child: const Text('Delete Forever'),
                                                ),
                                              ],
                                            ),
                                          );
                                          
                                          if (confirm == true) {
                                            try {
                                              await RosterStorage.permanentlyDeleteFromTrash(item);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade100,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Icon(Icons.delete_forever, color: Colors.red.shade700, size: 16),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Text('Permanently deleted "${item.displayName}"'),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.red.shade50,
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  margin: const EdgeInsets.all(16),
                                                ),
                                              );
                                              // Refresh the dialog by re-calling the method
                                              Navigator.pop(context);
                                              _showRestoreDialog();
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error deleting roster: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          elevation: 2,
                                        ),
                                        icon: const Icon(Icons.delete_forever, size: 16),
                                        label: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (deletedRosters.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Empty Trash'),
                            content: const Text('Are you sure you want to permanently delete ALL deleted rosters? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Empty Trash'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          try {
                            await RosterStorage.emptyTrash();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.delete_sweep, color: Colors.blue.shade700, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text('Trash emptied'),
                                  ],
                                ),
                                backgroundColor: Colors.blue.shade50,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error emptying trash: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                      icon: const Icon(Icons.delete_sweep, size: 18),
                      label: const Text(
                        'Empty Trash',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading deleted rosters: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openRoster(String name) {
    print('🔍 _openRoster called with name: $name');
    print('🔍 About to navigate to RosterPage...');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RosterPage(rosterName: name)),
    ).then((_) {
      print('✅ Navigation completed - NOT reloading rosters to avoid loop');
      // Removed _loadRosters() to prevent potential loop
    }).catchError((error) {
      print('❌ Navigation error: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster Manager'),
        centerTitle: true,
        actions: [
          // Restore deleted rosters
          IconButton(
            tooltip: 'Restore Deleted Rosters',
            icon: const Icon(Icons.restore_from_trash),
            onPressed: _showRestoreDialog,
          ),
          // Sign out
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<String>>(
        stream: RosterStorage.watchRosterNames(),
        initialData: rosterNames,
        builder: (context, snap) {
          final names = snap.data ?? const <String>[];
          if (names.isEmpty) {
            return const Center(
              child: Text(
                'No rosters yet.\nTap + to create one!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: names.length,
            itemBuilder: (context, index) {
              final name = names[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: ListTile(
                  title: Text(name),
                  subtitle: FutureBuilder<double>(
                    future: RosterStorage.getTotalHours(name),
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? 0;
                      return Text('Total Hours (inc. breaks): ${total.toStringAsFixed(1)}');
                    },
                  ),
                  onTap: () => _openRoster(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, color: Colors.blue),
                        onPressed: () => _copyRoster(name),
                        tooltip: 'Copy roster',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRoster(name),
                        tooltip: 'Delete roster',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade300.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _createRoster,
          tooltip: 'Create new roster',
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }

  /// Copy an existing roster to create a new one
  Future<void> _copyRoster(String sourceRosterName) async {
    try {
      // Ask user what to copy
      final copyOption = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Copy "$sourceRosterName"'),
          content: const Text('What would you like to copy?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('employees_only'),
              child: const Text('Employees Only\n(empty shifts)'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('employees_and_shifts'),
              child: const Text('Employees + Shifts\n(complete copy)'),
            ),
          ],
        ),
      );

      if (copyOption == null) return;

      // Generate a simple default name for the copy
      final defaultName = 'Copy of $sourceRosterName';

      // Show dialog to get new roster name
      final newName = await _showNewRosterDialog(defaultName);
      if (newName == null || newName.isEmpty) return;

      // Check if name already exists
      if (rosterNames.contains(newName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A roster with that name already exists!')),
          );
        }
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copying roster...')),
        );
      }

      // Copy the roster based on user choice
      if (copyOption == 'employees_only') {
        await _copyRosterEmployeesOnly(sourceRosterName, newName);
      } else {
        await RosterStorage.copyRoster(sourceRosterName, newName);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully copied to "$newName"')),
        );
      }

      // Refresh the list
      _loadRosters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error copying roster: $e')),
        );
      }
    }
  }

  /// Copy roster with employees only (no shifts)
  Future<void> _copyRosterEmployeesOnly(String sourceRosterName, String newRosterName) async {
    // Use current week instead of asking user to select
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    
    // Load the source roster data
    final sourceEmployees = await RosterStorage.loadRoster(sourceRosterName);
    
    // Create employees with empty shifts and new dates
    final copiedEmployees = sourceEmployees.map((emp) => Employee(
      name: emp.name,
      shifts: {}, // Empty shifts
      employeeColor: emp.employeeColor,
      accumulatedWorkedHours: 0.0,
      accumulatedTotalHours: 0.0,
      accumulatedHolidayHours: emp.accumulatedHolidayHours, // Preserve holiday hours
      rosterStartDate: monday, // NEW: Set the selected week dates
      rosterEndDate: sunday,
    )).toList();
    
    // Create the new roster
    await RosterStorage.createRoster(newRosterName, copiedEmployees);
    
    // Copy style settings if they exist
    try {
      final sourceStyle = await RosterStorage.loadStyle(sourceRosterName);
      if (sourceStyle != null) {
        await RosterStorage.saveStyle(newRosterName, sourceStyle);
      }
    } catch (e) {
      // Ignore style copy errors
    }
  }

  /// Move a roster to trash with confirmation
  Future<void> _deleteRoster(String rosterName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        titlePadding: const EdgeInsets.all(24),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete, color: Colors.red.shade700, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Move to Trash',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade50, Colors.indigo.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.info, size: 16, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Safe Delete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This roster will be moved to trash and can be restored later if needed.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: 'Are you sure you want to move '),
                    TextSpan(
                      text: '"$rosterName"',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const TextSpan(text: ' to trash?'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade300,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Move to Trash',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RosterStorage.moveRosterToTrash(rosterName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.delete, color: Colors.blue.shade700, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Moved "$rosterName" to trash')),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      _showRestoreDialog();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text(
                      'RESTORE',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue.shade50,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error moving roster to trash: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}


