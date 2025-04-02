#!/bin/bash
set -e

PLUGIN_PATH="$HOME/.pub-cache/hosted/pub.dev/firebase_crashlytics-3.5.7/ios/Classes/FLTFirebaseCrashlyticsPlugin.m"

if [ ! -f "$PLUGIN_PATH" ]; then
  echo "Crashlytics plugin file not found at $PLUGIN_PATH"
  exit 1
fi

echo "Creating backup of original Crashlytics plugin implementation..."
cp "$PLUGIN_PATH" "${PLUGIN_PATH}.bak"

echo "Patching Crashlytics plugin implementation..."

cat > "$PLUGIN_PATH" << 'EOF'
// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "FLTFirebaseCrashlyticsPlugin.h"

#import <Firebase/Firebase.h>
#import <firebase_core/FLTFirebasePluginRegistry.h>

@interface FLTFirebaseCrashlyticsPlugin ()
@property(nonatomic, retain) FlutterMethodChannel *channel;
@end

@implementation FLTFirebaseCrashlyticsPlugin

#pragma mark - FlutterPlugin

- (instancetype)init:(NSObject<FlutterBinaryMessenger> *)messenger {
  self = [super init];
  if (self) {
    _channel = [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_crashlytics"
                                          binaryMessenger:messenger];
  }
  return self;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"plugins.flutter.io/firebase_crashlytics"
                                  binaryMessenger:[registrar messenger]];
  FLTFirebaseCrashlyticsPlugin *instance =
      [[FLTFirebaseCrashlyticsPlugin alloc] init:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:channel];
  
  [[FLTFirebasePluginRegistry sharedInstance] registerFirebasePlugin:instance];
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([@"Crashlytics#recordError" isEqualToString:call.method]) {
    [self recordError:call result:result];
  } else if ([@"Crashlytics#setCrashlyticsCollectionEnabled" isEqualToString:call.method]) {
    NSNumber *enabled = call.arguments[@"enabled"];
    [[FIRCrashlytics crashlytics] setCrashlyticsCollectionEnabled:[enabled boolValue]];
    result([NSNumber numberWithBool:YES]);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)recordError:(FlutterMethodCall *)call result:(FlutterResult)result {
  NSString *reason = call.arguments[@"reason"];
  NSString *information = call.arguments[@"information"];
  NSString *dartExceptionMessage = call.arguments[@"exception"];
  NSArray *stackTraceElements = call.arguments[@"stackTraceElements"];
  BOOL fatal = [call.arguments[@"fatal"] boolValue];

  NSString *context;
  if (dartExceptionMessage != nil && dartExceptionMessage != (id)[NSNull null]) {
    context = dartExceptionMessage;
  } else if (information != nil && information != (id)[NSNull null]) {
    context = information;
  } else {
    context = @"";
  }

  // Log exception
  NSMutableArray *frames = [NSMutableArray array];
  for (NSDictionary *errorElement in stackTraceElements) {
    FIRStackFrame *frame = [FIRStackFrame frame];
    frame.library = errorElement[@"library"];
    frame.fileName = errorElement[@"file"];
    frame.className = errorElement[@"class"];
    frame.lineNumber = [(NSNumber *)errorElement[@"line"] intValue];
    frame.methodName = errorElement[@"method"];
    
    // Try setting symbol safely
    if ([frame respondsToSelector:@selector(setSymbol:)]) {
      id symbol = [errorElement objectForKey:@"method"];
      if (symbol != nil && [symbol isKindOfClass:[NSString class]]) {
        [frame performSelector:@selector(setSymbol:) withObject:symbol];
      }
    }
    
    [frames addObject:frame];
  }

  // Create custom exception
  FIRExceptionModel *exception = [FIRExceptionModel exceptionModelWithName:@"FlutterError" reason:reason];
  exception.stackTrace = frames;
  [[FIRCrashlytics crashlytics] recordExceptionModel:exception];

  NSNumber *valueToReturn = [NSNumber numberWithBool:YES];
  result(valueToReturn);
}

- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [self.channel setMethodCallHandler:nil];
  self.channel = nil;
  
  // Unregister safely if the method exists
  if ([[FLTFirebasePluginRegistry sharedInstance] respondsToSelector:@selector(deregisterFirebasePlugin:)]) {
    [[FLTFirebasePluginRegistry sharedInstance] performSelector:@selector(deregisterFirebasePlugin:)
                                                     withObject:self];
  }
}

@end
EOF

echo "Patched Crashlytics plugin implementation successfully!"
echo "You may now build your Flutter iOS app." 