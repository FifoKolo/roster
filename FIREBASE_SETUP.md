# Firebase Database Setup Guide

## Overview

The Roster app now includes full Firebase integration with Firestore database support. The app intelligently switches between cloud sync and local-only mode based on authentication status and network connectivity.

## Features Implemented

✅ **Cloud Firestore Integration**
- Real-time data synchronization across devices
- Automatic offline support with local caching
- Efficient batch operations for better performance

✅ **Hybrid Storage Mode**
- Cloud sync when user is authenticated
- Automatic fallback to local storage when offline
- Seamless transition between modes

✅ **Complete CRUD Operations**
- Create, read, update, and delete rosters
- Employee management within rosters
- Trash/restore functionality
- Settings persistence

## Architecture

### Service Layer

1. **FirestoreService** (`lib/services/firestore_service.dart`)
   - Handles all Firestore operations
   - Manages user-scoped data collections
   - Provides real-time streams for live updates

2. **RosterStorage** (`lib/services/roster_storage.dart`)
   - Abstraction layer over Firestore and local storage
   - Automatically switches between cloud and local modes
   - Handles synchronization logic

3. **AuthService** (`lib/services/auth_service.dart`)
   - Manages Firebase Authentication
   - Automatically configures storage mode on auth state changes

### Data Structure in Firestore

```
users/
  {userId}/
    rosters/
      {rosterName}/
        - createdAt: Timestamp
        - updatedAt: Timestamp
        - employeeCount: Number
        employees/
          {employeeName}/
            - name: String
            - shifts: Map<String, Shift>
            - accumulatedWorkedHours: Number
            - accumulatedTotalHours: Number
            - accumulatedHolidayHours: Number
            - employeeColor: Number (ARGB)
            - ...other employee fields
    settings/
      {settingKey}/
        - value: Any
        - updatedAt: Timestamp
    trash/
      {trashItemId}/
        - originalName: String
        - deletedAt: Timestamp
        - employees: Array<Employee>
```

## How It Works

### Authentication Flow

1. **User Signs In**
   ```dart
   AuthService.instance.signIn(email, password)
   ```
   - Firebase Auth authenticates the user
   - AuthService listener detects auth state change
   - RosterStorage.configureCloud(uid) is called automatically
   - All subsequent operations use cloud storage

2. **User Signs Out**
   - AuthService listener detects sign-out
   - RosterStorage.configureCloud(null) switches to local mode
   - Data persists locally using SharedPreferences

### Data Synchronization

**Automatic Sync:**
- All roster operations automatically sync to cloud when online
- Data is also saved locally for offline support
- Real-time streams update UI when data changes in cloud

**Offline Support:**
- Firestore SDK provides automatic offline persistence
- Local SharedPreferences serves as additional backup
- Operations work seamlessly offline and sync when connection restored

### Usage Examples

**Watch Roster Names (Real-time):**
```dart
RosterStorage.watchRosterNames().listen((names) {
  // UI updates automatically when rosters are added/removed
});
```

**Load a Roster:**
```dart
final employees = await RosterStorage.loadRoster('Week 1');
// Returns cloud data if authenticated, local data otherwise
```

**Save Changes:**
```dart
await RosterStorage.saveRoster('Week 1', employees);
// Saves to cloud if authenticated, local storage otherwise
// Also caches locally for offline support
```

## Firebase Console Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name (e.g., "roster-app")
4. Follow the setup wizard

### 2. Enable Firestore Database

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in production mode"
4. Select a location (choose closest to your users)
5. Click "Enable"

### 3. Set Firestore Security Rules

In the Firestore "Rules" tab, add the following rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // User data - users can only access their own data
    match /users/{userId} {
      allow read, write: if isOwner(userId);
      
      // Rosters collection
      match /rosters/{rosterName} {
        allow read, write: if isOwner(userId);
        
        // Employees sub-collection
        match /employees/{employeeId} {
          allow read, write: if isOwner(userId);
        }
      }
      
      // Settings collection
      match /settings/{settingKey} {
        allow read, write: if isOwner(userId);
      }
      
      // Trash collection
      match /trash/{trashItemId} {
        allow read, write: if isOwner(userId);
      }
    }
  }
}
```

### 4. Enable Firebase Authentication

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Enable "Email/Password" provider
4. Save changes

### 5. Add Users

You can add users in two ways:

**Option 1: Firebase Console**
1. Go to "Authentication" > "Users"
2. Click "Add user"
3. Enter email and password

**Option 2: App Sign-Up**
- Users can sign up through the app's sign-up screen
- Email verification is automatically sent

## Testing Firebase Integration

### Test Cloud Sync

1. **Sign In on Device 1:**
   ```
   - Sign in with your Firebase account
   - Create a roster
   - Add employees and shifts
   ```

2. **Sign In on Device 2:**
   ```
   - Sign in with the same account
   - You should see the roster automatically appear
   ```

3. **Make Changes:**
   ```
   - Edit shifts on Device 1
   - Device 2 should update in real-time
   ```

### Test Offline Mode

1. **Disconnect from Internet:**
   ```
   - Turn off WiFi/mobile data
   - App should still work normally
   - Changes are saved locally
   ```

2. **Reconnect:**
   ```
   - Turn WiFi back on
   - Changes should sync automatically
   ```

### Test Local-Only Mode

1. **Sign Out:**
   ```
   - Sign out from your account
   - App switches to local-only mode
   - All data persists on device
   ```

2. **Create Local Data:**
   ```
   - Create rosters while signed out
   - Data saved to SharedPreferences only
   ```

## Monitoring and Debugging

### View Data in Firebase Console

1. Go to Firestore Database in Firebase Console
2. Browse the `users` collection
3. Navigate to `users/{userId}/rosters` to see your rosters

### Enable Debug Logging

The app includes comprehensive logging:
- `☁️` - Cloud operations
- `📱` - Local operations
- `✅` - Success messages
- `❌` - Error messages
- `🔍` - Debug information

Check your IDE console for detailed logs.

### Common Issues

**Issue: "User not configured" error**
- **Solution:** Make sure user is signed in before accessing rosters

**Issue: Data not syncing**
- **Solution:** Check internet connection and Firestore rules
- Verify user is authenticated
- Check Firebase Console for any rule violations

**Issue: "Permission denied" errors**
- **Solution:** Verify Firestore security rules are set correctly
- Ensure user is accessing only their own data

## Performance Optimization

### Firestore Best Practices Implemented

1. **Batch Operations:**
   - Multiple employee updates are batched together
   - Reduces number of writes and improves performance

2. **Offline Persistence:**
   - Firestore automatically caches data locally
   - Reduces network requests and improves app responsiveness

3. **Real-time Listeners:**
   - Only active rosters have active listeners
   - Listeners are properly cleaned up when not needed

4. **Metadata Updates:**
   - Roster metadata (employee count, last updated) maintained separately
   - Avoids loading full roster data for list views

## Cost Considerations

### Firestore Pricing (Free Tier)

- **Reads:** 50,000 per day
- **Writes:** 20,000 per day
- **Deletes:** 20,000 per day
- **Storage:** 1 GB
- **Network:** 10 GB per month

### Estimated Usage

For a typical user:
- **Daily Reads:** ~100-500 (roster list + employee data)
- **Daily Writes:** ~50-200 (shift updates, settings)
- **Storage:** ~1-10 MB per user

Most users will stay well within the free tier limits.

## Future Enhancements

Potential improvements for the Firebase integration:

1. **Cloud Functions:**
   - Automated backups
   - Data validation
   - Email notifications

2. **Analytics:**
   - Track roster usage patterns
   - Monitor app performance

3. **Storage:**
   - Upload PDF exports to Firebase Storage
   - Sync across devices

4. **Push Notifications:**
   - Roster change notifications
   - Reminder notifications

## Support

For issues or questions:
1. Check the console logs for error messages
2. Verify Firebase setup in Firebase Console
3. Review Firestore security rules
4. Check network connectivity

---

**Last Updated:** January 14, 2026
**Firebase SDK Version:** 
- firebase_core: ^3.8.0
- firebase_auth: ^5.3.1
- cloud_firestore: ^5.5.0
