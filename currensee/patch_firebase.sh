#!/bin/bash

# Create directory for patched files
mkdir -p patched_files

# Create a simplified Firebase.h header
cat > patched_files/Firebase.h << 'EOF'
// Patched Firebase.h for Crashlytics
#ifndef Firebase_h
#define Firebase_h

#if __has_include(<FirebaseCore/FirebaseCore.h>)
  #import <FirebaseCore/FirebaseCore.h>
#else
  #import "FirebaseCore/FirebaseCore.h"
#endif

#if __has_include(<FirebaseCrashlytics/FirebaseCrashlytics.h>)
  #import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#else
  #import "FirebaseCrashlytics/FirebaseCrashlytics.h"
#endif

#endif /* Firebase_h */
EOF

echo "Patched Firebase.h header created"

# Define paths
PLUGIN_DIR="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios/Classes"
PODS_HEADERS_DIR="ios/Pods/Headers/Public"

# Create directories if they don't exist
mkdir -p "$PODS_HEADERS_DIR/firebase_crashlytics"

# Copy the patched Firebase.h to the Pods directory
cp patched_files/Firebase.h "$PODS_HEADERS_DIR/Firebase/Firebase.h"
echo "Copied patched Firebase.h to Pods directory"

# Patch the plugin files
if [ -d "$PLUGIN_DIR" ]; then
  echo "Patching plugin files in: $PLUGIN_DIR"
  
  # Backup the original files
  if [ ! -f "$PLUGIN_DIR/Crashlytics_Platform.h.orig" ]; then
    cp "$PLUGIN_DIR/Crashlytics_Platform.h" "$PLUGIN_DIR/Crashlytics_Platform.h.orig"
    cp "$PLUGIN_DIR/ExceptionModel_Platform.h" "$PLUGIN_DIR/ExceptionModel_Platform.h.orig"
    echo "Created backups of original files"
  fi
  
  # Patch the files to use quotes instead of angle brackets
  sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PLUGIN_DIR/Crashlytics_Platform.h"
  sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PLUGIN_DIR/ExceptionModel_Platform.h"
  echo "Patched plugin files to use quotes for imports"
else
  echo "Warning: Plugin directory not found: $PLUGIN_DIR"
fi

echo "All patching completed. Now run Flutter clean and rebuild." 