import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'constants/theme_constants.dart';
import 'providers/currency_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'screens/home_screen.dart';
import 'services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AdMob
  await AdService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
        ChangeNotifierProxyProvider<UserPreferencesProvider, CurrencyProvider>(
          create: (_) => CurrencyProvider(),
          update: (_, userPrefs, currencyProvider) {
            if (currencyProvider == null) return CurrencyProvider();
            
            // Initialize the currency provider with user preferences
            if (!userPrefs.isLoading) {
              currencyProvider.initialize(
                userPrefs.selectedCurrencyCodes,
                userPrefs.baseCurrencyCode,
              );
            }
            
            return currencyProvider;
          },
        ),
      ],
      child: Consumer<UserPreferencesProvider>(
        builder: (context, userPrefs, _) {
          return MaterialApp(
            title: 'CurrenSee',
            theme: ThemeConstants.lightTheme,
            darkTheme: ThemeConstants.darkTheme,
            themeMode: userPrefs.themeMode,
            home: const HomeScreen(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
