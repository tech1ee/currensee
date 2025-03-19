import 'package:flutter/material.dart';

class UserPreferences {
  final ThemeMode themeMode;
  final bool isPremium;
  final List<String> selectedCurrencyCodes;
  final String baseCurrencyCode;
  final DateTime? lastRatesRefresh;
  final bool hasCompletedInitialSetup;

  UserPreferences({
    this.themeMode = ThemeMode.system,
    this.isPremium = false,
    List<String>? selectedCurrencyCodes,
    this.baseCurrencyCode = '',
    this.lastRatesRefresh,
    this.hasCompletedInitialSetup = false,
  }) : selectedCurrencyCodes = selectedCurrencyCodes ?? [];

  UserPreferences copyWith({
    ThemeMode? themeMode,
    bool? isPremium,
    List<String>? selectedCurrencyCodes,
    String? baseCurrencyCode,
    DateTime? lastRatesRefresh,
    bool? hasCompletedInitialSetup,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      isPremium: isPremium ?? this.isPremium,
      selectedCurrencyCodes: selectedCurrencyCodes ?? this.selectedCurrencyCodes,
      baseCurrencyCode: baseCurrencyCode ?? this.baseCurrencyCode,
      lastRatesRefresh: lastRatesRefresh ?? this.lastRatesRefresh,
      hasCompletedInitialSetup: hasCompletedInitialSetup ?? this.hasCompletedInitialSetup,
    );
  }

  bool canRefreshRatesToday() {
    print('\n📅 REFRESH DATE CHECK: Evaluating if user can refresh today');
    
    // Premium users can always refresh
    if (isPremium) {
      print('📅   Result: YES - User is PREMIUM, can always refresh');
      return true;
    }
    
    // If no previous refresh, they can refresh
    if (lastRatesRefresh == null) {
      print('📅   Result: YES - No previous refresh recorded');
      return true;
    }
    
    final now = DateTime.now();
    final lastRefresh = lastRatesRefresh!;
    
    // Output raw timestamps for debugging
    print('📅   Raw lastRefresh timestamp: $lastRefresh');
    print('📅   Raw current timestamp: $now');
    
    // Get date-only components for comparison (ignore time)
    final todayDate = DateTime(now.year, now.month, now.day);
    final lastRefreshDate = DateTime(lastRefresh.year, lastRefresh.month, lastRefresh.day);
    
    // Calculate difference in days
    final difference = todayDate.difference(lastRefreshDate).inDays;
    
    print('📅   Today date: ${todayDate.toIso8601String().split('T')[0]}');
    print('📅   Last refresh date: ${lastRefreshDate.toIso8601String().split('T')[0]}');
    print('📅   Difference in days: $difference');
    
    // Can refresh if the last refresh was at least 1 day ago
    final canRefresh = difference >= 1;
    
    print('📅   Result: ${canRefresh ? "YES - Last refresh was on a different day" : "NO - Already refreshed today"}');
    
    return canRefresh;
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    List<String> currencies = [];
    if (json['selectedCurrencyCodes'] != null) {
      currencies = List<String>.from(json['selectedCurrencyCodes']);
    }
    
    final baseCurrency = json['baseCurrencyCode'] ?? 'USD';
    
    DateTime? lastRefresh;
    if (json['lastRatesRefresh'] != null) {
      try {
        lastRefresh = DateTime.fromMillisecondsSinceEpoch(json['lastRatesRefresh']);
      } catch (e) {
        print('Error parsing last refresh date: $e');
      }
    }
    
    return UserPreferences(
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.toString() == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      isPremium: json['isPremium'] ?? false,
      selectedCurrencyCodes: currencies,
      baseCurrencyCode: baseCurrency,
      lastRatesRefresh: lastRefresh,
      hasCompletedInitialSetup: json['hasCompletedInitialSetup'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.toString(),
      'isPremium': isPremium,
      'selectedCurrencyCodes': selectedCurrencyCodes,
      'baseCurrencyCode': baseCurrencyCode,
      'lastRatesRefresh': lastRatesRefresh?.millisecondsSinceEpoch,
      'hasCompletedInitialSetup': hasCompletedInitialSetup,
    };
  }
} 