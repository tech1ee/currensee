#!/bin/bash

# Exit on error
set -e

echo "🔧 Starting iOS build script..."

# Clean the project
echo "🧹 Cleaning old build artifacts..."
rm -rf ios/Pods ios/Podfile.lock
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Generate patched headers if needed
if [ -f "ios/fix_firebase_headers.sh" ]; then
  echo "🔧 Making Firebase header fix script executable..."
  chmod +x ios/fix_firebase_headers.sh
  
  echo "🔧 Applying Firebase header fixes..."
  cd ios
  ./fix_firebase_headers.sh
  cd ..
fi

# Clean and reinstall pods
echo "🧹 Cleaning iOS pods..."
cd ios
rm -rf Pods Podfile.lock

# Install pods
echo "📦 Installing CocoaPods dependencies..."
pod install

# Apply post-pod install fixes if needed
if [ -f "fix_after_pod_install.sh" ]; then
  echo "🔧 Applying post-pod install fixes..."
  chmod +x fix_after_pod_install.sh
  ./fix_after_pod_install.sh
fi

# Return to the main project directory
cd ..

# Build for iOS
echo "🏗️ Building for iOS..."
flutter build ios --no-codesign --debug

echo "🔧 Running Google Mobile Ads compatibility fixes..."
./ios/fix_google_mobile_ads.sh

echo "🛠️ Creating mock Crashlytics script if needed..."
mkdir -p ios/Pods/FirebaseCrashlytics
if [ ! -f ios/Pods/FirebaseCrashlytics/upload-symbols ]; then
  echo "#!/bin/bash
  echo \"Crashlytics upload script skipped\"
  exit 0" > ios/Pods/FirebaseCrashlytics/upload-symbols
  chmod +x ios/Pods/FirebaseCrashlytics/upload-symbols
  echo "✅ Created mock Crashlytics upload-symbols script"
fi

echo "📦 Installing CocoaPods dependencies..."
cd ios && pod install && cd ..

echo "🔧 Now running the app..."
flutter run -d "iPhone 16 Pro" "$@"

echo "✅ iOS build script completed successfully!" 