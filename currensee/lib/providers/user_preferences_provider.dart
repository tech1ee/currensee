import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../services/storage_service.dart';

class UserPreferencesProvider with ChangeNotifier {
  StorageService _storageService = StorageService();
  bool _isLoading = true;
  String? _error;
  UserPreferences? _preferences;

  UserPreferencesProvider() {
    _loadPreferences();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPremium => _preferences?.isPremium ?? false;
  ThemeMode get themeMode => _preferences?.themeMode ?? ThemeMode.system;
  List<String> get selectedCurrencyCodes => _preferences?.selectedCurrencyCodes ?? [];
  String get baseCurrencyCode => _preferences?.baseCurrencyCode ?? '';
  DateTime? get lastRatesRefresh => _preferences?.lastRatesRefresh;
  bool get hasCompletedInitialSetup => _preferences?.hasCompletedInitialSetup ?? false;

  // Load preferences from storage
  Future<void> _loadPreferences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _preferences = await _storageService.loadUserPreferences();
    } catch (e) {
      print('❌ Error loading preferences: $e');
      _error = e.toString();
      // Initialize with default preferences on error
      _preferences = UserPreferences();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save preferences to storage
  Future<void> _savePreferences() async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    try {
      print('📝 Saving preferences to storage: ${_preferences!.toJson()}');
      await _storageService.saveUserPreferences(_preferences!);
      print('📝 Preferences saved successfully');
      notifyListeners();
    } catch (e) {
      print('❌ Error saving preferences: $e');
      throw e;
    }
  }

  // Complete initial setup
  Future<void> completeInitialSetup() async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    _preferences = _preferences!.copyWith(hasCompletedInitialSetup: true);
    await _savePreferences();
  }

  // Set initial currencies
  Future<void> setInitialCurrencies({
    required String baseCurrency,
    required List<String> selectedCurrencies,
  }) async {
    print('📝 Setting initial currencies: Base=$baseCurrency, Selected=${selectedCurrencies.join(", ")}');
    
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    // Ensure the base currency is always included in the selected currencies
    if (!selectedCurrencies.contains(baseCurrency) && baseCurrency.isNotEmpty) {
      selectedCurrencies = [baseCurrency, ...selectedCurrencies];
    }
    
    _preferences = _preferences!.copyWith(
      baseCurrencyCode: baseCurrency,
      selectedCurrencyCodes: selectedCurrencies,
    );
    
    // Save to storage
    await _storageService.saveUserPreferences(_preferences!);
    
    // Verify currencies were saved correctly by loading them back
    final verification = await _storageService.loadUserPreferences();
    print('📝 Verification - Saved currencies: ${verification.selectedCurrencyCodes.join(", ")}');
    print('📝 Verification - Saved base currency: ${verification.baseCurrencyCode}');
    
    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    if (themeMode == _preferences!.themeMode) return;
    
    _preferences = _preferences!.copyWith(themeMode: themeMode);
    await _storageService.saveUserPreferences(_preferences!);
    notifyListeners();
  }

  // Add a currency to selected list
  Future<void> addCurrency(String currencyCode) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    if (_preferences!.selectedCurrencyCodes.contains(currencyCode)) return;
    
    // Check if user is at the free tier limit
    if (!_preferences!.isPremium && 
        _preferences!.selectedCurrencyCodes.length >= 5) {
      throw Exception('Free users can only add up to 5 currencies');
    }
    
    final updatedList = List<String>.from(_preferences!.selectedCurrencyCodes)
      ..add(currencyCode);
    
    _preferences = _preferences!.copyWith(selectedCurrencyCodes: updatedList);
    await _storageService.saveUserPreferences(_preferences!);
    notifyListeners();
  }

  // Remove a currency from selected list
  Future<void> removeCurrency(String currencyCode) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    if (!_preferences!.selectedCurrencyCodes.contains(currencyCode)) return;
    
    // Don't allow removing base currency
    if (currencyCode == _preferences!.baseCurrencyCode) {
      throw Exception('Cannot remove base currency');
    }
    
    final updatedList = List<String>.from(_preferences!.selectedCurrencyCodes)
      ..remove(currencyCode);
    
    _preferences = _preferences!.copyWith(selectedCurrencyCodes: updatedList);
    await _storageService.saveUserPreferences(_preferences!);
    notifyListeners();
  }

  // Set base currency
  Future<void> setBaseCurrency(String currencyCode) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    if (currencyCode == _preferences!.baseCurrencyCode) return;
    
    print('📝 Setting base currency: $currencyCode');
    
    // Make sure the currency is in the selected list
    if (!_preferences!.selectedCurrencyCodes.contains(currencyCode)) {
      final updatedList = List<String>.from(_preferences!.selectedCurrencyCodes)
        ..add(currencyCode);
      
      _preferences = _preferences!.copyWith(
        selectedCurrencyCodes: updatedList,
        baseCurrencyCode: currencyCode,
      );
    } else {
      _preferences = _preferences!.copyWith(baseCurrencyCode: currencyCode);
    }
    
    await _storageService.saveUserPreferences(_preferences!);
    print('📝 Base currency saved: $currencyCode');
    
    // Verify currencies were saved correctly by loading them back
    final verification = await _storageService.loadUserPreferences();
    print('📝 Verification - Selected currencies: ${verification.selectedCurrencyCodes.join(", ")}');
    print('📝 Verification - Base currency: ${verification.baseCurrencyCode}');
    
    notifyListeners();
  }

  // Set the premium status and save
  Future<void> setPremiumStatus(bool isPremium) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    if (_preferences!.isPremium != isPremium) {
      print('💰 Setting premium status to: $isPremium');
      
      // Update preferences with new premium status
      _preferences = _preferences!.copyWith(isPremium: isPremium);
      
      // Save updated preferences
      await _storageService.saveUserPreferences(_preferences!);
      
      // Notify listeners
      notifyListeners();
    }
  }
  
  // Set the last rates refresh timestamp and save
  Future<void> setLastRatesRefresh(DateTime? timestamp) async {
    if (_preferences == null) {
      _preferences = UserPreferences();
    }
    
    print('⏰ Setting lastRatesRefresh to: $timestamp');
    
    // Don't update if timestamps are the same
    if (_preferences!.lastRatesRefresh == timestamp) {
      print('⏰ Timestamps are identical, no update needed');
      return;
    }
    
    // Update preferences with new timestamp
    _preferences = _preferences!.copyWith(lastRatesRefresh: timestamp);
    
    // Save updated preferences
    await _storageService.saveUserPreferences(_preferences!);
    
    print('⏰ Updated lastRatesRefresh: ${_preferences!.lastRatesRefresh}');
    print('⏰ Can refresh today: ${_preferences!.canRefreshRatesToday()}');
    
    // Notify listeners
    notifyListeners();
  }
  
  // Force reload preferences from storage
  Future<void> reloadPreferences() async {
    print('\n🔄 USER PREFS: Force reloading preferences from storage');
    
    try {
      final loadedPrefs = await _storageService.loadUserPreferences();
      
      print('   BEFORE reload: ${_preferences?.toJson() ?? "No preferences set"}');
      _preferences = loadedPrefs;
      print('   AFTER reload: ${_preferences!.toJson()}');
      print('   canRefreshRatesToday: ${_preferences!.canRefreshRatesToday()}');
      print('   Selected currencies after reload: ${_preferences!.selectedCurrencyCodes.join(", ")}');
      
      notifyListeners();
    } catch (e) {
      print('   ⚠️ Error reloading preferences: $e');
    }
  }
} 