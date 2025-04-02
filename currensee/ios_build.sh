#!/bin/bash
set -e

echo "🔥 Starting comprehensive iOS build with Firebase fixes..."

# Step 1: Clean the Flutter project
echo "📦 Cleaning Flutter project..."
flutter clean
flutter pub get

# Step 2: Navigate to iOS directory
echo "📱 Moving to iOS directory..."
cd ios

# Step 3: Remove pods and lock file
echo "🗑️ Removing existing Pods and Podfile.lock..."
rm -rf Pods Podfile.lock

# Step 4: Make Ruby script executable
echo "🛠️ Making Ruby script executable..."
chmod +x fix_firebase_crashlytics.rb

# Step 5: Install pods
echo "📥 Installing pods..."
pod install

# Step 6: Run the Ruby script to fix headers
echo "🧰 Running header fix script..."
./fix_firebase_crashlytics.rb

# Step 7: Return to project root
echo "🔙 Returning to project root..."
cd ..

# Step 8: Enable Firebase on iOS by updating main.dart
echo "🔄 Updating main.dart to enable Firebase on iOS..."
sed -i '' 's/if (!Platform.isIOS)/if (true)/g' lib/main.dart

# Step 9: Run Flutter on iOS
echo "🚀 Running app on iOS..."
flutter run -d "iPhone 16 Pro"

echo "✅ Build script completed." 