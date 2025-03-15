import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'constants/theme_constants.dart';
import 'providers/currency_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AdMob
  await AdService().initialize();
  
  print('🚀🚀🚀 STARTING APP 🚀🚀🚀');
  print('Flutter: ${await getFlutterVersion()}');
  print('🚀🚀🚀 APP INITIALIZATION COMPLETE 🚀🚀🚀');
  
  runApp(const MyApp());
}

// Helper function to get Flutter version
Future<String> getFlutterVersion() async {
  try {
    // This just returns a string for logging purposes
    return 'Flutter Debug Mode';
  } catch (e) {
    return 'Unknown version';
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final UserPreferencesProvider _userPrefs = UserPreferencesProvider();
  final CurrencyProvider _currencyProvider = CurrencyProvider();
  final PurchaseService _purchaseService = PurchaseService();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    print('📱 MyApp initState called');
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    print('🔄 Starting provider initialization');
    
    // Wait for user preferences to load
    print('⏳ Waiting for user preferences to load...');
    while (_userPrefs.isLoading) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    print('✅ User preferences loaded:');
    print('   Base currency: ${_userPrefs.baseCurrencyCode}');
    print('   Selected currencies: ${_userPrefs.selectedCurrencyCodes.join(', ')}');
    print('   Theme: ${_userPrefs.themeMode.toString()}');
    
    // Initialize purchase service
    await _purchaseService.initialize();
    
    // Now initialize currency provider with user preferences
    print('⏳ Initializing currency provider...');
    await _currencyProvider.initialize(
      _userPrefs.selectedCurrencyCodes,
      _userPrefs.baseCurrencyCode,
    );
    print('✅ Currency provider initialized');
    
    if (mounted) {
      setState(() {
        _initialized = true;
        print('🚀 App initialization complete, rendering main UI');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _userPrefs),
        ChangeNotifierProvider.value(value: _currencyProvider),
        ChangeNotifierProvider.value(value: _purchaseService),
        Provider<StorageService>(create: (_) => StorageService()),
      ],
      child: Consumer<UserPreferencesProvider>(
        builder: (context, userPrefs, _) {
          return MaterialApp(
            title: 'CurrenSee',
            theme: ThemeConstants.lightTheme,
            darkTheme: ThemeConstants.darkTheme,
            themeMode: userPrefs.themeMode,
            home: _initialized 
                ? (userPrefs.hasCompletedOnboarding 
                    ? const HomeScreen() 
                    : const OnboardingScreen())
                : Scaffold(
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
                  ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
