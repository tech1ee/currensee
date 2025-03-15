import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/exchange_rates.dart';
import '../models/user_preferences.dart';
import '../models/currency.dart';

class StorageService {
  // Save user preferences
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    print('\n💾 STORAGE: Saving user preferences');
    print('   isPremium: ${preferences.isPremium}');
    print('   themeMode: ${preferences.themeMode}');
    print('   baseCurrency: ${preferences.baseCurrencyCode}');
    print('   lastRatesRefresh: ${preferences.lastRatesRefresh}');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Save theme mode
    await prefs.setString(
      AppConstants.prefsKeyThemeMode,
      preferences.themeMode.toString(),
    );
    
    // Save selected currencies
    await prefs.setStringList(
      AppConstants.prefsKeySelectedCurrencies,
      preferences.selectedCurrencyCodes,
    );
    
    // Save base currency
    await prefs.setString(
      AppConstants.prefsKeyBaseCurrency,
      preferences.baseCurrencyCode,
    );
    
    // Save premium status
    await prefs.setBool(
      AppConstants.prefsKeyIsPremium,
      preferences.isPremium,
    );
    
    // Save onboarding status
    await prefs.setBool(
      AppConstants.prefsKeyOnboardingCompleted,
      preferences.hasCompletedOnboarding,
    );
    
    // Save last rates refresh date
    if (preferences.lastRatesRefresh != null) {
      final timestamp = preferences.lastRatesRefresh!.millisecondsSinceEpoch;
      print('   Saving lastRatesRefresh timestamp: $timestamp');
      await prefs.setInt(
        AppConstants.prefsKeyLastRatesRefresh,
        timestamp,
      );
    } else {
      print('   Last rates refresh is null, removing from storage if exists');
      await prefs.remove(AppConstants.prefsKeyLastRatesRefresh);
    }
    
    print('💾 STORAGE: User preferences saved successfully');
  }

  // Load user preferences
  Future<UserPreferences> loadUserPreferences() async {
    print('\n💾 STORAGE: Loading user preferences');
    
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeString = prefs.getString(AppConstants.prefsKeyThemeMode);
    final selectedCurrencyCodes = prefs.getStringList(AppConstants.prefsKeySelectedCurrencies) ?? [];
    final baseCurrencyCode = prefs.getString(AppConstants.prefsKeyBaseCurrency) ?? 'USD';
    final isPremium = prefs.getBool(AppConstants.prefsKeyIsPremium) ?? false;
    final hasCompletedOnboarding = prefs.getBool(AppConstants.prefsKeyOnboardingCompleted) ?? false;
    
    print('   isPremium loaded: $isPremium');
    print('   baseCurrency loaded: $baseCurrencyCode');
    print('   themeMode loaded: $themeModeString');
    
    // Load last rates refresh date
    DateTime? lastRatesRefresh;
    final lastRefreshTimestamp = prefs.getInt(AppConstants.prefsKeyLastRatesRefresh);
    print('   lastRatesRefresh timestamp from storage: $lastRefreshTimestamp');
    
    if (lastRefreshTimestamp != null) {
      try {
        lastRatesRefresh = DateTime.fromMillisecondsSinceEpoch(lastRefreshTimestamp);
        print('   Converted to DateTime: $lastRatesRefresh');
      } catch (e) {
        print('Error parsing last refresh date: $e');
      }
    } else {
      print('   No lastRatesRefresh found in storage');
    }
    
    final loadedPrefs = UserPreferences(
      themeMode: _parseThemeMode(themeModeString),
      selectedCurrencyCodes: selectedCurrencyCodes,
      baseCurrencyCode: baseCurrencyCode,
      isPremium: isPremium,
      hasCompletedOnboarding: hasCompletedOnboarding,
      lastRatesRefresh: lastRatesRefresh,
    );
    
    print('💾 STORAGE: User preferences loaded successfully');
    print('   canRefreshRatesToday: ${loadedPrefs.canRefreshRatesToday()}');
    
    return loadedPrefs;
  }
  
  // Helper method to parse theme mode from string
  ThemeMode _parseThemeMode(String? themeModeString) {
    switch (themeModeString) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  // Save exchange rates
  Future<void> saveExchangeRates(ExchangeRates rates) async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = json.encode(rates.toJson());
    await prefs.setString(AppConstants.prefsKeyExchangeRates, ratesJson);
    await prefs.setInt(AppConstants.prefsKeyLastUpdate, DateTime.now().millisecondsSinceEpoch);
  }

  // Load exchange rates
  Future<ExchangeRates?> loadExchangeRates() async {
    final prefs = await SharedPreferences.getInstance();
    final ratesJson = prefs.getString(AppConstants.prefsKeyExchangeRates);
    
    if (ratesJson != null) {
      final ratesMap = json.decode(ratesJson) as Map<String, dynamic>;
      return ExchangeRates.fromJson(ratesMap);
    }
    
    return null;
  }

  // Get the timestamp of the last exchange rates update
  Future<DateTime?> getLastUpdateTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(AppConstants.prefsKeyLastUpdate);
    
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    
    return null;
  }
  
  // Save currency values
  Future<void> saveCurrencyValues(List<Currency> currencies) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert currencies to a simple map of code -> value
    final valuesMap = <String, double>{};
    for (final currency in currencies) {
      valuesMap[currency.code] = currency.value;
    }
    
    final valuesJson = json.encode(valuesMap);
    await prefs.setString(AppConstants.prefsKeyCurrencyValues, valuesJson);
  }
  
  // Load currency values
  Future<Map<String, double>> loadCurrencyValues() async {
    final prefs = await SharedPreferences.getInstance();
    final valuesJson = prefs.getString(AppConstants.prefsKeyCurrencyValues);
    
    if (valuesJson != null) {
      try {
        final Map<String, dynamic> valuesMap = json.decode(valuesJson);
        return valuesMap.map((key, value) => MapEntry(key, value.toDouble()));
      } catch (e) {
        print('Error loading currency values: $e');
      }
    }
    
    // Return empty map if no values are saved
    return {};
  }
} 