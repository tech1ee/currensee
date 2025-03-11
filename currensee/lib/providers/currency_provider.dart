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
  
  bool _isLoadingAllCurrencies = false;
  bool _isLoadingRates = false;
  bool _isOffline = false;
  String? _error;
  
  // Getters
  List<Currency> get allCurrencies => _allCurrencies;
  List<Currency> get selectedCurrencies => _selectedCurrencies;
  ExchangeRates? get exchangeRates => _exchangeRates;
  String get baseCurrencyCode => _baseCurrencyCode;
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
    
    // Load all available currencies
    await loadAllCurrencies();
    
    // Select currencies based on the provided codes
    selectCurrencies(selectedCurrencyCodes);
    
    // Fetch latest exchange rates
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
    
    _updateCurrencyValues();
    notifyListeners();
  }

  // Update currency object when value changes
  void updateCurrencyValue(String currencyCode, double value) {
    // Find the currency
    final index = _selectedCurrencies.indexWhere((c) => c.code == currencyCode);
    if (index == -1) return;
    
    // Update its value
    _selectedCurrencies[index].value = value;
    
    // Recalculate all other currencies
    _recalculateValues(currencyCode, value);
    
    notifyListeners();
  }

  // Set base currency
  void setBaseCurrency(String currencyCode) {
    _baseCurrencyCode = currencyCode;
    // We need to fetch new exchange rates for the new base currency
    fetchExchangeRates();
  }

  // Update values of all selected currencies
  void _updateCurrencyValues() {
    if (_exchangeRates == null) return;
    
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
    
    _recalculateValues(baseCurrency.code, 1.0);
  }

  // Recalculate all currency values based on a single value change
  void _recalculateValues(String sourceCode, double sourceValue) {
    if (_exchangeRates == null) return;
    
    for (var i = 0; i < _selectedCurrencies.length; i++) {
      if (_selectedCurrencies[i].code != sourceCode) {
        _selectedCurrencies[i].value = _exchangeRates!.convert(
          sourceValue,
          sourceCode,
          _selectedCurrencies[i].code,
        );
      }
    }
  }
} 