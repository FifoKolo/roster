# Quick Integration: Demo Mode & License System

## 1. Initialize License Service in main.dart

Add this to your `main()` function:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize time service
  await TimeService.initialize();
  
  // Initialize license service
  await LicenseService.initialize();
  
  // ... rest of initialization
  runApp(RosterApp(localOnly: localOnly));
}
```

## 2. Add Demo Mode Banner to Roster Manager

In `roster_manager.dart`, add to the AppBar:

```dart
AppBar(
  title: const Text('Roster App'),
  elevation: 0,
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(40),
    child: DemoModeBanner(
      onUpgradePressed: () => _showUpgradeScreen(context),
    ),
  ),
)
```

## 3. Protect Staff Creation

In `roster_page.dart` or wherever you add staff:

```dart
Future<void> _addEmployee() async {
  // Check demo limit
  if (!await LicenseService.canAddMoreStaff(employees.length)) {
    if (!mounted) return;
    showDemoLimitDialog(
      context,
      limitType: 'staff members',
      onUpgradePressed: () => _showUpgradeScreen(context),
    );
    return;
  }
  
  // Continue with adding staff
  // ... rest of code
}
```

## 4. Protect Roster Creation

In `roster_manager.dart` when creating new rosters:

```dart
Future<void> _createNewRoster(String name) async {
  // Get current roster count
  final names = await RosterStorage.watchRosterNames().first;
  
  // Check demo limit
  if (!await LicenseService.canAddMoreRosters(names.length)) {
    if (!mounted) return;
    showDemoLimitDialog(
      context,
      limitType: 'rosters',
      onUpgradePressed: () => _showUpgradeScreen(context),
    );
    return;
  }
  
  // Continue with creating roster
  // ... rest of code
}
```

## 5. Add Upgrade Screen

Create a simple upgrade screen:

```dart
void _showUpgradeScreen(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.star, color: Colors.amber),
          SizedBox(width: 8),
          Text('Upgrade to Full Version'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock unlimited access to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const _FeatureRow('Unlimited staff members'),
            const _FeatureRow('Unlimited rosters'),
            const _FeatureRow('Unlimited weeks'),
            const _FeatureRow('Cloud synchronization (coming soon)'),
            const _FeatureRow('Multi-device support (coming soon)'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '💡 One-time purchase, lifetime access!',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // TODO: Implement in-app purchase
            _processPurchase();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
          ),
          child: const Text('Buy Now - €4.99'),
        ),
      ],
    ),
  );
}

class _FeatureRow extends StatelessWidget {
  final String feature;
  const _FeatureRow(this.feature);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(feature)),
        ],
      ),
    );
  }
}

void _processPurchase() {
  // TODO: Integrate with:
  // - iOS: StoreKit2
  // - Android: Google Play Billing
  // - Web: Stripe/PayPal
  
  // For now, mark as purchased for testing:
  LicenseService.markAsPurchased();
  
  print('Purchase processed!');
}
```

## 6. Add Imports to Files

Add these imports to files that use the new features:

```dart
// In roster_manager.dart
import 'package:roster/services/license_service.dart';
import 'package:roster/widgets/demo_mode_widgets.dart';

// In roster_page.dart
import 'package:roster/services/license_service.dart';
import 'package:roster/widgets/demo_mode_widgets.dart';
```

## 7. Testing

### Test Demo Mode
```dart
// In app settings or debug menu:
await LicenseService.resetToDemo();
```

### Test Purchased Mode
```dart
await LicenseService.markAsPurchased();
```

### View Current Status
```dart
final status = await LicenseService.getDemoStatus();
print(status);
```

## 8. Firebase Integration (Optional)

When ready to add cloud features:

```dart
// In license_service.dart, add cloud methods:
static Future<bool> shouldUseCloud() async {
  return await isPurchased(); // Cloud features only in full version
}

// In firestore_service.dart:
@override
Future<List<String>> getRosterNames() async {
  if (!await LicenseService.shouldUseCloud()) {
    // Use local storage instead
    return [];
  }
  // Use Firestore
}
```

## 9. Adjust Limits as Needed

Current demo limits in `LicenseService`:
- **5 staff** - Enough to test all features
- **3 rosters** - Different roster types
- **4 weeks** - Full month of planning

Adjust based on user feedback:
```dart
// More generous demo?
static const int maxStaffInDemo = 10;
static const int maxRostersInDemo = 5;
static const int maxWeeksInDemo = 8;
```

## Summary

✅ Users start with demo mode by default  
✅ Full feature testing with fair limits  
✅ Clear upgrade path when limits hit  
✅ One-time purchase model  
✅ No sign-up required to start  
✅ Future cloud features for premium users  

Your app now has a complete freemium model! 🚀

Next step: Integrate with in-app purchase system (Google Play, App Store, etc.)
