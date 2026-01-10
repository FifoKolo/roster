import 'roster_storage.dart';
import '../models/employee_model.dart';

class HolidayRecalculationService {
  /// Recalculate accumulated holiday hours across all weeks in order
  /// This fixes any existing rosters that have incorrect accumulated values
  static Future<Map<String, dynamic>> recalculateAllWeeks() async {
    print('🔄 Starting holiday recalculation for all weeks...');
    
    try {
      // Get all roster names
      final allRosters = await RosterStorage.getAllRosterNames();
      
      // Filter and sort week rosters (Week 1, Week 2, etc.)
      final weekRosters = allRosters
          .where((name) => RegExp(r'^Week\s+\d+', caseSensitive: false).hasMatch(name))
          .toList();
      
      // Sort by week number
      weekRosters.sort((a, b) {
        final aMatch = RegExp(r'Week\s+(\d+)').firstMatch(a);
        final bMatch = RegExp(r'Week\s+(\d+)').firstMatch(b);
        if (aMatch == null || bMatch == null) return 0;
        final aNum = int.parse(aMatch.group(1)!);
        final bNum = int.parse(bMatch.group(1)!);
        return aNum.compareTo(bNum);
      });
      
      if (weekRosters.isEmpty) {
        return {
          'success': false,
          'message': 'No weekly rosters found to recalculate',
          'weeksProcessed': 0,
        };
      }
      
      print('📋 Found ${weekRosters.length} weekly rosters to process');
      
      // Track employee holiday balances across weeks
      final Map<String, double> employeeHolidayBalance = {};
      int weeksProcessed = 0;
      int employeesUpdated = 0;
      
      for (final rosterName in weekRosters) {
        print('\n📊 Processing: $rosterName');
        
        // Load the roster
        final employees = await RosterStorage.loadRoster(rosterName);
        bool rosterModified = false;
        
        for (final employee in employees) {
          final employeeName = employee.name;
          
          // Get the starting balance for this employee
          double startingBalance;
          if (employeeHolidayBalance.containsKey(employeeName)) {
            // Use the ending balance from the previous week
            startingBalance = employeeHolidayBalance[employeeName]!;
          } else {
            // First week for this employee - use their current accumulated value
            // But clear any custom holiday hours to avoid double-counting
            startingBalance = employee.accumulatedHolidayHours;
            print('  ✨ First appearance of $employeeName: starting with ${startingBalance.toStringAsFixed(2)} hrs');
          }
          
          // Calculate this week's values
          final earnedThisWeek = employee.totalPaidHours * 0.08;
          final usedThisWeek = employee.totalHolidayHoursUsed;
          final endingBalance = (startingBalance + earnedThisWeek - usedThisWeek).clamp(0.0, double.infinity);
          
          print('  👤 $employeeName: start=${startingBalance.toStringAsFixed(2)} + earned=${earnedThisWeek.toStringAsFixed(2)} - used=${usedThisWeek.toStringAsFixed(2)} = ${endingBalance.toStringAsFixed(2)}');
          
          // Update the employee's accumulated holiday hours if different
          if ((employee.accumulatedHolidayHours - startingBalance).abs() > 0.01) {
            employee.accumulatedHolidayHours = startingBalance;
            employee.customHolidayHours = null; // Clear any custom overrides
            rosterModified = true;
            employeesUpdated++;
            print('    ✏️  Updated accumulated holiday hours from ${employee.accumulatedHolidayHours.toStringAsFixed(2)} to ${startingBalance.toStringAsFixed(2)}');
          }
          
          // Store the ending balance for the next week
          employeeHolidayBalance[employeeName] = endingBalance;
        }
        
        // Save the roster if modified
        if (rosterModified) {
          await RosterStorage.saveRoster(rosterName, employees);
          print('  ✅ Saved updated roster');
        }
        
        weeksProcessed++;
      }
      
      print('\n🎉 Recalculation complete!');
      print('   Weeks processed: $weeksProcessed');
      print('   Employee records updated: $employeesUpdated');
      
      return {
        'success': true,
        'message': 'Successfully recalculated $weeksProcessed weeks',
        'weeksProcessed': weeksProcessed,
        'employeesUpdated': employeesUpdated,
        'finalBalances': employeeHolidayBalance,
      };
      
    } catch (e, stackTrace) {
      print('❌ Error during recalculation: $e');
      print('Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error: $e',
        'weeksProcessed': 0,
      };
    }
  }
}
