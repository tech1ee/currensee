import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/exchange_rates.dart';
import '../models/user_preferences.dart';

class StorageService {
  // Save user preferences
  Future<void> saveUserPreferences(UserPreferences preferences) async {
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
  }

  // Load user preferences
  Future<UserPreferences> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeString = prefs.getString(AppConstants.prefsKeyThemeMode);
    final selectedCurrencyCodes = prefs.getStringList(AppConstants.prefsKeySelectedCurrencies) ?? [];
    final baseCurrencyCode = prefs.getString(AppConstants.prefsKeyBaseCurrency) ?? 'USD';
    final isPremium = prefs.getBool(AppConstants.prefsKeyIsPremium) ?? false;
    
    return UserPreferences(
      themeMode: _parseThemeMode(themeModeString),
      selectedCurrencyCodes: selectedCurrencyCodes,
      baseCurrencyCode: baseCurrencyCode,
      isPremium: isPremium,
    );
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
} 