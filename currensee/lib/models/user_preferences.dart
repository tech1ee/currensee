import 'package:flutter/material.dart';

class UserPreferences {
  final ThemeMode themeMode;
  final bool isPremium;
  final List<String> selectedCurrencyCodes;
  final String baseCurrencyCode;

  UserPreferences({
    this.themeMode = ThemeMode.system,
    this.isPremium = false,
    List<String>? selectedCurrencyCodes,
    this.baseCurrencyCode = 'USD',
  }) : selectedCurrencyCodes = selectedCurrencyCodes ?? ['USD', 'EUR', 'GBP'];

  UserPreferences copyWith({
    ThemeMode? themeMode,
    bool? isPremium,
    List<String>? selectedCurrencyCodes,
    String? baseCurrencyCode,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      isPremium: isPremium ?? this.isPremium,
      selectedCurrencyCodes: selectedCurrencyCodes ?? this.selectedCurrencyCodes,
      baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    // Extract selected currency codes with fallback to default currencies
    List<String> currencies = [];
    if (json['selectedCurrencyCodes'] != null) {
      currencies = List<String>.from(json['selectedCurrencyCodes']);
    }
    
    // Ensure we have at least one currency (the base currency)
    final baseCurrency = json['baseCurrencyCode'] ?? 'USD';
    if (currencies.isEmpty || !currencies.contains(baseCurrency)) {
      currencies = [baseCurrency, 'EUR', 'GBP'];
    }
    
    return UserPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.toString() == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      isPremium: json['isPremium'] ?? false,
      selectedCurrencyCodes: currencies,
      baseCurrencyCode: baseCurrency,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.toString(),
      'isPremium': isPremium,
      'selectedCurrencyCodes': selectedCurrencyCodes,
      'baseCurrencyCode': baseCurrencyCode,
    };
  }
} 