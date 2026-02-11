import 'roster_storage.dart';

class HolidayRecalculationService {
  /// Recalculate accumulated holiday hours across all weeks in order
  /// This fixes any existing rosters that have incorrect accumulated values
  static Future<Map<String, dynamic>> recalculateAllWeeks() async {
    print('🔄 Starting holiday recalculation for all weeks...');
    
    try {
      // Recover roster list in case names were cleared but data still exists
      await RosterStorage.recoverRosterNamesIfMissing();

      // Get all roster names
      final allRosters = await RosterStorage.watchRosterNames().first;
      
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
      
      // Track employee balances across weeks
      final Map<String, Map<String, double>> employeeBalances = {};
      int weeksProcessed = 0;
      int employeesUpdated = 0;
      int? currentYear;
      
      for (final rosterName in weekRosters) {
        print('\n📊 Processing: $rosterName');
        
        // Load the roster
        final employees = await RosterStorage.loadRoster(rosterName);
        
        if (employees.isEmpty) {
          print('  ⚠️ No employees found, skipping');
          continue;
        }
        
        // Detect year change by checking roster start date
        final rosterStartDate = employees.first.rosterStartDate;
        if (rosterStartDate != null) {
          final rosterYear = rosterStartDate.year;
          
          // Check if we've crossed into a new year
          if (currentYear != null && rosterYear != currentYear) {
            print('  🎉 NEW YEAR DETECTED: $currentYear → $rosterYear');
            print('  🔄 Resetting all accumulated values to 0');
            employeeBalances.clear(); // Reset all employee balances
          }
          
          currentYear = rosterYear;
        }
        
        bool rosterModified = false;
        
        for (final employee in employees) {
          final employeeName = employee.name;
          
          // Get the starting balances for this employee
          double startingWorkedHours;
          double startingTotalHours;
          double startingHolidayHours;
          double startingHolidayUsed;
          double startingHolidayEarned;
          
          if (employeeBalances.containsKey(employeeName)) {
            // Use the ending balances from the previous week
            final prev = employeeBalances[employeeName]!;
            startingWorkedHours = prev['worked']!;
            startingTotalHours = prev['total']!;
            startingHolidayHours = prev['holiday']!;
            startingHolidayUsed = prev['holidayUsed'] ?? 0.0;
            startingHolidayEarned = prev['holidayEarned'] ?? 0.0;
          } else {
            // First week for this employee - rebuild from zero
            startingWorkedHours = 0.0;
            startingTotalHours = 0.0;
            startingHolidayHours = 0.0;
            startingHolidayUsed = 0.0;
            startingHolidayEarned = 0.0;
            print('  ✨ First appearance of $employeeName: starting with worked=${startingWorkedHours.toStringAsFixed(2)}, holiday=${startingHolidayHours.toStringAsFixed(2)}');
          }
          // Align holiday earned with starting worked hours
          startingHolidayEarned = startingWorkedHours * 0.08;
          
          // Calculate this week's values
          final workedThisWeek = employee.totalPaidHours;
          final earnedHolidayThisWeek = workedThisWeek * 0.08;
          final usedHolidayThisWeek = employee.totalHolidayHoursUsed;
          
          // Calculate ending balances
          final endingWorkedHours = startingWorkedHours + workedThisWeek;
          final endingTotalHours = startingTotalHours + workedThisWeek;
          final endingHolidayHours = (startingHolidayHours + earnedHolidayThisWeek - usedHolidayThisWeek).clamp(0.0, double.infinity);
          final endingHolidayUsed = startingHolidayUsed + usedHolidayThisWeek;
          final endingHolidayEarned = endingWorkedHours * 0.08;
          
          print('  👤 $employeeName:');
          print('     Worked: ${startingWorkedHours.toStringAsFixed(2)} + ${workedThisWeek.toStringAsFixed(2)} = ${endingWorkedHours.toStringAsFixed(2)}');
          print('     Holiday: ${startingHolidayHours.toStringAsFixed(2)} + ${earnedHolidayThisWeek.toStringAsFixed(2)} - ${usedHolidayThisWeek.toStringAsFixed(2)} = ${endingHolidayHours.toStringAsFixed(2)}');
          
          // Update the employee's accumulated values
          bool wasUpdated = false;
          
          if ((employee.accumulatedWorkedHours - startingWorkedHours).abs() > 0.01) {
            print('    ✏️  Updated worked hours: ${employee.accumulatedWorkedHours.toStringAsFixed(2)} → ${startingWorkedHours.toStringAsFixed(2)}');
            wasUpdated = true;
          }
          
          if ((employee.accumulatedTotalHours - startingTotalHours).abs() > 0.01) {
            print('    ✏️  Updated total hours: ${employee.accumulatedTotalHours.toStringAsFixed(2)} → ${startingTotalHours.toStringAsFixed(2)}');
            wasUpdated = true;
          }
          
          if ((employee.accumulatedHolidayHours - startingHolidayHours).abs() > 0.01) {
            print('    ✏️  Updated holiday hours: ${employee.accumulatedHolidayHours.toStringAsFixed(2)} → ${startingHolidayHours.toStringAsFixed(2)}');
            wasUpdated = true;
          }
          if ((employee.accumulatedHolidayHoursUsed - startingHolidayUsed).abs() > 0.01) {
            print('    ✏️  Updated holiday used: ${employee.accumulatedHolidayHoursUsed.toStringAsFixed(2)} → ${startingHolidayUsed.toStringAsFixed(2)}');
            wasUpdated = true;
          }
          if ((employee.accumulatedHolidayHoursEarned - startingHolidayEarned).abs() > 0.01) {
            print('    ✏️  Updated holiday earned: ${employee.accumulatedHolidayHoursEarned.toStringAsFixed(2)} → ${startingHolidayEarned.toStringAsFixed(2)}');
            wasUpdated = true;
          }
          
          if (wasUpdated) {
            employeesUpdated++;
          }
          
          employee.accumulatedWorkedHours = startingWorkedHours;
          employee.accumulatedTotalHours = startingTotalHours;
          employee.accumulatedHolidayHours = startingHolidayHours;
          employee.accumulatedHolidayHoursUsed = startingHolidayUsed;
          employee.accumulatedHolidayHoursEarned = startingHolidayEarned;
          employee.customAccumulatedHours = null; // Clear any custom overrides
          employee.customHolidayHours = null;
          rosterModified = true;
          
          // Store the ending balances for the next week
          employeeBalances[employeeName] = {
            'worked': endingWorkedHours,
            'total': endingTotalHours,
            'holiday': endingHolidayHours,
            'holidayUsed': endingHolidayUsed,
            'holidayEarned': endingHolidayEarned,
          };
        }
        
        // Always save the roster to persist the corrected balances
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
        'finalBalances': employeeBalances,
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
