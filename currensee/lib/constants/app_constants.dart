class AppConstants {
  // API Constants
  static const String apiBaseUrl = 'https://openexchangerates.org/api/';
  static const String apiKey = 'YOUR_API_KEY'; // Replace with your actual API key
  
  // App Limitations
  static const int maxCurrenciesFreeTier = 5;
  
  // Ad Unit IDs - Replace with actual ad unit IDs for production
  static const String bannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String bannerAdUnitIdiOS = 'ca-app-pub-3940256099942544/2934735716'; // Test ID
  static const String interstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const String interstitialAdUnitIdiOS = 'ca-app-pub-3940256099942544/4411468910'; // Test ID
  
  // App Theme Colors
  static const String lightPrimaryColor = '#FFFFFF';
  static const String lightAccentColor = '#A2D05E';
  static const String lightTextColor = '#000000';
  static const String lightSecondaryTextColor = '#666666';
  static const String lightDividerColor = '#E0E0E0';
  
  static const String darkPrimaryColor = '#121212';
  static const String darkAccentColor = '#A2D05E';
  static const String darkTextColor = '#FFFFFF';
  static const String darkSecondaryTextColor = '#AAAAAA';
  static const String darkDividerColor = '#333333';

  // Storage Keys
  static const String prefsKeyThemeMode = 'theme_mode';
  static const String prefsKeySelectedCurrencies = 'selected_currencies';
  static const String prefsKeyBaseCurrency = 'base_currency';
  static const String prefsKeyExchangeRates = 'exchange_rates';
  static const String prefsKeyIsPremium = 'is_premium';
  static const String prefsKeyLastUpdate = 'last_update';
} 