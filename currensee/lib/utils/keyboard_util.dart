import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// Utility class to help with keyboard issues
class KeyboardUtil {
  /// Shows keyboard with platform-specific fixes
  static void showKeyboard() {
    // Direct command to show keyboard
    SystemChannels.textInput.invokeMethod('TextInput.show');
    
    // iOS-specific fixes for keyboard issues
    if (Platform.isIOS) {
      // First clear any existing clients
      SystemChannels.textInput.invokeMethod('TextInput.clearClient');
      
      // Then request keyboard with delays to ensure it works
      Future.delayed(const Duration(milliseconds: 50), () {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
      
      Future.delayed(const Duration(milliseconds: 300), () {
        SystemChannels.textInput.invokeMethod('TextInput.show');
      });
    }
  }
} 