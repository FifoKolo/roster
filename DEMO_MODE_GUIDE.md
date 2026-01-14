# Demo/Freemium Mode Implementation

## Overview

The Roster app now includes a **demo/freemium model** that allows users to:
- ✅ Test the app completely free with limited features
- ✅ Experience full functionality within demo limits
- ✅ Purchase to unlock unlimited features

## Demo Mode Limits

| Feature | Demo | Full |
|---------|------|------|
| Staff Members | 5 | Unlimited |
| Rosters | 3 | Unlimited |
| Weeks per Roster | 4 | Unlimited |
| Cloud Sync | ❌ | ✅ (Coming Soon) |
| Multi-Device Sync | ❌ | ✅ (Coming Soon) |
| Data Export | ✅ | ✅ |
| PDF Export | ✅ | ✅ |

## How It Works

### Default Behavior
- **New users start in DEMO mode** by default
- Full features available without sign-up
- No login required to try the app
- All data saved locally

### Demo Limits Enforcement
When users hit a limit, they see:
1. **Demo Limit Dialog** - Explains the limitation
2. **Upgrade Button** - Prompts them to purchase
3. **Banner** - Shows current mode status

### Purchasing
- Users upgrade to unlock all features
- Purchase date is saved locally
- No need to re-download the app
- Instant upgrade on purchase

## Implementation Details

### Files Added

1. **[lib/services/license_service.dart](../lib/services/license_service.dart)**
   - Manages demo/full mode status
   - Checks license limits
   - Provides upgrade prompts

2. **[lib/widgets/demo_mode_widgets.dart](../lib/widgets/demo_mode_widgets.dart)**
   - `DemoModeBanner` - Shows current mode
   - `DemoLimitDialog` - Shows limit reached message
   - `showDemoLimitDialog()` - Helper function

### How to Use

#### Check if user is in demo mode
```dart
bool isDemo = await LicenseService.isDemoMode();
bool isPurchased = await LicenseService.isPurchased();
```

#### Check if user can add more staff
```dart
bool canAdd = await LicenseService.canAddMoreStaff(currentStaffCount);
if (!canAdd) {
  showDemoLimitDialog(context, limitType: 'staff');
}
```

#### Check remaining demo slots
```dart
int remaining = await LicenseService.remainingStaffSlots(currentCount);
print('$remaining staff slots remaining');
```

#### Mark app as purchased
```dart
// This would be called after successful payment
await LicenseService.markAsPurchased();
```

#### Get demo status message
```dart
String status = await LicenseService.getDemoStatus();
print(status);
```

## Integration Points

### When Creating New Staff
```dart
int staffCount = employees.length;
if (!await LicenseService.canAddMoreStaff(staffCount)) {
  showDemoLimitDialog(context, limitType: 'staff');
  return; // Don't allow adding
}
```

### When Creating New Roster
```dart
int rosterCount = rosterNames.length;
if (!await LicenseService.canAddMoreRosters(rosterCount)) {
  showDemoLimitDialog(context, limitType: 'rosters');
  return;
}
```

### In App Header
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      // ... other content
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: DemoModeBanner(
          onUpgradePressed: () => _openUpgradeFlow(context),
        ),
      ),
    ),
  );
}
```

## Testing Demo Mode

### Test Demo Limits
```dart
// Reset to demo mode
await LicenseService.resetToDemo();

// Test limits
bool canAdd = await LicenseService.canAddMoreStaff(5);
// Returns false if demo limit reached
```

### Test Purchase
```dart
// Simulate purchase
await LicenseService.markAsPurchased();

// Test unlimited features
bool canAdd = await LicenseService.canAddMoreStaff(1000);
// Returns true - unlimited
```

### View Status
```dart
String status = await LicenseService.getDemoStatus();
print(status);
```

## Monetization Strategy

### Phase 1: Demo Mode (Current)
- Free trial with limits
- Tests core features
- No ads or upsell

### Phase 2: In-App Purchase (Future)
- One-time purchase to unlock full app
- Suggested price: €4.99 - €9.99
- Includes future cloud features

### Phase 3: Cloud Features (Future)
- Cloud sync between devices
- Multi-device access
- Optional subscription: €2.99/month or €19.99/year

### Phase 4: Business Tier (Future)
- Team collaboration
- Advanced reporting
- Enterprise support

## User Experience Flow

```
User Opens App
    ↓
Demo Mode Active
    ├─ Can use with 5 staff, 3 rosters, 4 weeks
    ├─ Sees "Demo Mode" banner
    └─ Sees "Upgrade" button
    
User Hits Limit
    ├─ Demo Limit Dialog shown
    ├─ Explanation of limits
    └─ "Upgrade Now" button
    
User Upgrades
    ├─ Payment processed
    ├─ App marked as purchased
    ├─ Full features unlocked
    └─ Banner shows "🔓 Full Version"

User Has Full Version
    ├─ Unlimited staff, rosters, weeks
    ├─ Ready for cloud features
    └─ Enhanced app experience
```

## Best Practices

### Don't Show Upgrade Prompts Too Aggressively
- Only show when user actually hits a limit
- Not on app startup
- Not every action

### Make Demo Experience Great
- Limits should be generous enough to test features
- Current limits: 5 staff, 3 rosters, 4 weeks
- Adjustable based on user feedback

### Clear Upgrade Path
- Simple one-click upgrade
- Clear pricing
- Instant activation
- Show what user gains

### Respect User Data
- Demo data persists
- No data loss on upgrade
- User's work is preserved

## Future Enhancements

1. **Social Proof**
   - Show ratings/reviews in upgrade prompt
   - "Used by X companies"

2. **Seasonal Promotions**
   - Limited-time discounts
   - Bundle offers

3. **Referral System**
   - Reward users for referrals
   - Extend trial or discount

4. **Email Reminders**
   - "You're almost at the limit"
   - "Don't lose your progress - upgrade now"

5. **A/B Testing**
   - Different prompt styles
   - Optimal timing
   - Best messaging

## Configuration

To adjust demo limits, edit `LicenseService`:

```dart
class LicenseService {
  // Adjust these constants
  static const int maxStaffInDemo = 5;        // Change limit
  static const int maxRostersInDemo = 3;      // Change limit
  static const int maxWeeksInDemo = 4;        // Change limit
}
```

---

**Status:** ✅ Implemented and ready to use  
**Default Mode:** Demo (Free)  
**Purchase System:** Ready for integration  
**Cloud Features:** Planned for Phase 3

Enjoy your freemium Roster app! 🚀
