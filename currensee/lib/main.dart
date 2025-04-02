import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'constants/theme_constants.dart';
import 'providers/currency_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/home_screen.dart';
import 'screens/currencies_screen.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';
import 'services/env_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  // This captures errors reported by the Flutter framework.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('🔴 Flutter Error: ${details.exception}');
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize environment variables
  await dotenv.load();
  
  // Debug print to verify .env file loading
  final EnvService envService = EnvService();
  debugPrint('🔐 .env file loaded. Checking variables:');
  debugPrint('🔐 AdMob App ID iOS: ${envService.admobAppId.isNotEmpty ? "✅ Found" : "❌ Missing"}');
  debugPrint('🔐 AdMob Banner ID iOS: ${envService.bannerAdUnitId.isNotEmpty ? "✅ Found" : "❌ Missing"}');
  debugPrint('🔐 Firebase API Key iOS: ${envService.firebaseApiKey.isNotEmpty ? "✅ Found" : "❌ Missing"}');
  
  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('🔥 Firebase Core initialized successfully');
    
    // Initialize Analytics
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    print('📊 Firebase Analytics initialized successfully');
    
    // Firebase Crashlytics removed due to iOS build issues
    print('ℹ️ Firebase Crashlytics disabled for compatibility');
    
  } catch (e) {
    print('❌ Error initializing Firebase: $e');
  }
  
  // Initialize AdMob with platform-specific checks
  if (!kIsWeb) {
    if (defaultTargetPlatform == TargetPlatform.android || 
        defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await MobileAds.instance.initialize();
        print('📱 AdMob initialized successfully');
      } catch (e) {
        print('❌ Error initializing AdMob: $e');
      }
    } else {
      print('ℹ️ Skipping AdMob on unsupported platform');
    }
  } else {
    print('ℹ️ Skipping AdMob on web platform');
  }
  
  print('🚀🚀🚀 STARTING APP 🚀🚀🚀');
  print('Flutter: ${await getFlutterVersion()}');
  print('🚀🚀🚀 APP INITIALIZATION COMPLETE 🚀🚀🚀');
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize SharedPreferences
  SharedPreferences prefs = await SharedPreferences.getInstance();
  
  // UserPreferencesProvider is automatically initialized in its constructor
  // No need to explicitly initialize it
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseService()),
        Provider<AdService>(create: (_) => AdService()),
        Provider<FirebaseAnalytics>(
          create: (_) => FirebaseAnalytics.instance,
        ),
        Provider<StorageService>(create: (_) => StorageService()),
      ],
      child: const MyApp(),
    ),
  );
}

// Get Flutter version information
Future<String> getFlutterVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  return '${packageInfo.version}+${packageInfo.buildNumber}';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📱 MyApp initState called');
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    debugPrint('🔄 Starting provider initialization');

    try {
      // Get provider references from context
      final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final purchaseService = Provider.of<PurchaseService>(context, listen: false);
      
      // Temporarily set to free user for testing ads
      debugPrint('🆓 Current premium status: ${userPrefs.isPremium}');
      if (userPrefs.isPremium) {
        await userPrefs.setPremiumStatus(false);  // Force free status for testing ads
        debugPrint('🆓 Set premium status to FREE for testing ads');
      }

      // Wait for everything to initialize
      await Future.wait([
        userPrefs.isLoading ? Future.delayed(Duration(milliseconds: 500)) : Future.value(),
        purchaseService.initialize(),
      ]);

      // Set initialized flag
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      debugPrint('❌ Error initializing providers: $e');
      setState(() {
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get providers directly from the existing context
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    
    return MaterialApp(
      title: 'CurrenSee',
      theme: ThemeConstants.lightTheme,
      darkTheme: ThemeConstants.darkTheme,
      themeMode: userPrefs.themeMode,
      home: _error
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to initialize app',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'An error occurred while initializing the app. Please try again later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = false;
                          _initialized = false;
                        });
                        _initializeProviders();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : !_initialized
              ? Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(
                          'Loading currencies...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : (!userPrefs.hasCompletedInitialSetup
                  ? const CurrenciesScreen(isInitialSetup: true)
                  : const HomeScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}
