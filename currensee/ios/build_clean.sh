#!/bin/bash
set -e

echo "🔧 Starting clean iOS build without Crashlytics..."

# Navigate to the project root directory
cd "$(dirname "$0")/.."

# Clean existing build
echo "🧹 Cleaning the project..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Going to iOS directory
cd ios

# Clean existing pods
echo "🧹 Removing Pods directory..."
rm -rf Pods Podfile.lock

# Temporarily rename the Firebase Crashlytics script
SCRIPT_PATH="./Pods/FirebaseCrashlytics/upload-symbols"
if [ -f "$SCRIPT_PATH" ]; then
  echo "📝 Temporarily disabling Crashlytics upload script..."
  mv "$SCRIPT_PATH" "${SCRIPT_PATH}.bak"
fi

# Install pods
echo "📦 Installing pods..."
pod install

# Build the app without codesigning
echo "🏗️ Building the app..."
cd ..
flutter build ios --no-codesign --debug

# Run the app
echo "🚀 Running the app on iPhone 16 Pro..."
flutter run -d "iPhone 16 Pro"

# Restore the script
if [ -f "${SCRIPT_PATH}.bak" ]; then
  echo "🔄 Restoring Crashlytics upload script..."
  mv "${SCRIPT_PATH}.bak" "$SCRIPT_PATH"
fi

echo "✅ Build completed!" 