#!/bin/bash
set -e

echo "🔧 Fixing Firebase Crashlytics implementation issues..."

PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios"
PLUGIN_IMPL="$PLUGIN_PATH/Classes/FLTFirebaseCrashlyticsPlugin.m"

if [ ! -d "$PLUGIN_PATH" ]; then
  echo "⚠️ Plugin directory not found at: $PLUGIN_PATH"
  exit 1
fi

if [ ! -f "$PLUGIN_IMPL" ]; then
  echo "⚠️ Plugin implementation file not found at: $PLUGIN_IMPL"
  exit 1
fi

# Create backup
if [ ! -f "${PLUGIN_IMPL}.orig2" ]; then
  cp "$PLUGIN_IMPL" "${PLUGIN_IMPL}.orig2"
  echo "📂 Created backup of implementation file"
fi

echo "🔄 Patching implementation file..."

# Replace the problematic implementation with a compatible version
cat > "$PLUGIN_IMPL" << 'EOF'
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTFirebaseCrashlyticsPlugin.h"

// Direct imports
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCrashlytics/FirebaseCrashlytics.h>

#import <firebase_core/FLTFirebasePluginRegistry.h>

@implementation FLTFirebaseCrashlyticsPlugin

NSString *const kFLTFirebaseCrashlyticsChannelName = @"plugins.flutter.io/firebase_crashlytics";

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:kFLTFirebaseCrashlyticsChannelName
                                  binaryMessenger:[registrar messenger]];

  FLTFirebaseCrashlyticsPlugin *instance =
      [[FLTFirebaseCrashlyticsPlugin alloc] initWithBinaryMessenger:[registrar messenger]];

  [[FLTFirebasePluginRegistry sharedInstance] registerFirebasePlugin:instance];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [[FLTFirebasePluginRegistry sharedInstance] deregisterFirebasePlugin:self];
}

- (instancetype)initWithBinaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _binaryMessenger = messenger;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)flutterResult {
  FLTFirebaseMethodCallErrorBlock errorBlock =
      ^(NSString *_Nullable code, NSString *_Nullable message, NSDictionary *_Nullable details,
        NSError *_Nullable error) {
        flutterResult([FLTFirebasePlugin createFlutterErrorFromCode:code
                                                            message:message
                                                    optionalDetails:details
                                                 andOptionalNSError:error]);
      };

  FLTFirebaseMethodCallResult *methodCallResult =
      [FLTFirebaseMethodCallResult createWithSuccess:flutterResult andErrorBlock:errorBlock];

  if ([@"Crashlytics#recordError" isEqualToString:call.method]) {
    [self recordError:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#setCrashlyticsCollectionEnabled" isEqualToString:call.method]) {
    [self setCrashlyticsCollectionEnabled:call.arguments
                    withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#setUserIdentifier" isEqualToString:call.method]) {
    [self setUserIdentifier:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#setCustomKey" isEqualToString:call.method]) {
    [self setCustomKey:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#log" isEqualToString:call.method]) {
    [self log:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#checkForUnsentReports" isEqualToString:call.method]) {
    [self checkForUnsentReports:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#deleteUnsentReports" isEqualToString:call.method]) {
    [self deleteUnsentReports:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#didCrashOnPreviousExecution" isEqualToString:call.method]) {
    [self didCrashOnPreviousExecution:call.arguments withMethodCallResult:methodCallResult];
  } else if ([@"Crashlytics#sendUnsentReports" isEqualToString:call.method]) {
    [self sendUnsentReports:call.arguments withMethodCallResult:methodCallResult];
  } else {
    methodCallResult.success(FlutterMethodNotImplemented);
  }
}

#pragma mark - Firebase Crashlytics API

- (void)recordError:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *reason = arguments[@"reason"];
  NSDictionary *information = arguments[@"information"];
  NSString *dartExceptionMessage = arguments[@"exception"];
  NSArray *stackTraceElements = arguments[@"stackTraceElements"];
  BOOL fatal = [arguments[@"fatal"] boolValue];

  NSMutableArray *frames = [NSMutableArray array];
  for (NSDictionary *errorElement in stackTraceElements) {
    [frames addObject:[self generateFrame:errorElement]];
  }

  // Report a custom exception to Crashlytics
  [[FIRCrashlytics crashlytics] recordExceptionModel:[self createException:dartExceptionMessage
                                                                      reason:reason
                                                                       fatal:fatal
                                                                     frames:frames
                                                                information:information]];

  result.success(@{});
}

- (FIRExceptionModel *)createException:(NSString *)name
                                reason:(NSString *)reason
                                 fatal:(BOOL)fatal
                                frames:(NSArray<FIRStackFrame *> *)frames
                          information:(NSDictionary *)information {
  FIRExceptionModel *exception = [[FIRExceptionModel alloc] initWithName:name reason:reason];
  [exception setStackTrace:frames];
  // Note: these two properties don't exist in newer versions, but we don't need them
  // [exception setValue:@(fatal) forKey:@"isFatal"];
  // [exception setValue:@(YES) forKey:@"onDemand"];

  return exception;
}

- (FIRStackFrame *)generateFrame:(NSDictionary *)errorElement {
  NSString *methodName = [errorElement valueForKey:@"method"];
  NSString *className = [errorElement valueForKey:@"class"];
  NSString *fileName = [errorElement valueForKey:@"file"];
  NSNumber *lineNumber = [errorElement valueForKey:@"line"];

  FIRStackFrame *frame = [FIRStackFrame stackFrameWithSymbol:@"Flutter"
                                                   file:fileName
                                                   line:[lineNumber intValue]];
  [frame setSymbol:[NSString stringWithFormat:@"%@.%@", className, methodName]];
  return frame;
}

- (void)setCrashlyticsCollectionEnabled:(id)arguments
                  withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  BOOL enabled = [arguments[@"enabled"] boolValue];
  [[FIRCrashlytics crashlytics] setCrashlyticsCollectionEnabled:enabled];
  result.success(@{});
}

- (void)setUserIdentifier:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [[FIRCrashlytics crashlytics] setUserID:arguments[@"identifier"]];
  result.success(@{});
}

- (void)setCustomKey:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *key = arguments[@"key"];
  NSString *value = arguments[@"value"];
  [[FIRCrashlytics crashlytics] setCustomValue:value forKey:key];
  result.success(@{});
}

- (void)log:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  NSString *message = arguments[@"message"];
  [[FIRCrashlytics crashlytics] log:message];
  result.success(@{});
}

- (void)checkForUnsentReports:(id)arguments
         withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [[FIRCrashlytics crashlytics] checkForUnsentReportsWithCompletion:^(BOOL hasUnsentReports) {
    result.success(@{@"unsentReports" : @(hasUnsentReports)});
  }];
}

- (void)deleteUnsentReports:(id)arguments
       withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [[FIRCrashlytics crashlytics] deleteUnsentReports];
  result.success(@{});
}

- (void)didCrashOnPreviousExecution:(id)arguments
               withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  BOOL didCrash = [[FIRCrashlytics crashlytics] didCrashDuringPreviousExecution];
  result.success(@{@"didCrashOnPreviousExecution" : @(didCrash)});
}

- (void)sendUnsentReports:(id)arguments withMethodCallResult:(FLTFirebaseMethodCallResult *)result {
  [[FIRCrashlytics crashlytics] sendUnsentReports];
  result.success(@{});
}

@end
EOF

echo "✅ Fixed implementation file!"
echo "Now run: cd .. && flutter run -d \"iPhone 16 Pro\"" 