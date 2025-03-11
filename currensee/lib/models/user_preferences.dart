import 'package:flutter/material.dart';

class UserPreferences {
  final ThemeMode themeMode;
  final bool isPremium;
  final List<String> selectedCurrencyCodes;
  final String baseCurrencyCode;

  UserPreferences({
    this.themeMode = ThemeMode.system,
    this.isPremium = false,
    this.selectedCurrencyCodes = const [],
    this.baseCurrencyCode = 'USD',
  });

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
    return UserPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.toString() == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      isPremium: json['isPremium'] ?? false,
      selectedCurrencyCodes: List<String>.from(json['selectedCurrencyCodes'] ?? []),
      baseCurrencyCode: json['baseCurrencyCode'] ?? 'USD',
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