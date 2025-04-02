import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for handling environment variables
class EnvService {
  // Singleton pattern
  static final EnvService _instance = EnvService._internal();
  factory EnvService() => _instance;
  EnvService._internal();

  /// Initialize the environment service
  static Future<void> initialize() async {
    await dotenv.load();
  }

  /// Get AdMob app ID for the current platform
  String get admobAppId {
    if (isAndroid) {
      return dotenv.env['ADMOB_APP_ID_ANDROID'] ?? '';
    } else if (isIOS) {
      return dotenv.env['ADMOB_APP_ID_IOS'] ?? '';
    }
    return '';
  }

  /// Get AdMob banner ID for the current platform
  String get bannerAdUnitId {
    if (isAndroid) {
      return dotenv.env['ADMOB_BANNER_ID_ANDROID'] ?? '';
    } else if (isIOS) {
      return dotenv.env['ADMOB_BANNER_ID_IOS'] ?? '';
    }
    return '';
  }

  /// Get AdMob interstitial ID for the current platform
  String get interstitialAdUnitId {
    if (isAndroid) {
      return dotenv.env['ADMOB_INTERSTITIAL_ID_ANDROID'] ?? '';
    } else if (isIOS) {
      return dotenv.env['ADMOB_INTERSTITIAL_ID_IOS'] ?? '';
    }
    return '';
  }

  /// Get Firebase API key for the current platform
  String get firebaseApiKey {
    if (isAndroid) {
      return dotenv.env['FIREBASE_API_KEY_ANDROID'] ?? '';
    } else if (isIOS) {
      return dotenv.env['FIREBASE_API_KEY_IOS'] ?? '';
    } else if (isWeb) {
      return dotenv.env['FIREBASE_API_KEY_WEB'] ?? '';
    } else if (isMacOS) {
      return dotenv.env['FIREBASE_API_KEY_MACOS'] ?? '';
    } else if (isWindows) {
      return dotenv.env['FIREBASE_API_KEY_WINDOWS'] ?? '';
    }
    return '';
  }

  /// Check if running on Android
  bool get isAndroid {
    return const bool.fromEnvironment('dart.library.io') &&
        const bool.fromEnvironment('dart.library.jni');
  }

  /// Check if running on iOS
  bool get isIOS {
    return const bool.fromEnvironment('dart.library.io') &&
        const bool.fromEnvironment('dart.library.objc');
  }

  /// Check if running on Web
  bool get isWeb {
    return const bool.fromEnvironment('dart.library.js');
  }

  /// Check if running on macOS
  bool get isMacOS {
    return const bool.fromEnvironment('dart.library.io') &&
        const bool.fromEnvironment('dart.library.macos');
  }

  /// Check if running on Windows
  bool get isWindows {
    return const bool.fromEnvironment('dart.library.io') &&
        const bool.fromEnvironment('dart.library.ffi');
  }
} 