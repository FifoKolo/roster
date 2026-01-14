# Firebase Quick Reference

## 🚀 Quick Start

### 1. Firebase Console Setup (5 minutes)
```
1. Go to https://console.firebase.google.com
2. Create new project or select existing
3. Enable Firestore Database (Production mode)
4. Enable Authentication → Email/Password
5. Set security rules (see firestore.rules file)
```

### 2. Test the App
```
Option A: Local Mode (No Firebase Required)
  - Just open the app
  - Works offline, saves to device only

Option B: Cloud Mode
  - Sign in with Firebase account
  - Data syncs to cloud automatically
  - Works across devices
```

## 📊 Data Structure

```
Firestore Database
└── users/
    └── {userId}/
        ├── rosters/
        │   └── {rosterName}/
        │       ├── metadata (createdAt, updatedAt, employeeCount)
        │       └── employees/
        │           └── {employeeName}/
        │               └── employee data (shifts, hours, etc.)
        ├── settings/
        │   └── {settingKey}/
        │       └── value, updatedAt
        └── trash/
            └── {trashItemId}/
                └── deleted roster data
```

## 🔑 Key Concepts

### Mode Switching
| User State | Storage Mode | Data Location |
|------------|--------------|---------------|
| Not signed in | Local | SharedPreferences |
| Signed in + Online | Cloud | Firestore + Local cache |
| Signed in + Offline | Local (queued) | Local cache → Syncs when online |

### Automatic Behaviors
- ✅ Sign in → Cloud mode enabled
- ✅ Sign out → Local mode enabled
- ✅ Offline → Uses local cache
- ✅ Online → Syncs automatically

## 🛠️ Common Operations

### Create User Account
```
1. Open app
2. Click "Sign Up"
3. Enter email and password
4. Verify email (check inbox)
```

### View Your Data in Firebase Console
```
1. Go to Firestore Database
2. Navigate to: users → {your-uid} → rosters
3. See real-time data
```

### Debug Issues
```
1. Check app console logs for emoji indicators:
   ☁️ = Cloud operation
   📱 = Local operation
   ✅ = Success
   ❌ = Error
   
2. Check Firebase Console → Firestore → "Rules playground"
3. Test your security rules
```

## 📝 Security Rules (Quick Copy)

Paste these rules in Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## 💾 Storage Quotas (Free Tier)

| Resource | Free Tier Limit | Typical Daily Usage |
|----------|----------------|---------------------|
| Reads | 50,000/day | ~100-500 |
| Writes | 20,000/day | ~50-200 |
| Deletes | 20,000/day | ~10-50 |
| Storage | 1 GB | ~1-10 MB/user |
| Network | 10 GB/month | Minimal |

**Verdict:** You'll stay within free tier ✅

## 🔧 Troubleshooting

### "Permission denied" errors
```
Cause: Security rules not set or user not authenticated
Fix: 
  1. Check Firebase Console → Firestore → Rules
  2. Make sure user is signed in
  3. Verify userId matches in rules
```

### Data not syncing
```
Cause: Network issue or Firestore offline
Fix:
  1. Check internet connection
  2. Check Firebase status: https://status.firebase.google.com
  3. Look for ❌ errors in console logs
```

### App crashes on startup
```
Cause: Firebase initialization failed
Fix:
  1. Verify google-services.json is present (Android)
  2. Verify firebase_options.dart is correct
  3. Check console for Firebase errors
  4. App will fallback to local mode automatically
```

## 📱 Testing Checklist

- [ ] App opens without Firebase (local mode)
- [ ] Can create and save rosters locally
- [ ] Sign up creates new user
- [ ] Email verification sent
- [ ] Sign in switches to cloud mode
- [ ] Roster created in cloud appears in Firebase Console
- [ ] Second device shows same data after sign in
- [ ] Offline edits sync when back online
- [ ] Sign out switches to local mode

## 🎯 Next Steps

1. **Now:** Test local mode (works immediately)
2. **Next:** Set up Firebase Console (5 min)
3. **Then:** Create test account and sign in
4. **Finally:** Test cloud sync on multiple devices

## 📚 Files Reference

| File | Purpose |
|------|---------|
| [firestore.rules](firestore.rules) | Security rules for Firebase Console |
| [FIREBASE_SETUP.md](FIREBASE_SETUP.md) | Complete setup guide |
| [FIREBASE_INTEGRATION_SUMMARY.md](FIREBASE_INTEGRATION_SUMMARY.md) | Implementation details |
| [lib/services/firestore_service.dart](lib/services/firestore_service.dart) | Cloud database operations |
| [lib/services/roster_storage.dart](lib/services/roster_storage.dart) | Hybrid storage controller |

---

**Need detailed help?** See [FIREBASE_SETUP.md](FIREBASE_SETUP.md)  
**Want implementation details?** See [FIREBASE_INTEGRATION_SUMMARY.md](FIREBASE_INTEGRATION_SUMMARY.md)
