import 'package:flutter/material.dart';
import '../models/user_preferences.dart';
import '../services/storage_service.dart';

class UserPreferencesProvider with ChangeNotifier {
  UserPreferences _preferences = UserPreferences();
  final StorageService _storageService = StorageService();
  bool _isLoading = true;

  UserPreferencesProvider() {
    _loadPreferences();
  }

  UserPreferences get preferences => _preferences;
  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _preferences.themeMode;
  bool get isPremium => _preferences.isPremium;
  List<String> get selectedCurrencyCodes => _preferences.selectedCurrencyCodes;
  String get baseCurrencyCode => _preferences.baseCurrencyCode;

  // Load preferences from storage
  Future<void> _loadPreferences() async {
    _isLoading = true;
    notifyListeners();
    
    _preferences = await _storageService.loadUserPreferences();
    
    _isLoading = false;
    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (themeMode == _preferences.themeMode) return;
    
    _preferences = _preferences.copyWith(themeMode: themeMode);
    await _storageService.saveUserPreferences(_preferences);
    notifyListeners();
  }

  // Add a currency to selected list
  Future<void> addCurrency(String currencyCode) async {
    if (_preferences.selectedCurrencyCodes.contains(currencyCode)) return;
    
    // Check if user is at the free tier limit
    if (!_preferences.isPremium && 
        _preferences.selectedCurrencyCodes.length >= 5) {
      throw Exception('Free users can only add up to 5 currencies');
    }
    
    final updatedList = List<String>.from(_preferences.selectedCurrencyCodes)
      ..add(currencyCode);
    
    _preferences = _preferences.copyWith(selectedCurrencyCodes: updatedList);
    await _storageService.saveUserPreferences(_preferences);
    notifyListeners();
  }

  // Remove a currency from selected list
  Future<void> removeCurrency(String currencyCode) async {
    if (!_preferences.selectedCurrencyCodes.contains(currencyCode)) return;
    
    // Don't allow removing base currency
    if (currencyCode == _preferences.baseCurrencyCode) {
      throw Exception('Cannot remove base currency');
    }
    
    final updatedList = List<String>.from(_preferences.selectedCurrencyCodes)
      ..remove(currencyCode);
    
    _preferences = _preferences.copyWith(selectedCurrencyCodes: updatedList);
    await _storageService.saveUserPreferences(_preferences);
    notifyListeners();
  }

  // Set base currency
  Future<void> setBaseCurrency(String currencyCode) async {
    if (currencyCode == _preferences.baseCurrencyCode) return;
    
    // Make sure the currency is in the selected list
    if (!_preferences.selectedCurrencyCodes.contains(currencyCode)) {
      final updatedList = List<String>.from(_preferences.selectedCurrencyCodes)
        ..add(currencyCode);
      
      _preferences = _preferences.copyWith(
        selectedCurrencyCodes: updatedList,
        baseCurrencyCode: currencyCode,
      );
    } else {
      _preferences = _preferences.copyWith(baseCurrencyCode: currencyCode);
    }
    
    await _storageService.saveUserPreferences(_preferences);
    notifyListeners();
  }

  // Set premium status (for future use)
  Future<void> setPremium(bool isPremium) async {
    if (isPremium == _preferences.isPremium) return;
    
    _preferences = _preferences.copyWith(isPremium: isPremium);
    await _storageService.saveUserPreferences(_preferences);
    notifyListeners();
  }
} 