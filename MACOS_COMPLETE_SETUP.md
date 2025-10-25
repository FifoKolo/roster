# 🍎 Roster App - Complete macOS Setup Guide

## ✅ What's Already Done
- ✅ macOS platform files created
- ✅ Entitlements configured for file access and printing
- ✅ Build script ready (`build_macos.sh`)

## 📋 Prerequisites on Mac
1. **macOS 10.14+** (Mojave or later)
2. **Xcode** (from Mac App Store - required for Flutter desktop)
3. **Flutter SDK** for macOS

## 🚀 Quick Start (On Your Mac)

### Step 1: Install Flutter
```bash
# Option A: Download from official site
# Visit: https://docs.flutter.dev/get-started/install/macos

# Option B: Use Homebrew (easier)
brew install --cask flutter
```

### Step 2: Install Xcode
```bash
# Install Xcode from App Store, then:
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runfirstlaunch
```

### Step 3: Transfer Your Project
```bash
# Copy the entire Roster folder to your Mac, then:
cd /path/to/Roster
flutter pub get
```

### Step 4: Build & Run
```bash
# Make build script executable
chmod +x build_macos.sh

# Run the build script
./build_macos.sh
```

## 🔧 Manual Build Commands
```bash
# Check Flutter setup
flutter doctor

# Enable macOS (already done)
flutter config --enable-macos-desktop

# Install dependencies
flutter pub get

# Run in development
flutter run -d macos

# Build release version
flutter build macos --release
```

## 📱 Your App Features on macOS
- ✅ **Complete roster management**
- ✅ **PDF generation & printing** (uses native macOS print dialog)
- ✅ **Local data storage** (SharedPreferences → macOS User Defaults)
- ✅ **Employee scheduling**
- ✅ **Holiday hours tracking**
- ✅ **Management reports**

## 📁 File Locations
```
build/macos/Build/Products/Release/roster.app  # Your final app
```

## 🎯 Next Steps
1. **Test locally**: `flutter run -d macos`
2. **Build release**: `./build_macos.sh`
3. **Optional**: Sign for distribution (requires Apple Developer account)

## 🆘 Troubleshooting
- **"No devices found"**: Run `flutter doctor` and install missing components
- **Build errors**: Ensure Xcode command line tools: `xcode-select --install`
- **Permission issues**: Entitlements are already configured for your app

The macOS version will have the same functionality as your Windows/Android version!