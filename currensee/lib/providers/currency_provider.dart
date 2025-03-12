import 'dart:async';
import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../models/exchange_rates.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class CurrencyProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  List<Currency> _allCurrencies = [];
  List<Currency> _selectedCurrencies = [];
  ExchangeRates? _exchangeRates;
  String _baseCurrencyCode = 'USD';
  
  // Add tracking for the currently edited currency
  String? _currentlyEditedCurrencyCode;
  
  bool _isLoadingAllCurrencies = false;
  bool _isLoadingRates = false;
  bool _isOffline = false;
  String? _error;
  
  // Getters
  List<Currency> get allCurrencies => _allCurrencies;
  List<Currency> get selectedCurrencies => _selectedCurrencies;
  ExchangeRates? get exchangeRates => _exchangeRates;
  String get baseCurrencyCode => _baseCurrencyCode;
  String? get currentlyEditedCurrencyCode => _currentlyEditedCurrencyCode;
  bool get isLoadingAllCurrencies => _isLoadingAllCurrencies;
  bool get isLoadingRates => _isLoadingRates;
  bool get isOffline => _isOffline;
  String? get error => _error;
  
  // Initialize with selected currency codes
  Future<void> initialize(List<String> selectedCurrencyCodes, String baseCurrencyCode) async {
    _baseCurrencyCode = baseCurrencyCode;
    
    // Try to load cached exchange rates
    final cachedRates = await _storageService.loadExchangeRates();
    if (cachedRates != null) {
      _exchangeRates = cachedRates;
      _isOffline = true; // Assume we're offline if using cached rates
    }
    
    // Make sure we have the base currency in selected currencies
    if (!selectedCurrencyCodes.contains(baseCurrencyCode)) {
      selectedCurrencyCodes = [...selectedCurrencyCodes, baseCurrencyCode];
    }
    
    // Ensure we have at least some currencies selected
    if (selectedCurrencyCodes.isEmpty) {
      selectedCurrencyCodes = [baseCurrencyCode, 'EUR', 'GBP'];
    }
    
    // Load all available currencies
    await loadAllCurrencies();
    
    // Select currencies based on the provided codes
    selectCurrencies(selectedCurrencyCodes);
    
    // Fetch latest exchange rates
    await fetchExchangeRates();
    
    // Make sure to notify listeners after everything is loaded
    notifyListeners();
  }

  // Force a reload of selected currencies from user preferences
  Future<void> reloadSelectedCurrencies(List<String> currencyCodes) async {
    selectCurrencies(currencyCodes);
    await fetchExchangeRates();
  }

  // Load all available currencies
  Future<void> loadAllCurrencies() async {
    _isLoadingAllCurrencies = true;
    _error = null;
    notifyListeners();
    
    try {
      _allCurrencies = await _apiService.fetchAvailableCurrencies();
      _isLoadingAllCurrencies = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load currencies: $e';
      _isLoadingAllCurrencies = false;
      _isOffline = true;
      notifyListeners();
    }
  }

  // Fetch latest exchange rates
  Future<void> fetchExchangeRates() async {
    _isLoadingRates = true;
    _error = null;
    notifyListeners();
    
    try {
      final rates = await _apiService.fetchExchangeRates(_baseCurrencyCode);
      _exchangeRates = rates;
      _isOffline = false;
      
      // Save rates to storage
      await _storageService.saveExchangeRates(rates);
      
      // Update the values of all selected currencies
      _updateCurrencyValues();
      
      _isLoadingRates = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch exchange rates: $e';
      _isLoadingRates = false;
      _isOffline = true;
      notifyListeners();
    }
  }

  // Select currencies based on the provided codes
  void selectCurrencies(List<String> currencyCodes) {
    // Make sure we have at least one currency
    if (currencyCodes.isEmpty) {
      currencyCodes = [_baseCurrencyCode];
    }
    
    // Make sure we have the base currency
    if (!currencyCodes.contains(_baseCurrencyCode)) {
      currencyCodes = [...currencyCodes, _baseCurrencyCode];
    }
    
    // Find currency objects for the provided codes
    _selectedCurrencies = _allCurrencies
        .where((currency) => currencyCodes.contains(currency.code))
        .toList();
    
    // If we couldn't find all currencies, create placeholders
    final foundCodes = _selectedCurrencies.map((c) => c.code).toList();
    for (final code in currencyCodes) {
      if (!foundCodes.contains(code)) {
        _selectedCurrencies.add(Currency(
          code: code,
          name: code,
          symbol: '',
          flagUrl: 'https://flagsapi.com/${code.substring(0, 2)}/flat/64.png',
        ));
      }
    }
    
    // Make sure to update all currency values
    _updateCurrencyValues();
    
    notifyListeners();
  }

  // Methods to track which currency is currently being edited
  void setCurrentlyEditedCurrencyCode(String currencyCode) {
    print('✏️ Setting currently edited currency code to $currencyCode');
    _currentlyEditedCurrencyCode = currencyCode;
    notifyListeners();
  }
  
  void clearCurrentlyEditedCurrencyCode() {
    print('🧹 Clearing currently edited currency code');
    _currentlyEditedCurrencyCode = null;
    notifyListeners();
  }
  
  // Update the value of a specific currency and recalculate other values
  Future<void> updateCurrencyValue(String currencyCode, double newValue) async {
    print('\n💰💰💰 UPDATING CURRENCY VALUE 💰💰💰');
    print('   Currency: $currencyCode');
    print('   New value: $newValue');
    print('   Currently edited: $_currentlyEditedCurrencyCode');
    
    // Critical: Mark this currency as being edited during the update
    _currentlyEditedCurrencyCode = currencyCode;
    
    // Skip if rates are not available
    if (_exchangeRates == null) {
      print('   ❌ Exchange rates not available, cannot update');
      return;
    }
    
    try {
      // Find the currency in our selected list
      int index = _selectedCurrencies.indexWhere((c) => c.code == currencyCode);
      if (index == -1) {
        print('   ⚠️ Currency not found in selected list: $currencyCode');
        return;
      }
      
      // Update the value for the changed currency
      final oldValue = _selectedCurrencies[index].value;
      
      // CRITICAL - Check if update is really needed to prevent unnecessary refreshes
      // Use a small epsilon to avoid floating point comparison issues
      if (oldValue != 0 && (oldValue - newValue).abs() < 0.000001) {
        print('   ⏩ Value unchanged or too small change, skipping update');
        return;
      }
      
      // CRITICAL: Create new list with same order to prevent position changes
      List<Currency> updatedCurrencies = [];
      
      // Process each currency while preserving original order
      for (int i = 0; i < _selectedCurrencies.length; i++) {
        final current = _selectedCurrencies[i];
        
        if (current.code == currencyCode) {
          // Update the edited currency
          updatedCurrencies.add(Currency(
            code: current.code,
            name: current.name,
            symbol: current.symbol,
            flagUrl: current.flagUrl,
            value: newValue
          ));
        } else {
          // For all other currencies, calculate new value
          try {
            double convertedValue = _exchangeRates!.convert(
              newValue, 
              currencyCode, 
              current.code
            );
            
            updatedCurrencies.add(Currency(
              code: current.code,
              name: current.name,
              symbol: current.symbol,
              flagUrl: current.flagUrl,
              value: convertedValue
            ));
            print('   🔄 Recalculated ${current.code}: ${current.value} → $convertedValue');
          } catch (e) {
            // If there's an error, keep the original value
            updatedCurrencies.add(current);
            print('   ⚠️ Error calculating ${current.code}, keeping original value');
          }
        }
      }
      
      // Replace currencies while preserving order
      _selectedCurrencies = updatedCurrencies;
      
      // Critical: Keep this currency marked as being edited
      print('   ✅ Update complete, notifying listeners (keeping $currencyCode as edited)');
      _currentlyEditedCurrencyCode = currencyCode;
      notifyListeners();
      
    } catch (e) {
      print('   ❌ Error updating currency value: $e');
      _error = 'Failed to update currency value: $e';
      notifyListeners();
    }
    
    print('💰💰💰 UPDATE COMPLETE 💰💰💰\n');
  }

  // PRIVATE: Recalculate all currency values when base currency changes
  void _updateCurrencyValues() {
    if (_exchangeRates == null) return;
    
    print('💱 Initializing all currencies with base currency');
    
    // Base currency always has value 1
    final baseCurrency = _selectedCurrencies.firstWhere(
      (c) => c.code == _baseCurrencyCode,
      orElse: () => Currency(
        code: _baseCurrencyCode,
        name: _baseCurrencyCode,
        symbol: '',
        flagUrl: 'https://flagsapi.com/${_baseCurrencyCode.substring(0, 2)}/flat/64.png',
      ),
    );
    
    // Use the comprehensive recalculation method
    _recalculateValuesFromCurrency(baseCurrency.code, 1.0);
  }
  
  // PRIVATE: COMPREHENSIVE recalculation based on a changed currency
  void _recalculateValuesFromCurrency(String sourceCode, double sourceValue) {
    if (_exchangeRates == null) return;
    
    print('\n🧮🧮🧮 RECALCULATING all values from $sourceCode = $sourceValue 🧮🧮🧮');
    
    // Ensure the source value is not zero to avoid division by zero issues
    if (sourceValue == 0) {
      print('   ⚠️ Source value is zero, setting all currencies to zero');
      // If source value is zero, set all other currencies to zero
      for (var i = 0; i < _selectedCurrencies.length; i++) {
        if (_selectedCurrencies[i].code != sourceCode) {
          _selectedCurrencies[i].value = 0;
        }
      }
      return;
    }
    
    // Loop through all currencies and update their values
    for (var i = 0; i < _selectedCurrencies.length; i++) {
      final targetCurrency = _selectedCurrencies[i];
      
      // Skip the source currency - it's already updated
      if (targetCurrency.code == sourceCode) {
        print('   Skipping $sourceCode (source currency)');
        continue;
      }
      
      try {
        final oldValue = targetCurrency.value;
        
        // Calculate the new value based on exchange rates
        final newValue = _exchangeRates!.convert(
          sourceValue,
          sourceCode,
          targetCurrency.code,
        );
        
        print('   ✅ Updated ${targetCurrency.code}: $oldValue → $newValue');
        _selectedCurrencies[i].value = newValue;
      } catch (e) {
        print('   ❌ Error calculating value for ${targetCurrency.code}: $e');
        
        // Use a fallback conversion
        if (targetCurrency.code == _baseCurrencyCode) {
          _selectedCurrencies[i].value = sourceValue; // If base currency, assume 1:1
        } else if (sourceCode == _baseCurrencyCode) {
          _selectedCurrencies[i].value = sourceValue; // If converting from base, assume 1:1
        } else {
          _selectedCurrencies[i].value = sourceValue; // Default fallback
        }
      }
    }
    print('🧮🧮🧮 RECALCULATION COMPLETE 🧮🧮🧮\n');
  }

  // Set base currency
  void setBaseCurrency(String currencyCode) {
    _baseCurrencyCode = currencyCode;
    // We need to fetch new exchange rates for the new base currency
    fetchExchangeRates();
  }
} 