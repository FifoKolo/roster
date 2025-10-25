#!/bin/bash

# macOS Build Script for Roster App
# Run this script on a Mac to build the macOS version

echo "🍎 Building Roster App for macOS..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    echo "Visit: https://docs.flutter.dev/get-started/install/macos"
    exit 1
fi

# Enable macOS desktop support
echo "📱 Enabling macOS desktop support..."
flutter config --enable-macos-desktop

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Build for macOS
echo "🔨 Building for macOS..."
flutter build macos --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📱 Your app is located at: build/macos/Build/Products/Release/roster.app"
    echo "🚀 You can run it with: open build/macos/Build/Products/Release/roster.app"
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi