# Orientation Locking Implementation

## Overview
The roster app now intelligently manages screen orientation:
- **Locked to Landscape** when viewing the roster (to see all 7 days at once)
- **Unlocked to Portrait/Landscape** when editing shifts or viewing employee profiles (for comfortable typing)
- **Automatically switches** back to landscape when you close the dialog

## How It Works

### 1. New Service: `OrientationService` (`lib/services/orientation_service.dart`)

This service manages all orientation changes:

```dart
// Lock to landscape only
await OrientationService.lockToLandscape();

// Allow both portrait and landscape
await OrientationService.unlockOrientation();

// Reset to default (all orientations)
await OrientationService.resetOrientation();
```

### 2. Main App Flow

**On App Start** (`main.dart`):
```dart
// Initialize orientation - allow all directions by default
await OrientationService.resetOrientation();
```

**When Viewing Roster** (`roster_page.dart`):
```dart
@override
void initState() {
  OrientationService.lockToLandscape();  // Lock when page opens
}

@override
void dispose() {
  OrientationService.unlockOrientation();  // Unlock when leaving page
}
```

**When Editing a Shift** (`modern_roster_table.dart`):
```dart
Future<void> _editShift(Employee employee, String day, Shift? shift) async {
  // Unlock for comfortable editing
  await OrientationService.unlockOrientation();
  
  final editedShift = await widget.onEdit(context, shift);
  
  // Lock back to landscape
  await OrientationService.lockToLandscape();
}
```

**When Opening Add/Edit Dialog** (`add_shift_dialog.dart`):
```dart
@override
void initState() {
  OrientationService.unlockOrientation();  // Unlock in dialog
}

@override
void dispose() {
  OrientationService.lockToLandscape();  // Re-lock after dialog closes
}
```

## User Experience Flow

### Typical Usage Scenario

```
1. User opens app
   └─ App starts with all orientations unlocked

2. User navigates to roster (RosterPage)
   └─ 🔒 Orientation locked to LANDSCAPE
   └─ User can now see all 7 days at once
   └─ If user rotates phone → nothing happens (locked)

3. User taps on a shift to edit
   └─ 🔓 Orientation unlocked
   └─ Add/Edit Shift Dialog opens
   └─ User can now rotate phone to portrait for comfortable typing
   └─ Full keyboard is visible, more space for input

4. User finishes editing and closes dialog
   └─ Dialog disappears
   └─ 🔒 Orientation locked back to LANDSCAPE
   └─ Roster view returns to landscape lock

5. User taps employee profile
   └─ 🔓 Orientation unlocked
   └─ Employee profile dialog opens
   └─ User can view/edit in portrait if desired

6. User closes employee profile
   └─ 🔓 Orientation stays unlocked (profile dialog uses .then())
   └─ 🔒 Then locks back to LANDSCAPE
```

## What Changed

### Files Modified

1. **`lib/services/orientation_service.dart`** (NEW)
   - New service to manage orientation locking
   - Three main methods: `lockToLandscape()`, `unlockOrientation()`, `resetOrientation()`

2. **`lib/main.dart`**
   - Imports OrientationService
   - Calls `OrientationService.resetOrientation()` on app start

3. **`lib/screens/roster_page.dart`**
   - Imports OrientationService
   - Locks to landscape in `initState()`
   - Unlocks in `dispose()`

4. **`lib/widgets/modern_roster_table.dart`**
   - Imports OrientationService
   - Modified `_editShift()` to unlock before dialog and re-lock after
   - Modified `_showEmployeeProfile()` to unlock before dialog and re-lock after

5. **`lib/widgets/add_shift_dialog.dart`**
   - Imports OrientationService
   - Unlocks in `initState()` (in case it wasn't already)
   - Re-locks in `dispose()` when dialog is closed

## Technical Details

### Using `SystemChrome.setPreferredOrientations()`

The implementation uses Flutter's native API:

```dart
// Lock to landscape
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);

// Allow all orientations
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
]);
```

### Why `.then()` for Profile Dialog?

```dart
showDialog(
  context: context,
  builder: (context) => EmployeeProfileDialog(...),
).then((_) {
  // This runs after the dialog closes
  OrientationService.lockToLandscape();
});
```

This ensures orientation is re-locked after the profile dialog is dismissed.

## Benefits

✅ **Better UX** - Users don't have to type in cramped landscape mode
✅ **Smart Behavior** - App knows when to lock and unlock automatically
✅ **Less Confusion** - Users can't accidentally rotate and lose their place
✅ **Comfortable Editing** - Full portrait mode available for data entry
✅ **Professional Feel** - Just like real roster management apps

## Testing

### Test Scenario 1: Landscape Lock Works
1. Open app and navigate to roster
2. Try to rotate phone - should stay in landscape
3. Phone orientation sensor should be ignored ✓

### Test Scenario 2: Portrait Unlock Works
1. In roster, tap a shift to edit
2. Rotate phone to portrait
3. Phone should rotate to portrait ✓
4. Close dialog
5. Phone should rotate back to landscape ✓

### Test Scenario 3: Employee Profile
1. In roster, tap employee name to open profile
2. Rotate phone - should allow portrait ✓
3. Close profile dialog
4. Should return to landscape ✓

## Future Enhancements

Could also add:
- User preference to "always allow portrait"
- Orientation toggle button in the app bar
- Different behavior for tablets (might want to always allow rotation)
- Smooth transition animations (optional)

## No Mobile App Store Issues

This implementation:
- ✅ Uses standard Flutter APIs
- ✅ No deprecated methods
- ✅ Works on iOS and Android
- ✅ No permission issues
- ✅ Won't cause app store rejection

---

**Status:** ✅ Complete and ready to test
**Files Changed:** 6 files
**New Files:** 1 file (OrientationService)
**Breaking Changes:** None
