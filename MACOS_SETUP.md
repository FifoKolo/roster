# Roster App - macOS Setup

## Transfer Project to MacBook

### Option 1: Clone from GitHub
```bash
git clone <your-repo-url>
cd roster-app
flutter pub get
flutter create --platforms=macos .
flutter run -d macos
```

### Option 2: Copy Project Files
1. Copy entire project folder to MacBook
2. Open Terminal in project directory
3. Run setup commands:

```bash
# Get dependencies
flutter pub get

# Add macOS platform support
flutter create --platforms=macos .

# Run on macOS
flutter run -d macos
```

## For Web Version (Quick Demo)
```bash
flutter config --enable-web
flutter create --platforms=web .
flutter run -d chrome
```

## Build for Distribution
```bash
# macOS app bundle
flutter build macos

# Web deployment
flutter build web
```

## Troubleshooting
- Run `flutter doctor` to check setup
- Ensure Xcode is installed for iOS tools
- For macOS app signing, you'll need Apple Developer account