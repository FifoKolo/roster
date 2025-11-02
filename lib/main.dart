// Main entry for the app.
// - runApp creates the RosterApp (MaterialApp).
// - RosterManager (or home widget) is the top-level navigation entry.
//
// Roster App main.dart
// Flutter 3.35.1 compatible
//
// Features implemented:
// - Break logic: >=4.5 hrs -> 15 min; >=6 hrs -> 30 min (deducted from worked hours by default)
// - Settings popup (show breaks separately, disable break deductions) saved in SharedPreferences
// - Holiday hours: auto 8% of worked hours + manual additions (per staff)
// - Persistence: staff list, their week hours, manual holiday hours, accumulated totals
// - Weekly accumulation: "Save Week" button accumulates current week into totals and persists
//
// NOTE: Staff list starts empty (as requested). Use the + button to add staff for testing
// or integrate your own staff dataset where indicated.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/roster_manager.dart';
import 'services/roster_storage.dart';
import 'services/auth_service.dart';

// Entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force local-only mode to bypass Firebase issues for now
  var localOnly = true;

  try {
    // Skip Firebase initialization for now
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
  } catch (_) {
    // Fallback to local-only if Firebase init fails for any reason.
    localOnly = true;
  }
  runApp(RosterApp(localOnly: localOnly));
}

class RosterApp extends StatelessWidget {
  const RosterApp({super.key, this.localOnly = false});

  // NEW: whether to skip auth/cloud and run locally only
  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roster App',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: ThemeData(useMaterial3: true),
      home: AuthGate(
        skipAuth: localOnly, // NEW
        child: const RosterManager(),
      ),
    );
  }
}

// NEW: Gate to show login/signup or app (and verify email)
class AuthGate extends StatelessWidget {
  final Widget child;
  // NEW: skip auth entirely (local-only mode)
  final bool skipAuth;
  const AuthGate({super.key, required this.child, this.skipAuth = false});

  @override
  Widget build(BuildContext context) {
    // Local-only mode: no auth, no cloud sync
    if (skipAuth) {
      RosterStorage.configureCloud(null);
      return child;
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authState$,
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) {
          RosterStorage.configureCloud(null);
          return const _SignInSignUpPage();
        }
        // Configure cloud and ensure user doc exists
        RosterStorage.configureCloud(
          user.uid,
          email: user.email,
          displayName: user.displayName,
        );
        // Optional: gate unverified emails with a simple screen
        if (!(user.emailVerified)) {
          return _VerifyEmailPage(onContinue: child);
        }
        return child;
      },
    );
  }
}

// NEW: Minimal sign in/up page with validation and visibility toggles
class _SignInSignUpPage extends StatefulWidget {
  const _SignInSignUpPage();

  @override
  State<_SignInSignUpPage> createState() => _SignInSignUpPageState();
}

class _SignInSignUpPageState extends State<_SignInSignUpPage> {
  final emailCtl = TextEditingController();
  final passCtl = TextEditingController();
  final confirmCtl = TextEditingController();
  final nameCtl = TextEditingController(); // display name on sign up
  bool isLogin = true;
  bool busy = false;
  String? error;
  bool showPass = false;
  bool showPass2 = false;

  bool get _validEmail => emailCtl.text.trim().contains('@');
  bool get _validPass => passCtl.text.length >= 6;
  bool get _validConfirm => isLogin || (confirmCtl.text == passCtl.text);

  Future<void> _submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (isLogin) {
        await AuthService.instance.signIn(emailCtl.text, passCtl.text);
      } else {
        await AuthService.instance.signUp(
          emailCtl.text,
          passCtl.text,
          displayName: nameCtl.text.trim().isEmpty ? null : nameCtl.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verification email sent')),
          );
        }
      }
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      if (mounted) setState(() { busy = false; });
    }
  }

  Future<void> _reset() async {
    final email = emailCtl.text.trim();
    if (email.isEmpty) return;
    try {
      await AuthService.instance.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent')),
      );
    } catch (e) {
      setState(() { error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _validEmail && _validPass && _validConfirm && !busy;
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Sign In' : 'Sign Up')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: emailCtl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtl,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 chars)',
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showPass = !showPass),
                    ),
                  ),
                  obscureText: !showPass,
                ),
                if (!isLogin) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtl,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(showPass2 ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => showPass2 = !showPass2),
                      ),
                    ),
                    obscureText: !showPass2,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Name (optional)'),
                  ),
                ],
                const SizedBox(height: 12),
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  child: Text(busy ? 'Please wait...' : (isLogin ? 'Sign In' : 'Sign Up')),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    isLogin = !isLogin;
                    error = null;
                  }),
                  child: Text(isLogin ? 'Create account' : 'Have an account? Sign in'),
                ),
                if (isLogin)
                  TextButton(onPressed: _reset, child: const Text('Forgot Password')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// NEW: Simple verify-email page (resend + refresh). Continue button lets user proceed if you don't want to hard-block.
class _VerifyEmailPage extends StatefulWidget {
  final Widget onContinue;
  const _VerifyEmailPage({required this.onContinue});

  @override
  State<_VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<_VerifyEmailPage> {
  bool sending = false;
  String? message;

  Future<void> _resend() async {
    setState(() { sending = true; message = null; });
    try {
      await AuthService.instance.resendVerificationEmail();
      setState(() { message = 'Verification email sent.'; });
    } catch (e) {
      setState(() { message = e.toString(); });
    } finally {
      setState(() { sending = false; });
    }
  }

  Future<void> _refresh() async {
    await AuthService.instance.refreshUser();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final verified = user?.emailVerified ?? false;
    if (verified) return widget.onContinue;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('A verification link was sent to ${user?.email ?? ''}. Please verify to enable full sync.'),
                const SizedBox(height: 12),
                if (message != null) Text(message!, style: const TextStyle(color: Colors.green)),
                const SizedBox(height: 8),
                ElevatedButton(onPressed: sending ? null : _resend, child: Text(sending ? 'Sending...' : 'Resend Email')),
                TextButton(onPressed: _refresh, child: const Text('I verified, refresh')),
                const SizedBox(height: 8),
                // Optional: allow entering app unverified
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => widget.onContinue),
                    );
                  },
                  child: const Text('Continue to app'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Staff model.
/// All fields are serializable to JSON so we can persist easily to SharedPreferences.
class Staff {
  String id; // unique id (could be UUID or simple timestamp/string)
  String name;
  double currentWeekHours; // hours input for the current week (raw, before breaks)
  double manualHolidayHours; // any manually added holiday hours (user-specified)
  double accumulatedWorkedHours; // totals across past saved weeks
  double accumulatedHolidayHours; // totals across past saved weeks (including auto 8% + manual)

  Staff({
    required this.id,
    required this.name,
    this.currentWeekHours = 0.0,
    this.manualHolidayHours = 0.0,
    this.accumulatedWorkedHours = 0.0,
    this.accumulatedHolidayHours = 0.0,
  });

  // Convert Staff to JSON map for persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'currentWeekHours': currentWeekHours,
        'manualHolidayHours': manualHolidayHours,
        'accumulatedWorkedHours': accumulatedWorkedHours,
        'accumulatedHolidayHours': accumulatedHolidayHours,
      };

  // Create Staff from JSON map
  factory Staff.fromJson(Map<String, dynamic> map) {
    return Staff(
      id: map['id'] as String,
      name: map['name'] as String,
      currentWeekHours: (map['currentWeekHours'] ?? 0).toDouble(),
      manualHolidayHours: (map['manualHolidayHours'] ?? 0).toDouble(),
      accumulatedWorkedHours: (map['accumulatedWorkedHours'] ?? 0).toDouble(),
      accumulatedHolidayHours: (map['accumulatedHolidayHours'] ?? 0).toDouble(),
    );
  }
}

/// Home page widget: displays roster and controls
class RosterHomePage extends StatefulWidget {
  const RosterHomePage({super.key});

  @override
  State<RosterHomePage> createState() => _RosterHomePageState();
}

class _RosterHomePageState extends State<RosterHomePage> {
  // Keys for SharedPreferences
  static const String _prefsStaffKey = 'roster_staff_data_v1';
  static const String _prefsShowBreaksSeparately = 'settings_show_breaks_separately';
  static const String _prefsDisableBreakDeductions = 'settings_disable_break_deductions';

  List<Staff> staffList = [];

  // Settings (persisted)
  bool showBreaksSeparately = true;
  bool disableBreakDeductions = false;

  late SharedPreferences prefs;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initPrefsAndLoad();
  }

  Future<void> _initPrefsAndLoad() async {
    prefs = await SharedPreferences.getInstance();
    _loadSettings();
    _loadStaff();
    setState(() {
      _loading = false;
    });
  }

  void _loadSettings() {
    showBreaksSeparately = prefs.getBool(_prefsShowBreaksSeparately) ?? true;
    disableBreakDeductions = prefs.getBool(_prefsDisableBreakDeductions) ?? false;
  }

  void _saveSettings() {
    prefs.setBool(_prefsShowBreaksSeparately, showBreaksSeparately);
    prefs.setBool(_prefsDisableBreakDeductions, disableBreakDeductions);
  }

  void _loadStaff() {
    final String? raw = prefs.getString(_prefsStaffKey);
    if (raw == null) {
      staffList = []; // keep empty as requested
      return;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      staffList = decoded.map((e) => Staff.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      // Something went wrong parsing - start with empty list to avoid crashing
      staffList = [];
    }
  }

  void _persistStaff() {
    final String encoded = jsonEncode(staffList.map((s) => s.toJson()).toList());
    prefs.setString(_prefsStaffKey, encoded);
  }

  /// Compute the break duration in hours based on total shift length (raw hours).
  /// Rules:
  /// - >= 6.0 hours -> 0.5 hr (30 min)
  /// - >= 4.5 hours -> 0.25 hr (15 min)
  /// - otherwise 0.0
  double _computeBreakHours(double shiftHours) {
    if (shiftHours >= 6.0) return 0.5;
    if (shiftHours >= 4.5) return 0.25;
    return 0.0;
  }

  /// Compute effective worked hours after break deduction (unless deductions are disabled).
  double _effectiveWorkedHours(double shiftHours) {
    final double breakHours = _computeBreakHours(shiftHours);
    if (disableBreakDeductions) return shiftHours;
    final double effective = shiftHours - breakHours;
    return effective < 0 ? 0 : effective;
  }

  /// Compute auto holiday hours (8% of worked hours).
  double _computeAutoHoliday(double workedHours) => workedHours * 0.08;

  /// "Save Week" accumulates each staff's current week into their totals.
  /// - Accumulated worked hours increases by effectiveWorkedHours
  /// - Auto holiday (8% of effective worked hours) is added
  /// - Manual holiday hours are kept separately (user can add them at any time)
  /// After saving, the currentWeekHours is reset to 0 (ready for next week).
  void _saveWeekAndAccumulate() {
    for (var s in staffList) {
      final double eff = _effectiveWorkedHours(s.currentWeekHours);
      final double autoHoliday = _computeAutoHoliday(eff);
      s.accumulatedWorkedHours += eff;
      s.accumulatedHolidayHours += (autoHoliday + s.manualHolidayHours);

      // Reset current week and manual additions (assumption: manual additions
      // are consumed into accumulated holiday upon saving; if you want to keep manual
      // as historical separate value, remove the next line).
      s.currentWeekHours = 0.0;
      s.manualHolidayHours = 0.0;
    }
    _persistStaff();
    setState(() {
      // just to trigger UI update
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Week saved — hours and holiday totals updated.')),
    );
  }

  /// Allows user to add manual holiday hours to a staff entry (these will be added to accumulated at save)
  Future<void> _showAddManualHolidayDialog(Staff staff) async {
    final TextEditingController controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add manual holiday hours — ${staff.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Hours to add (e.g. 2.5)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // cancel
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final String val = controller.text.trim();
                if (val.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                final double? add = double.tryParse(val);
                if (add == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid number')),
                  );
                  return;
                }
                setState(() {
                  staff.manualHolidayHours += add;
                });
                _persistStaff();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added ${add.toString()} hrs manual holiday')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Add a new staff member (simple dialog)
  Future<void> _showAddStaffDialog() async {
    final TextEditingController nameController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Staff Member'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final String name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a name')),
                  );
                  return;
                }
                final newStaff = Staff(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: name,
                );
                setState(() {
                  staffList.add(newStaff);
                });
                _persistStaff();
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            )
          ],
        );
      },
    );
  }

  /// Edit current week hours inline for a staff entry
  void _updateStaffCurrentHours(Staff s, String value) {
    final double? parsed = double.tryParse(value);
    setState(() {
      s.currentWeekHours = (parsed == null || parsed.isNaN) ? 0.0 : parsed;
    });
    _persistStaff();
  }

  /// Settings popup (small dialog with toggles)
  Future<void> _openSettingsPopup() async {
    bool localShowBreaks = showBreaksSeparately;
    bool localDisableDeds = disableBreakDeductions;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Show breaks separately'),
                  subtitle: const Text('When enabled, a separate line shows the break time.'),
                  value: localShowBreaks,
                  onChanged: (v) {
                    setDialogState(() => localShowBreaks = v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Disable break deductions'),
                  subtitle: const Text(
                      'When enabled, breaks are NOT deducted from worked hours (view raw hours).'),
                  value: localDisableDeds,
                  onChanged: (v) {
                    setDialogState(() => localDisableDeds = v);
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Holiday calculation: 8% of worked hours automatically added. You can also add manual holiday hours per staff.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showBreaksSeparately = localShowBreaks;
                    disableBreakDeductions = localDisableDeds;
                  });
                  _saveSettings();
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );
  }

  /// Remove staff entry
  void _removeStaff(Staff s) {
    setState(() {
      staffList.removeWhere((x) => x.id == s.id);
    });
    _persistStaff();
  }

  /// Reset everything (dangerous; used for dev/testing)
  Future<void> _confirmResetAll() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset all data?'),
          content: const Text('This will delete all staff and accumulated totals. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
          ],
        );
      },
    );
    if (ok == true) {
      setState(() {
        staffList.clear();
      });
      prefs.remove(_prefsStaffKey);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data reset.')));
    }
  }

  // UI builder for a single staff card row
  Widget _buildStaffCard(Staff s) {
    final double breakHours = _computeBreakHours(s.currentWeekHours);
    final double effective = _effectiveWorkedHours(s.currentWeekHours);
    final double autoHoliday = _computeAutoHoliday(effective);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: name + accumulated totals
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Accum. Worked: ${_formatDouble(s.accumulatedWorkedHours)} hrs'),
                Text('Accum. Holiday: ${_formatDouble(s.accumulatedHolidayHours)} hrs'),
              ]),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove staff',
                onPressed: () => _removeStaff(s),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Input for current week hours (raw)
          Row(
            children: [
              const SizedBox(width: 4),
              const Icon(Icons.access_time_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current week hours (raw)'),
                  controller: TextEditingController(text: s.currentWeekHours.toString())
                    // set caret to end by selecting nothing
                    ..selection = TextSelection.collapsed(offset: s.currentWeekHours.toString().length),
                  onChanged: (val) {
                    _updateStaffCurrentHours(s, val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Show breaks + effective hours info
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showBreaksSeparately)
              Text('Break: ${_formatDouble(breakHours)} hrs (${_breakLabel(breakHours)})'),
            Text('Effective worked hours: ${_formatDouble(effective)} hrs'
                '${disableBreakDeductions ? " (breaks not deducted)" : ""}'),
            const SizedBox(height: 6),
            Text(
                'Holiday this week (auto 8% of effective): ${_formatDouble(autoHoliday)} hrs  + manual: ${_formatDouble(s.manualHolidayHours)} hrs'),
            const SizedBox(height: 6),
            // Buttons: add manual holiday (per-staff) and quick zeroing of current week
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showAddManualHolidayDialog(s),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Holiday Hours'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      s.currentWeekHours = 0.0;
                    });
                    _persistStaff();
                  },
                  child: const Text('Clear Week Hours'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // Quick apply of a typical 8-hour work day (handy while testing)
                    setState(() {
                      s.currentWeekHours = 8.0;
                    });
                    _persistStaff();
                  },
                  child: const Text('Quick: 8 hrs'),
                ),
              ],
            ),
          ]),
        ]),
      ),
    );
  }

  String _breakLabel(double breakH) {
    if (breakH >= 0.5) return '30 min';
    if (breakH >= 0.25) return '15 min';
    return 'No break';
  }

  String _formatDouble(double v) {
    return (v.toStringAsFixed(v % 1 == 0 ? 0 : 2));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roster'),
        actions: [
          IconButton(
            onPressed: _openSettingsPopup,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reset') {
                _confirmResetAll();
              } else if (value == 'save') {
                _saveWeekAndAccumulate();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'save', child: Text('Save Week (accumulate)')),
              const PopupMenuItem(value: 'reset', child: Text('Reset All Data')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStaffDialog,
        tooltip: 'Add staff',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Short header with explanation & Save Week button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Enter each staff\'s hours for the current roster week. When ready, tap "Save Week" to store these hours into accumulated totals (and holiday hours will be added automatically: 8% of effective hours).',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _saveWeekAndAccumulate,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Week'),
                ),
              ],
            ),
          ),

          Expanded(
            child: staffList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No staff yet. Tap + to add staff.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _showAddStaffDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add staff'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 12, top: 12),
                    itemCount: staffList.length,
                    itemBuilder: (context, index) {
                      final s = staffList[index];
                      return _buildStaffCard(s);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
