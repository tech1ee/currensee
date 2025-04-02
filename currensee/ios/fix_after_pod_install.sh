#!/bin/bash
set -e

echo "🔥 Fixing Firebase headers after pod install..."

# Paths
PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios"
PODS_PATH="$PWD/Pods/Headers/Public"

# 1. Fix the plugin files
if [ -d "$PLUGIN_PATH" ]; then
  echo "📦 Found Crashlytics plugin at: $PLUGIN_PATH"
  
  # Fix Crashlytics_Platform.h
  file="$PLUGIN_PATH/Classes/Crashlytics_Platform.h"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak"
    cat > "$file" << 'EOF'
/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//
//  Crashlytics_Platform.h
//  Crashlytics
//

// Direct imports of required headers to avoid non-modular header issues
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRCrashlytics_Platform : NSObject
+ (FIRCrashlytics *)crashlytics;
@end

NS_ASSUME_NONNULL_END
EOF
    echo "✅ Fixed Crashlytics_Platform.h"
  fi
  
  # Fix ExceptionModel_Platform.h
  file="$PLUGIN_PATH/Classes/ExceptionModel_Platform.h"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak"
    cat > "$file" << 'EOF'
/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
//
//  Crashlytics_ExceptionModel.h
//  Crashlytics
//

// Direct imports of required headers to avoid non-modular header issues
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>

NS_ASSUME_NONNULL_BEGIN

@interface ExceptionModel_Platform : NSObject
+ (NSDictionary<NSString *, id> *)ExceptionModelFromJson:(NSDictionary<NSString *, id> *)json;
@end

NS_ASSUME_NONNULL_END
EOF
    echo "✅ Fixed ExceptionModel_Platform.h"
  fi
  
  # Fix FLTFirebaseCrashlyticsPlugin.m
  file="$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m"
  if [ -f "$file" ]; then
    cp "$file" "${file}.bak"
    sed -i '' 's|#import <Firebase/Firebase.h>|// Direct imports\n#import <FirebaseCore/FirebaseCore.h>\n#import <FirebaseCrashlytics/FirebaseCrashlytics.h>|g' "$file"
    echo "✅ Fixed FLTFirebaseCrashlyticsPlugin.m"
  fi
else
  echo "⚠️ Crashlytics plugin directory not found at: $PLUGIN_PATH"
fi

# 2. Create a custom Firebase.h in the Pods directory
if [ -d "$PODS_PATH" ]; then
  echo "📁 Creating custom Firebase.h in Pods directory..."
  
  mkdir -p "$PODS_PATH/Firebase"
  cat > "$PODS_PATH/Firebase/Firebase.h" << 'EOF'
// Custom Firebase.h header created by fix_after_pod_install.sh
#ifndef Firebase_h
#define Firebase_h

// Core
#if __has_include(<FirebaseCore/FirebaseCore.h>)
  #import <FirebaseCore/FirebaseCore.h>
#endif

// Crashlytics
#if __has_include(<FirebaseCrashlytics/FirebaseCrashlytics.h>)
  #import <FirebaseCrashlytics/FirebaseCrashlytics.h>
#endif

// Analytics
#if __has_include(<FirebaseAnalytics/FirebaseAnalytics.h>)
  #import <FirebaseAnalytics/FirebaseAnalytics.h>
#endif

#endif /* Firebase_h */
EOF
  echo "✅ Created custom Firebase.h"
else
  echo "⚠️ Pods Headers directory not found at: $PODS_PATH"
fi

echo "✅ All Firebase header fixes completed!" 