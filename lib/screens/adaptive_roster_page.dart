import 'package:flutter/material.dart';
import '../screens/roster_page.dart';
import '../screens/responsive_roster_page.dart';
import '../utils/responsive_helper.dart';

/// A wrapper that automatically selects the appropriate roster page
/// based on the device type and orientation
class AdaptiveRosterPage extends StatelessWidget {
  final String rosterName;

  const AdaptiveRosterPage({
    Key? key,
    required this.rosterName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    
    if (isMobile) {
      // Use responsive page for mobile devices
      return ResponsiveRosterPage(rosterName: rosterName);
    } else {
      // Use original page for desktop/tablet
      return RosterPage(rosterName: rosterName);
    }
  }
}