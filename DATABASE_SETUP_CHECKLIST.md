# Database Setup Checklist - Complete Steps

## ✅ PHASE 1: Firebase Project Setup (5 minutes)

### Step 1: Create Firebase Project
- [ ] Go to [Firebase Console](https://console.firebase.google.com/)
- [ ] Click "Add project"
- [ ] Project name: "Roster App" (or your preference)
- [ ] Accept terms and create

### Step 2: Enable Google Sign-In
- [ ] In Firebase Console, go to **Authentication** → **Sign-in method**
- [ ] Click **Google**
- [ ] Toggle "Enable" → **Save**
- [ ] You'll see: "Web SDK configuration" - save this info

### Step 3: Create Firestore Database
- [ ] Go to **Firestore Database** (left menu)
- [ ] Click **Create database**
- [ ] Choose region (closest to you is best)
- [ ] Start in **Production mode**
- [ ] Click **Create**
- [ ] **Database created!** ✅

---

## ✅ PHASE 2: Set Security Rules (2 minutes)

### Step 4: Add Security Rules
- [ ] In **Firestore Database** → **Rules** tab
- [ ] Copy & paste this (replaces default):

```firestore
rules_version = '3';

service cloud.firestore {
  match /databases/{database}/documents {
    // Only allow access to user's own data
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth.uid == uid;
    }
    
    // Allow creation of user document
    match /users/{uid} {
      allow create: if request.auth.uid == uid;
    }
  }
}
```

- [ ] Click **Publish** ✅

---

## ✅ PHASE 3: Download Config Files (2 minutes)

### Step 5: Get google-services.json (Android)
- [ ] In Firebase Console, click **⚙️ Project Settings** (top-left)
- [ ] Go to **Your apps** section
- [ ] Find or create your Android app
- [ ] Click **google-services.json** download button
- [ ] Replace the file at: `android/app/google-services.json`

### Step 6: Get GoogleService-Info.plist (iOS - if building for iOS)
- [ ] In **⚙️ Project Settings** → **Your apps**
- [ ] Find or create iOS app
- [ ] Download **GoogleService-Info.plist**
- [ ] Add to Xcode project at: `ios/Runner/`

---

## ✅ PHASE 4: Update Code Config (1 minute)

### Step 7: Update firebase_options.dart
- [ ] Open [Firebase Console](https://console.firebase.google.com/) → **Project Settings** → **Your apps**
- [ ] Click your app to see Web SDK config
- [ ] You'll see JSON like:
```json
{
  "apiKey": "AIza...",
  "appId": "1:123456:web:abc...",
  "messagingSenderId": "123456",
  "projectId": "your-project-id",
  "authDomain": "your-project-id.firebaseapp.com",
  "databaseURL": "https://your-project-id.firebaseio.com",
  "storageBucket": "your-project-id.appspot.com"
}
```

- [ ] Open `lib/firebase_options.dart`
- [ ] Update the `web` section with your values:
```dart
const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY_HERE',
  appId: 'YOUR_APP_ID_HERE',
  messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
  projectId: 'your-project-id',
  authDomain: 'your-project-id.firebaseapp.com',
  databaseURL: 'https://your-project-id.firebaseio.com',
  storageBucket: 'your-project-id.appspot.com',
);
```

---

## ✅ PHASE 5: Verify Installation (3 minutes)

### Step 8: Run App & Test Connection
- [ ] Open terminal in project root
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter run`

### Step 9: Check Logs for Firebase
- [ ] Look for these lines in terminal (green checkmark):
```
I/Firestore: (VERSION) Initializing Firestore Core
I/FA     : Registered AnalyticsConnectorListener
[✓] Firebase initialization successful
```

✅ **If you see "Firebase initialization successful" - Database is connected!**

### Step 10: Test Sign-In (Optional but recommended)
- [ ] In app, look for Google Sign-In button
- [ ] Click to sign in with Google
- [ ] Check Firebase Console → **Authentication**
- [ ] Your account should appear in "Users" list
- [ ] ✅ **Real-time connection working!**

---

## ✅ PHASE 6: Verify Data Storage (2 minutes)

### Step 11: Create a Test Roster
- [ ] In app, create a new roster (any name, e.g., "Test Roster")
- [ ] Add a few employees
- [ ] Don't sign out yet!

### Step 12: Check Firestore Console
- [ ] Go to [Firebase Console](https://console.firebase.google.com/) → **Firestore Database** → **Data**
- [ ] Look for collection: `users`
- [ ] Open your user ID (UUID string)
- [ ] Open `rosters` collection
- [ ] You should see your "Test Roster" with employees! ✅

---

## ✅ PHASE 7: Test Offline Functionality (2 minutes)

### Step 13: Enable Offline Mode
- [ ] Disable internet on your device/emulator
- [ ] In app, make changes (add/edit/delete an employee)
- [ ] Changes save to local cache instantly ✅
- [ ] Re-enable internet
- [ ] Changes auto-sync to Firestore ✅

---

## ❌ TROUBLESHOOTING

### "Firebase initialization failed"
**Solution:**
1. Check internet connection
2. Verify `firebase_options.dart` has correct values
3. Run `flutter clean && flutter pub get`
4. Check Android build.gradle has correct Google Play Services

### "Permission denied" errors in Firestore
**Solution:**
1. Go to Firestore Console → Rules tab
2. Check rules are published (blue "PUBLISHED" badge)
3. Verify security rules match the code above
4. Sign in again

### Data not appearing in Firestore
**Solution:**
1. Verify you're signed in (check Firebase Console → Authentication)
2. Check your user ID matches in console
3. Look at Firestore Console logs for errors
4. Try creating roster again while watching Firestore in real-time

### "Collection not found"
**Solution:**
- This is normal! Firestore creates collections when first document is added
- Create a roster in app → collection appears automatically

---

## 📊 Database Structure Reference

```
Firestore Collections:
├── users/
│   └── {userId}  (auto-created on sign-in)
│       ├── rosters/
│       │   ├── {rosterName}/
│       │   │   ├── createdAt: Timestamp
│       │   │   ├── employees/ (subcollection)
│       │   │   │   └── {employeeId}/
│       │   │   │       ├── name: String
│       │   │   │       ├── salary: Number
│       │   │   │       ├── ...
│       ├── trash/
│       │   └── {trashId}/
│       │       ├── rosterName: String
│       │       ├── deletedAt: Timestamp
│
Local Storage (SharedPreferences):
├── rosters_backup
├── latest_roster
├── last_opened_roster
```

---

## ✅ QUICK VERIFICATION

**Run this in app debug console:**
```dart
// Test 1: Check local storage
final local = await RosterStorage.watchRosterNames().first;
print('Local rosters: $local');

// Test 2: Check Firebase Auth
final user = FirebaseAuth.instance.currentUser;
print('Signed in: ${user?.email}');

// Test 3: Check Firestore
final docs = await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .collection('rosters')
    .get();
print('Cloud rosters: ${docs.docs.length}');
```

---

## 🎯 You're Done!

When all checkboxes above are ✅, your database is fully operational:
- ✅ Firebase project created
- ✅ Firestore database active
- ✅ Security rules deployed
- ✅ App connected to cloud
- ✅ Data syncing in real-time
- ✅ Offline support working

**Next:** Integrate demo mode to the app (limits 5 staff, 3 rosters, 4 weeks)

---

## 📱 Platform-Specific Notes

### Android
- google-services.json must be in `android/app/`
- Android min SDK: 21+
- Google Play Services auto-manages certificates

### iOS
- GoogleService-Info.plist in Xcode project
- iOS min version: 11.0+
- Pod dependencies auto-installed

### Web
- Works with browser storage
- No native config file needed
- Uses API key from firebase_options.dart

---

## 💡 Pro Tips

1. **Never commit secrets** - Add `firebase_options.dart` to `.gitignore` if it has real keys
2. **Use emulator first** - Test locally before deploying
3. **Monitor Firestore usage** - Check Firebase Console → Usage for costs (free tier is generous)
4. **Backup rules** - Keep your Firestore rules saved separately
5. **Test thoroughly** - Enable/disable offline to verify fallback logic

