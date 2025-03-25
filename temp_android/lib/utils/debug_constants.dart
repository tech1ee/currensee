// Debug constants and logging utilities for development
import 'package:flutter/foundation.dart';

class DebugConstants {
  // Set to false for production releases
  static const bool isDebugMode = false;
}

/// Centralized logging utility class that can be disabled in production
class AppLogger {
  static bool get _shouldLog => DebugConstants.isDebugMode || kDebugMode;
  
  /// Log an info message
  static void info(String message) {
    if (_shouldLog) {
      debugPrint('INFO: $message');
    }
  }
  
  /// Log an error message
  static void error(String message, [dynamic error]) {
    if (_shouldLog) {
      debugPrint('ERROR: $message ${error != null ? '- $error' : ''}');
    }
  }
  
  /// Log a warning message
  static void warning(String message) {
    if (_shouldLog) {
      debugPrint('WARNING: $message');
    }
  }
} 