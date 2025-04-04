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
  final UserPreferencesProvider _userPreferencesProvider = UserPreferencesProvider();
  
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
  Future<void> initialize() async {
    print('🔄 Initializing currency provider with: Base=$_baseCurrencyCode, Selected=${_selectedCurrencies.map((c) => c.code).join(", ")}');
    
    try {
      // Load user preferences
      _userPreferences = await _storageService.loadUserPreferences();
      
      // Try to load cached exchange rates first
      final cachedRates = await _storageService.loadExchangeRates();
      if (cachedRates != null) {
        _exchangeRates = cachedRates;
        print('💾 Loaded cached exchange rates from ${_exchangeRates!.timestamp}');
      }
      
      // Always ensure we have the latest preferences
      final latestPreferences = await _storageService.loadUserPreferences();
      if (latestPreferences.selectedCurrencyCodes.isNotEmpty) {
        print('🔄 Updating with latest preferences: Base=${latestPreferences.baseCurrencyCode}, Selected=${latestPreferences.selectedCurrencyCodes.join(", ")}');
        
        // Set base currency without triggering API calls
        _baseCurrencyCode = latestPreferences.baseCurrencyCode;
        
        // Set up selected currencies without triggering API calls
        await _setupSelectedCurrencies(latestPreferences.selectedCurrencyCodes);
      }
      
      // Make sure we have the base currency in selected currencies
      if (!_selectedCurrencies.any((c) => c.code == _baseCurrencyCode)) {
        print('⚠️ Base currency not found in selected, adding $_baseCurrencyCode');
        // Load currencies if needed
        if (_allCurrencies.isEmpty) {
          await loadAllCurrencies();
        }
        
        // Find the currency object for the base currency
        final baseCurrency = _allCurrencies.firstWhere(
          (c) => c.code == _baseCurrencyCode,
          orElse: () => Currency(
            code: _baseCurrencyCode, 
            name: _baseCurrencyCode, 
            symbol: _baseCurrencyCode, 
            value: 1.0,
            flagUrl: ''
          )
        );
        _selectedCurrencies.add(baseCurrency);
      }
      
      // Check if we need to fetch fresh rates
      final isPremium = _userPreferences?.isPremium ?? false;
      final canRefreshToday = _userPreferences?.canRefreshRatesToday() ?? true;
      final hasCachedRates = _exchangeRates != null;
      
      print('🔄 INITIALIZATION CHECK:');
      print('   isPremium: $isPremium');
      print('   canRefreshToday: $canRefreshToday');
      print('   hasCachedRates: $hasCachedRates');
      
      // Recalculate with cached rates first (this ensures the UI has some data to show)
      if (hasCachedRates) {
        _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      }
      
      // Fetch fresh rates only if needed (premium user or can refresh today)
      if (isPremium || (canRefreshToday && !hasCachedRates)) {
        print('🔄 Fetching fresh rates - user is premium or first-time/can refresh today');
        await fetchExchangeRates();
      } else if (hasCachedRates) {
        print('🔄 Using cached rates - free user already refreshed today');
        // For free users who already refreshed today,
        // we just use cached rates with their original timestamp
      } else {
        print('⚠️ No cached rates and cannot refresh today');
        _isOffline = true;
        _error = 'No exchange rate data available. Try again tomorrow.';
      }
      
      notifyListeners();
      print('✅ Currency provider initialized');
    } catch (e) {
      print('❌ Error initializing currency provider: $e');
      _error = 'Failed to initialize: $e';
      notifyListeners();
    }
  }
  
  // Helper method to set up selected currencies without triggering API calls
  Future<void> _setupSelectedCurrencies(List<String> currencyCodes) async {
    print('🔄 Setting up selected currencies: ${currencyCodes.join(", ")}');
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    
    // Always make sure base currency is included and at the top
    if (_baseCurrencyCode.isNotEmpty) {
      // First remove it if it exists elsewhere in the list
      sortedCodes.remove(_baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.insert(0, _baseCurrencyCode);
    }
    
    // Safety check - make sure we have loaded currencies
    if (_allCurrencies.isEmpty) {
      print('⚠️ No currencies loaded yet, loading them first');
      await loadAllCurrencies();
    }
    
    // Update selected currencies in the sorted order with safety check
    try {
      _selectedCurrencies = sortedCodes
          .where((code) => _allCurrencies.any((c) => c.code == code))
          .map((code) => _allCurrencies.firstWhere((c) => c.code == code))
          .toList();
      
      print('✅ Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
    } catch (e) {
      print('❌ Error setting up selected currencies: $e');
      // Fallback to default currency or empty list
      _selectedCurrencies = [];
    }
  }

  // Private method to handle exchange rates initialization logic
  Future<void> _initializeExchangeRates() async {
    // If we already have exchange rates loaded from cache, no need to fetch
    if (_exchangeRates != null) {
      print('💱 Initializing all currencies with base currency');
      _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      return;
    }
    
    // If we don't have rates yet, check if we can fetch them
    final isPremium = _userPreferences?.isPremium ?? false;
    final canRefreshToday = _userPreferences?.canRefreshRatesToday() ?? true;
    
    print('🔄 INITIAL RATES CHECK:');
    print('   isPremium: $isPremium');
    print('   canRefreshToday: $canRefreshToday');
    print('   hasCachedRates: ${_exchangeRates != null}');
    
    // Premium users or users who haven't refreshed today can fetch fresh rates
    if (isPremium || canRefreshToday) {
      print('🔄 Fetching initial rates from API');
      await fetchExchangeRates();
    } else {
      print('🔄 Free user cannot refresh today and no cached rates found');
      // Show offline mode or error state
      _isOffline = true;
    }
  }

  // Force a reload of selected currencies from user preferences
  Future<void> reloadSelectedCurrencies(List<String> currencyCodes) async {
    print('🔄 Reloading selected currencies: ${currencyCodes.join(", ")}');
    
    // Get base currency code
    final baseCurrencyCode = userPreferences?.baseCurrencyCode ?? '';
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    
    // Always make sure base currency is included and at the top
    if (baseCurrencyCode.isNotEmpty) {
      // First remove it if it exists elsewhere in the list
      sortedCodes.remove(baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.insert(0, baseCurrencyCode);
    }
    
    // Safety check - make sure we have loaded currencies
    if (_allCurrencies.isEmpty) {
      print('⚠️ No currencies loaded yet, loading them first');
      await loadAllCurrencies();
    }
    
    // Load currencies in the sorted order with safety check
    try {
      _selectedCurrencies = sortedCodes
          .where((code) => _allCurrencies.any((c) => c.code == code))
          .map((code) => _allCurrencies.firstWhere((c) => c.code == code))
          .toList();
      
      print('✅ Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
    } catch (e) {
      print('❌ Error selecting currencies: $e');
      // Fallback to empty list to prevent crashes
      _selectedCurrencies = [];
    }
    
    // Set initial values based on base currency
    if (baseCurrencyCode.isNotEmpty) {
      _recalculateValuesFromCurrency(baseCurrencyCode, 1.0);
    }
    
    notifyListeners();
  }

  // Load all available currencies
  Future<void> loadAllCurrencies() async {
    _isLoadingAllCurrencies = true;
    _error = null;
    notifyListeners();
    
    try {
      // Check if we have cached rates first - we can extract currencies from there
      final cachedRates = await _storageService.loadExchangeRates();
      
      if (cachedRates != null && cachedRates.rates.isNotEmpty) {
        // Get proper currency metadata first
        print('🔄 Fetching currency metadata for proper display');
        final currencyMetadata = await _apiService.fetchAvailableCurrencies();
        
        // Create a lookup map for quick access to metadata
        final metadataMap = {for (var c in currencyMetadata) c.code: c};
        
        // Extract currencies from cached rates with proper metadata
        print('💾 Using cached rates with proper currency metadata');
        
        // Create currency objects from rates
        _allCurrencies = cachedRates.rates.entries.map((entry) {
          final code = entry.key.toUpperCase();
          // Use metadata if available, otherwise fallback to basic info
          if (metadataMap.containsKey(code)) {
            final metadata = metadataMap[code]!;
            return Currency(
              code: code,
              name: metadata.name,
              symbol: metadata.symbol,
              value: entry.value,
              flagUrl: metadata.flagUrl
            );
          } else {
            // Fallback if no metadata
            return Currency(
              code: code,
              name: code,
              symbol: code,
              value: entry.value,
              flagUrl: ''
            );
          }
        }).toList();
        
        // Sort currencies alphabetically
        _allCurrencies.sort((a, b) => a.code.compareTo(b.code));
        
        print('✅ Loaded ${_allCurrencies.length} currencies from cached rates with proper display data');
      } else {
        // If no cached rates, fetch from API
        print('🌐 No cached rates available, fetching currencies from API');
        _allCurrencies = await _apiService.fetchAvailableCurrencies();
      }
      
      _isLoadingAllCurrencies = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading currencies: $e');
      _error = 'Failed to load currencies: $e';
      _isLoadingAllCurrencies = false;
      _isOffline = true;
      notifyListeners();
    }
  }

  // Fetch latest exchange rates for the base currency
  Future<bool> fetchExchangeRates() async {
    print('\n📊 FETCH EXCHANGE RATES: Requesting latest rates from API for $_baseCurrencyCode');
    _isLoadingRates = true;
    _error = null;
    notifyListeners();
    
    try {
      // Safety check - validate base currency code
      if (_baseCurrencyCode.isEmpty) {
        print('⚠️ Base currency code is empty, using USD as fallback');
        _baseCurrencyCode = 'USD';
      }
      
      // Check if the user is premium or can refresh today before making the API call
      final isPremium = _userPreferences?.isPremium ?? false;
      final canRefreshToday = _userPreferences?.canRefreshRatesToday() ?? true;
      
      // Only make the actual API call if the user is premium or can refresh today
      if (isPremium || canRefreshToday) {
        final rates = await _apiService.fetchExchangeRates(_baseCurrencyCode);
        
        // Validate the returned exchange rates
        if (rates.rates.isEmpty) {
          print('⚠️ API returned empty rates, using cached data as fallback');
          
          // Try to load cached rates
          final cachedRates = await _storageService.loadExchangeRates();
          if (cachedRates != null) {
            print('✅ Using cached exchange rates from: ${cachedRates.timestamp}');
            _exchangeRates = cachedRates;
          } else {
            throw Exception('Failed to fetch exchange rates and no cached data available');
          }
        } else {
          print('✅ Successfully received fresh exchange rates from API');
          _exchangeRates = rates;
          
          _isOffline = false;
          
          // Save rates to storage
          print('📊 FETCH EXCHANGE RATES: Saving fresh rates to storage');
          await _storageService.saveExchangeRates(_exchangeRates!);
          
          // Update the last refresh time in user preferences - only when fresh rates are fetched
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
        }
      } else {
        // Skip the API call for free users who already refreshed today
        print('⏩ Skipping API call - free user already refreshed today');
        
        // Try to load cached rates
        final cachedRates = await _storageService.loadExchangeRates();
        if (cachedRates != null) {
          print('✅ Using cached exchange rates from: ${cachedRates.timestamp}');
          _exchangeRates = cachedRates;
          _isOffline = true;
        } else {
          throw Exception('No cached exchange rates available');
        }
      }
      
      // Update the values of all selected currencies
      _updateCurrencyValues();
      
      _isLoadingRates = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ ERROR in fetchExchangeRates: $e');
      
      // Provide more detailed error information
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        _error = 'Network connection error. Please check your internet connection and try again.';
        _isOffline = true;
      } else if (e.toString().contains('timeout')) {
        _error = 'Request timed out. Server might be slow or unavailable.';
        _isOffline = true;
      } else {
        _error = 'Failed to fetch exchange rates: $e';
      }
      
      print('⚠️ Attempting to use cached rates as fallback');
      final cachedRates = await _storageService.loadExchangeRates();
      if (cachedRates != null) {
        print('✅ Using cached exchange rates from: ${cachedRates.timestamp}');
        _exchangeRates = cachedRates;
        _isOffline = true;
        
        // Even with cached rates, we should update the UI
        _updateCurrencyValues();
      }
      
      _isLoadingRates = false;
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
    
    // Always make sure base currency is included and at the top
    if (baseCurrencyCode.isNotEmpty) {
      // First remove it if it exists elsewhere in the list
      sortedCodes.remove(baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.insert(0, baseCurrencyCode);
    }
    
    // Safety check - make sure we have loaded currencies
    if (_allCurrencies.isEmpty) {
      print('⚠️ No currencies loaded yet, loading them first');
      await loadAllCurrencies();
    }
    
    // Update selected currencies in the sorted order with safety check
    try {
      _selectedCurrencies = sortedCodes
          .where((code) => _allCurrencies.any((c) => c.code == code))
          .map((code) => _allCurrencies.firstWhere((c) => c.code == code))
          .toList();
      
      print('✅ Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
      
      // Make sure the currency selection is saved to user preferences
      if (_userPreferences != null) {
        // Get current list
        final currentList = _userPreferences!.selectedCurrencyCodes;
        
        // Check if list has changed
        final needsUpdate = !_listEquals(currentList, sortedCodes);
        
        if (needsUpdate) {
          print('🔄 Currency selection changed, saving to preferences');
          
          // Create updated user preferences
          final updatedPrefs = _userPreferences!.copyWith(
            selectedCurrencyCodes: sortedCodes,
            baseCurrencyCode: baseCurrencyCode.isNotEmpty ? baseCurrencyCode : 
              (sortedCodes.isNotEmpty ? sortedCodes.first : 'USD')
          );
          
          // Save to storage
          await _storageService.saveUserPreferences(updatedPrefs);
          
          // Update in memory
          _userPreferences = updatedPrefs;
          
          // Verify save was successful
          final verification = await _storageService.loadUserPreferences();
          print('✅ Verification - Selected currencies: ${verification.selectedCurrencyCodes.join(", ")}');
          print('✅ Verification - Base currency: ${verification.baseCurrencyCode}');
        }
      }
    } catch (e) {
      print('❌ Error selecting currencies: $e');
      // Fallback to default currency or empty list
      _selectedCurrencies = [];
    }
    
    // Set initial values based on base currency if we have rates
    if (baseCurrencyCode.isNotEmpty) {
      _recalculateValuesFromCurrency(baseCurrencyCode, 1.0);
    }
    
    notifyListeners();
    
    // Fetch latest rates for selected currencies
    await fetchExchangeRates();
  }
  
  // Helper method to compare lists
  bool _listEquals(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    
    return true;
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
  void setBaseCurrency(String currencyCode) async {
    print('🔄 Setting base currency to: $currencyCode (previous: $_baseCurrencyCode)');
    
    // Only update if actually changed
    if (_baseCurrencyCode == currencyCode) {
      print('⚠️ Base currency is already $currencyCode - no change needed');
      return;
    }
    
    _baseCurrencyCode = currencyCode;
    
    // Check if user is premium or can refresh today before fetching rates
    final isPremium = _userPreferences?.isPremium ?? false;
    final canRefreshToday = this.canRefreshRatesToday;
    
    print('🔄 BASE CURRENCY CHANGED CHECK:');
    print('   isPremium: $isPremium');
    print('   canRefreshToday: $canRefreshToday');
    
    // We need to fetch new exchange rates for the new base currency only if allowed
    if (isPremium || canRefreshToday) {
      print('🔄 User can fetch rates - requesting new rates for base currency $currencyCode');
      await fetchExchangeRates();
    } else {
      print('🔄 Free user already refreshed today - using cached rates with recalculation');
      // If we can't fetch, at least recalculate with existing rates
      _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      notifyListeners();
    }
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