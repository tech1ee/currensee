import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:async';

/// Method channel for communicating with native iOS code
const MethodChannel _keyboardChannel = MethodChannel('com.currensee.app/keyboard');

/// Utility class to help with keyboard issues
class KeyboardUtil {
  static bool _isShowingKeyboard = false;
  static Timer? _keyboardCheckTimer;
  
  /// Shows keyboard with platform-specific fixes
  static Future<void> showKeyboard() async {
    _isShowingKeyboard = true;
    
    // Direct command to show keyboard
    await SystemChannels.textInput.invokeMethod('TextInput.show');
    
    // iOS-specific fixes for keyboard issues
    if (Platform.isIOS) {
      // First clear any existing clients
      await SystemChannels.textInput.invokeMethod('TextInput.clearClient');
      
      // Try to use our native method channel if available
      try {
        await _keyboardChannel.invokeMethod('forceKeyboardVisible');
      } catch (e) {
        // Fallback to standard methods if native channel fails
        print('Native keyboard channel failed: $e, using fallback');
        _useIOSFallback();
      }
    }
  }
  
  static void _useIOSFallback() {
    // Then request keyboard with multiple delays to ensure it works
    for (var delay in [50, 300, 600, 1000]) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isShowingKeyboard) {
          SystemChannels.textInput.invokeMethod('TextInput.clearClient');
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    }
    
    // Set up a periodic check to ensure keyboard stays visible
    _keyboardCheckTimer?.cancel();
    _keyboardCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isShowingKeyboard) {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else {
        timer.cancel();
      }
    });
  }
  
  /// Hides keyboard
  static void hideKeyboard() {
    _isShowingKeyboard = false;
    _keyboardCheckTimer?.cancel();
    _keyboardCheckTimer = null;
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
} 