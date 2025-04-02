#!/bin/bash

# Exit on error
set -e

echo "🔧 Starting Firebase Crashlytics header fix..."

# Path to the Firebase Crashlytics plugin directory
PLUGIN_DIR="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios/Classes"

# Check if plugin directory exists
if [ -d "$PLUGIN_DIR" ]; then
  echo "📂 Found Firebase Crashlytics plugin at: $PLUGIN_DIR"
  
  # Backup and fix Crashlytics_Platform.h
  if [ -f "$PLUGIN_DIR/Crashlytics_Platform.h" ]; then
    echo "📝 Fixing Crashlytics_Platform.h..."
    cp "$PLUGIN_DIR/Crashlytics_Platform.h" "$PLUGIN_DIR/Crashlytics_Platform.h.bak"
    sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PLUGIN_DIR/Crashlytics_Platform.h"
  fi
  
  # Backup and fix ExceptionModel_Platform.h
  if [ -f "$PLUGIN_DIR/ExceptionModel_Platform.h" ]; then
    echo "📝 Fixing ExceptionModel_Platform.h..."
    cp "$PLUGIN_DIR/ExceptionModel_Platform.h" "$PLUGIN_DIR/ExceptionModel_Platform.h.bak"
    sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PLUGIN_DIR/ExceptionModel_Platform.h"
  fi
  
  echo "✅ Firebase Crashlytics plugin headers fixed successfully"
else
  echo "⚠️ Firebase Crashlytics plugin directory not found at: $PLUGIN_DIR"
fi

# Fix headers in Pods directory if it exists
PODS_DIR="./Pods/Headers/Public/firebase_crashlytics"
if [ -d "$PODS_DIR" ]; then
  echo "📂 Found Firebase Crashlytics Pod headers at: $PODS_DIR"
  
  # Fix Crashlytics_Platform.h in Pods
  if [ -f "$PODS_DIR/Crashlytics_Platform.h" ]; then
    echo "📝 Fixing Crashlytics_Platform.h in Pods..."
    cp "$PODS_DIR/Crashlytics_Platform.h" "$PODS_DIR/Crashlytics_Platform.h.bak"
    sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PODS_DIR/Crashlytics_Platform.h"
  fi
  
  # Fix ExceptionModel_Platform.h in Pods
  if [ -f "$PODS_DIR/ExceptionModel_Platform.h" ]; then
    echo "📝 Fixing ExceptionModel_Platform.h in Pods..."
    cp "$PODS_DIR/ExceptionModel_Platform.h" "$PODS_DIR/ExceptionModel_Platform.h.bak"
    sed -i '' 's|#import <Firebase/Firebase.h>|#import "Firebase.h"|g' "$PODS_DIR/ExceptionModel_Platform.h"
  fi
  
  echo "✅ Pods directory headers fixed successfully"
else
  echo "⚠️ Firebase Crashlytics Pod headers directory not found at: $PODS_DIR"
fi

# Fix Firebase.h in Pods/Headers/Public/Firebase
FIREBASE_HEADER="./Pods/Headers/Public/Firebase/Firebase.h"
if [ -f "$FIREBASE_HEADER" ]; then
  echo "📝 Fixing Firebase.h header..."
  cp "$FIREBASE_HEADER" "$FIREBASE_HEADER.bak"
  
  # Remove problematic imports from Firebase.h
  sed -i '' 's|#import <FirebaseStorage/FirebaseStorage.h>|// #import <FirebaseStorage/FirebaseStorage.h>|g' "$FIREBASE_HEADER"
  
  echo "✅ Firebase.h header fixed successfully"
else
  echo "⚠️ Firebase.h header not found at: $FIREBASE_HEADER"
fi

echo "🎉 All Firebase Crashlytics header fixes completed!" 