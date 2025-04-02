#!/bin/bash
set -e

PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios"

echo "🔥 Fixing Firebase Crashlytics Headers..."

# Check if the plugin directory exists
if [ ! -d "$PLUGIN_PATH" ]; then
  echo "❌ Plugin directory not found at: $PLUGIN_PATH"
  exit 1
fi

# Create backups of the original files
echo "📂 Creating backups of original files..."
if [ ! -f "$PLUGIN_PATH/Classes/Crashlytics_Platform.h.orig" ]; then
  cp "$PLUGIN_PATH/Classes/Crashlytics_Platform.h" "$PLUGIN_PATH/Classes/Crashlytics_Platform.h.orig"
fi

if [ ! -f "$PLUGIN_PATH/Classes/ExceptionModel_Platform.h.orig" ]; then
  cp "$PLUGIN_PATH/Classes/ExceptionModel_Platform.h" "$PLUGIN_PATH/Classes/ExceptionModel_Platform.h.orig"
fi

if [ ! -f "$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m.orig" ]; then
  cp "$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m" "$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m.orig"
fi

# Replace the import statements
echo "🔄 Patching import statements..."
sed -i '' 's|#import <Firebase/Firebase.h>|// Fixed import\n#import "Firebase.h"|g' "$PLUGIN_PATH/Classes/Crashlytics_Platform.h"
sed -i '' 's|#import <Firebase/Firebase.h>|// Fixed import\n#import "Firebase.h"|g' "$PLUGIN_PATH/Classes/ExceptionModel_Platform.h"
sed -i '' 's|#import <Firebase/Firebase.h>|// Fixed import\n#import "Firebase.h"|g' "$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m"

echo "✅ Firebase Crashlytics headers fixed successfully!"
echo "Now run: cd ios && pod install && cd .. && flutter run -d \"iPhone 16 Pro\"" 