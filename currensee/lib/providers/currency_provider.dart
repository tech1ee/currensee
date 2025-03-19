import 'dart:async';
import 'package:flutter/material.dart';
import '../models/currency.dart';
import '../models/exchange_rates.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../providers/user_preferences_provider.dart';

// Class to hold refresh result
class RefreshResult {
  final bool success;
  final String? errorMessage;
  
  RefreshResult({required this.success, this.errorMessage});
}

class CurrencyProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  List<Currency> _allCurrencies = [];
  List<Currency> _selectedCurrencies = [];
  ExchangeRates? _exchangeRates;
  String _baseCurrencyCode = 'USD';
  UserPreferences? _userPreferences;
  
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
  UserPreferences? get userPreferences => _userPreferences;
  
  // Can the user refresh rates today?
  bool get canRefreshRatesToday => 
    _userPreferences?.canRefreshRatesToday() ?? true;
  
  // Initialize with selected currency codes
  Future<void> initialize(List<String> selectedCurrencyCodes, String baseCurrencyCode) async {
    _baseCurrencyCode = baseCurrencyCode;
    
    // Load user preferences
    _userPreferences = await _storageService.loadUserPreferences();
    
    // Try to load cached exchange rates
    final cachedRates = await _storageService.loadExchangeRates();
    if (cachedRates != null) {
      _exchangeRates = cachedRates;
      _isOffline = true;
    }
    
    // Make sure we have the base currency in selected currencies
    if (!selectedCurrencyCodes.contains(baseCurrencyCode)) {
      selectedCurrencyCodes = [...selectedCurrencyCodes, baseCurrencyCode];
    }
    
    // Ensure we have at least some currencies selected
    if (selectedCurrencyCodes.isEmpty) {
      selectedCurrencyCodes = [baseCurrencyCode];
    }
    
    // Load all available currencies
    await loadAllCurrencies();
    
    // Select currencies based on the provided codes
    await selectCurrencies(selectedCurrencyCodes);
    
    // Always set base currency value to 1.0 and recalculate others
    _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
    
    // Make sure to notify listeners after everything is loaded
    notifyListeners();
  }

  // Force a reload of selected currencies from user preferences
  Future<void> reloadSelectedCurrencies(List<String> currencyCodes) async {
    print('🔄 Reloading selected currencies: ${currencyCodes.join(", ")}');
    
    // Get base currency code
    final baseCurrencyCode = userPreferences?.baseCurrencyCode ?? '';
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    if (baseCurrencyCode.isNotEmpty) {
      sortedCodes.remove(baseCurrencyCode);
      sortedCodes.insert(0, baseCurrencyCode);
    }
    
    // Load currencies in the sorted order
    _selectedCurrencies = sortedCodes
        .map((code) => _allCurrencies.firstWhere((c) => c.code == code))
        .toList();
    
    // Set initial values based on base currency
    _recalculateValuesFromCurrency(baseCurrencyCode, 1.0);
    
    notifyListeners();
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

  // Fetch latest exchange rates - NOTE: This method doesn't check refresh limits
  Future<bool> fetchExchangeRates() async {
    _isLoadingRates = true;
    _error = null;
    notifyListeners();
    
    try {
      print('📊 FETCH EXCHANGE RATES: Requesting latest rates from API');
      final rates = await _apiService.fetchExchangeRates(_baseCurrencyCode);
      _exchangeRates = rates;
      _isOffline = false;
      
      // Save rates to storage
      print('📊 FETCH EXCHANGE RATES: Saving rates to storage');
      await _storageService.saveExchangeRates(rates);
      
      // Update the last refresh time in user preferences - this is crucial for the refresh limit
      if (_userPreferences != null) {
        final dateBeforeUpdate = _userPreferences?.lastRatesRefresh;
        print('📊 FETCH EXCHANGE RATES: Updating last refresh time');
        print('   BEFORE update: lastRatesRefresh = $dateBeforeUpdate');
        
        final updatedPrefs = _userPreferences!.copyWith(
          lastRatesRefresh: DateTime.now(),
        );
        _userPreferences = updatedPrefs;
        await _storageService.saveUserPreferences(updatedPrefs);
        
        print('   AFTER update: lastRatesRefresh = ${_userPreferences?.lastRatesRefresh}');
        print('   VERIFY: canRefreshRatesToday = ${_userPreferences?.canRefreshRatesToday()}');
      } else {
        print('⚠️ Cannot update last refresh time: user preferences is null');
      }
      
      // Update the values of all selected currencies
      _updateCurrencyValues();
      
      _isLoadingRates = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to fetch exchange rates: $e';
      _isLoadingRates = false;
      _isOffline = true;
      notifyListeners();
      return false;
    }
  }
  
  // Try to refresh rates, respecting rate limits for free users
  Future<RefreshResult> tryRefreshRates() async {
    try {
      final isPremium = _userPreferences?.isPremium ?? false;
      
      print('🔄 tryRefreshRates - User is premium: $isPremium');
      print('🔄 tryRefreshRates - Can refresh today: ${canRefreshRatesToday}');
      
      // Premium users can always refresh
      if (isPremium) {
        print('🔄 Premium user - refreshing rates');
        final success = await fetchExchangeRates();
        
        if (!success) {
          return RefreshResult(
            success: false, 
            errorMessage: error ?? 'Failed to fetch exchange rates'
          );
        }
        
        return RefreshResult(success: true);
      }
      
      // Free users can only refresh once per day
      if (canRefreshRatesToday) {
        print('🔄 Free user - has not refreshed today - refreshing rates');
        final success = await fetchExchangeRates();
        
        if (!success) {
          return RefreshResult(
            success: false, 
            errorMessage: error ?? 'Failed to fetch exchange rates'
          );
        }
        
        return RefreshResult(success: true);
      } else {
        print('🔄 Free user - already refreshed today - showing limit message');
        return RefreshResult(
          success: false,
          errorMessage: 'Free users can only refresh rates once per day. Upgrade to premium for unlimited refreshes!'
        );
      }
    } catch (e) {
      print('❌ Error in tryRefreshRates: $e');
      return RefreshResult(
        success: false,
        errorMessage: 'Error refreshing rates: ${e.toString()}'
      );
    }
  }

  // Select currencies based on the provided codes
  Future<void> selectCurrencies(List<String> currencyCodes) async {
    print('🔄 Selecting currencies: ${currencyCodes.join(", ")}');
    
    // Get base currency code
    final baseCurrencyCode = userPreferences?.baseCurrencyCode ?? '';
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    if (baseCurrencyCode.isNotEmpty) {
      sortedCodes.remove(baseCurrencyCode);
      sortedCodes.insert(0, baseCurrencyCode);
    }
    
    // Update selected currencies in the sorted order
    _selectedCurrencies = sortedCodes
        .map((code) => _allCurrencies.firstWhere((c) => c.code == code))
        .toList();
    
    // Set initial values based on base currency
    _recalculateValuesFromCurrency(baseCurrencyCode, 1.0);
    
    notifyListeners();
    
    // Fetch latest rates for selected currencies
    await fetchExchangeRates();
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
      
      // Create a new list to store updated currencies
      List<Currency> updatedCurrencies = List.from(_selectedCurrencies);
      
      // Update the edited currency's value
      updatedCurrencies[index] = Currency(
        code: updatedCurrencies[index].code,
        name: updatedCurrencies[index].name,
        symbol: updatedCurrencies[index].symbol,
        flagUrl: updatedCurrencies[index].flagUrl,
        value: newValue
      );
      
      // Update all other currencies based on the new value
      for (int i = 0; i < updatedCurrencies.length; i++) {
        if (i == index) continue; // Skip the edited currency
        
        final current = updatedCurrencies[i];
        try {
          double convertedValue = _exchangeRates!.convert(
            newValue, 
            currencyCode, 
            current.code
          );
          
          // Round to 2 decimal places to avoid floating point issues
          convertedValue = double.parse(convertedValue.toStringAsFixed(2));
          
          updatedCurrencies[i] = Currency(
            code: current.code,
            name: current.name,
            symbol: current.symbol,
            flagUrl: current.flagUrl,
            value: convertedValue
          );
          print('   🔄 Recalculated ${current.code}: ${current.value} → $convertedValue');
        } catch (e) {
          // If there's an error, keep the original value
          print('   ⚠️ Error calculating ${current.code}, keeping original value');
        }
      }
      
      // Replace currencies while preserving order
      _selectedCurrencies = updatedCurrencies;
      
      // Save the updated currency values
      await _storageService.saveCurrencyValues(_selectedCurrencies);
      
      // Notify listeners of the update
      print('   ✅ Update complete, notifying listeners');
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
    
    // Always set base currency value to 1.0 and recalculate others
    _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
  }
  
  // PRIVATE: COMPREHENSIVE recalculation based on a changed currency
  void _recalculateValuesFromCurrency(String sourceCurrencyCode, double sourceValue) {
    if (_exchangeRates == null) return;
    
    print('\n🧮 Recalculating values from $sourceCurrencyCode = $sourceValue');
    
    // Create a new list to store updated currencies
    final updatedCurrencies = <Currency>[];
    
    // For base currency calculations, we need USD rates since our API returns USD-based rates
    final usdRate = _exchangeRates!.rates[sourceCurrencyCode] ?? 1.0;
    
    for (final currency in _selectedCurrencies) {
      double newValue;
      
      if (currency.code == sourceCurrencyCode) {
        // Source currency gets the input value
        newValue = sourceValue;
      } else {
        // Get the target currency's USD rate
        final targetUsdRate = _exchangeRates!.rates[currency.code] ?? 1.0;
        
        // Calculate: sourceValue * (targetUsdRate / sourceUsdRate)
        // This gives us the correct cross rate from source to target
        newValue = sourceValue * (targetUsdRate / usdRate);
        
        // Round to 2 decimal places
        newValue = double.parse(newValue.toStringAsFixed(2));
      }
      
      print('   ${currency.code}: $newValue');
      
      updatedCurrencies.add(Currency(
        code: currency.code,
        name: currency.name,
        symbol: currency.symbol,
        flagUrl: currency.flagUrl,
        value: newValue
      ));
    }
    
    // Update the list and save
    _selectedCurrencies = updatedCurrencies;
    _storageService.saveCurrencyValues(_selectedCurrencies);
    
    notifyListeners();
    print('🧮 Recalculation complete\n');
  }

  // Set base currency
  void setBaseCurrency(String currencyCode) {
    _baseCurrencyCode = currencyCode;
    // We need to fetch new exchange rates for the new base currency
    fetchExchangeRates();
  }

  // Force reload user preferences to ensure refresh limit is accurate
  Future<void> forceReloadPreferences() async {
    try {
      print('🔄 CurrencyProvider: Forcing reload of user preferences');
      
      // Store the previous values for comparison
      final beforePrefs = _userPreferences;
      final beforeCanRefresh = canRefreshRatesToday;
      
      // Load fresh user preferences from storage
      _userPreferences = await _storageService.loadUserPreferences();
      
      // Log before and after states
      print('🔄 User preferences reload:');
      print('   Before lastRatesRefresh: ${beforePrefs?.lastRatesRefresh}');
      print('   After lastRatesRefresh: ${_userPreferences?.lastRatesRefresh}');
      print('   Before canRefreshToday: $beforeCanRefresh');
      print('   After canRefreshToday: ${canRefreshRatesToday}');
      
      // Let any listeners know the state has been updated
      notifyListeners();
    } catch (e) {
      print('❌ Error reloading user preferences: $e');
    }
    
    return;
  }

  // Update the last refresh timestamp
  Future<void> updateLastRefreshTimestamp(DateTime timestamp) async {
    try {
      print('🔄 CurrencyProvider: Updating lastRatesRefresh to $timestamp');
      
      if (_userPreferences != null) {
        // Create a new preferences object with the updated timestamp
        final updatedPrefs = _userPreferences!.copyWith(
          lastRatesRefresh: timestamp,
        );
        
        // Save to storage
        await _storageService.saveUserPreferences(updatedPrefs);
        
        // Update in memory
        _userPreferences = updatedPrefs;
        
        // Notify listeners
        notifyListeners();
        
        print('🔄 lastRatesRefresh updated successfully');
      } else {
        print('❌ Cannot update lastRatesRefresh: userPreferences is null');
      }
    } catch (e) {
      print('❌ Error updating lastRatesRefresh: $e');
    }
  }
} 