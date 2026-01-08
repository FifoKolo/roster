import 'package:flutter/material.dart';
import '../screens/roster_page.dart';

/// A wrapper that uses the same roster page for all devices
class AdaptiveRosterPage extends StatelessWidget {
  final String rosterName;

  const AdaptiveRosterPage({
    super.key,
    required this.rosterName,
  });

  @override
  Widget build(BuildContext context) {
    // Use the same RosterPage for all devices (mobile, tablet, desktop)
    return RosterPage(rosterName: rosterName);
  }
}