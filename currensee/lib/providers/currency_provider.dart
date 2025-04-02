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
  final bool limitReached;
  final String? errorMessage;
  
  RefreshResult({required this.success, this.limitReached = false, this.errorMessage});
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
    print('🔄 Currency provider initializing');
    
    // Reset state
    _isLoadingAllCurrencies = true;
    _isOffline = false;
    _error = null;
    
    try {
      // CRITICAL FIX: Load preferences only once
      print('💾 Loading user preferences');
      _userPreferences = await _storageService.loadUserPreferences();
      
      if (_userPreferences == null) {
        print('⚠️ No user preferences found, using defaults');
        // Use default base currency (USD)
      } else {
        // CRITICAL FIX: Always respect the saved base currency
        if (_userPreferences!.baseCurrencyCode.isNotEmpty) {
          _baseCurrencyCode = _userPreferences!.baseCurrencyCode;
          print('📌 Base currency set from preferences: $_baseCurrencyCode');
        } else {
          print('⚠️ No base currency in preferences, using default: $_baseCurrencyCode');
        }
      }
      
      // Load currencies
      if (_allCurrencies.isEmpty) {
        print('🔄 Loading available currencies');
        await loadAllCurrencies();
      }
      
      // Try to load cached exchange rates
      bool hasCachedRates = false;
      final cachedRates = await _storageService.loadExchangeRates();
      if (cachedRates != null) {
        print('💾 Found cached exchange rates from: ${cachedRates.timestamp}');
        _exchangeRates = cachedRates;
        hasCachedRates = true;
      }
      
      // Set up selected currencies from preferences
      if (_userPreferences != null && _userPreferences!.selectedCurrencyCodes.isNotEmpty) {
        print('🔄 Loading selected currencies from preferences');
        await _setupSelectedCurrencies(_userPreferences!.selectedCurrencyCodes);
      } else {
        print('⚠️ No selected currencies in preferences, using base currency only');
        await _setupSelectedCurrencies([_baseCurrencyCode]);
      }
      
      // FINAL VALIDATION: Ensure base currency is correctly set in user preferences
      if (_userPreferences != null && _userPreferences!.baseCurrencyCode != _baseCurrencyCode) {
        print('⚠️ Base currency mismatch in preferences! Fixing...');
        print('   Current base: $_baseCurrencyCode, Stored base: ${_userPreferences!.baseCurrencyCode}');
        
        final updatedPrefs = _userPreferences!.copyWith(
          baseCurrencyCode: _baseCurrencyCode
        );
        await _storageService.saveUserPreferences(updatedPrefs);
        _userPreferences = updatedPrefs;
        print('✅ Fixed base currency in preferences');
      }
      
      // Do calculation with cached rates first
      if (hasCachedRates) {
        _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      }
      
      // Fetch fresh rates if needed
      final isPremium = _userPreferences?.isPremium ?? false;
      
      // FIXED: Use the canRefreshRatesToday method from UserPreferences
      final canRefreshToday = _userPreferences != null ? _userPreferences!.canRefreshRatesToday() : true;
      
      if (isPremium || (canRefreshToday && !hasCachedRates)) {
        print('🔄 Fetching fresh rates - user is premium or can refresh today');
        await fetchExchangeRates();
      } else if (hasCachedRates) {
        print('🔄 Using cached rates - free user already refreshed today');
      } else {
        print('⚠️ No cached rates and cannot refresh today');
        _isOffline = true;
        _error = 'Cannot refresh rates. Free users can refresh once per day.';
      }
      
      // CRITICAL FIX: Call update method to ensure base currency is included
      _updateSelectedCurrencies();
      
      _isLoadingAllCurrencies = false;
      notifyListeners();
      print('✅ Currency provider initialized with base currency: $_baseCurrencyCode');
      
      // Final verification
      print('✅ Verification - Base currency: $_baseCurrencyCode');
      print('✅ Verification - Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
    } catch (e) {
      print('❌ Error initializing currency provider: $e');
      _isLoadingAllCurrencies = false;
      _isOffline = true;
      _error = 'Failed to initialize currency provider: $e';
      notifyListeners();
    }
  }
  
  // Helper method to set up selected currencies without triggering API calls
  Future<void> _setupSelectedCurrencies(List<String> currencyCodes) async {
    print('🔄 Setting up selected currencies: ${currencyCodes.join(", ")}');
    
    // CRITICAL FIX: Always use the current base currency code
    // Instead of potentially overriding it from preferences
    final baseCurrencyCode = _baseCurrencyCode;
    print('📌 Using base currency from class: $baseCurrencyCode');
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    
    // Always make sure base currency is included and at the top
    if (baseCurrencyCode.isNotEmpty) {
      // First remove it if it exists elsewhere in the list
      sortedCodes.remove(baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.insert(0, baseCurrencyCode);
      print('📌 Ensuring base currency $baseCurrencyCode is pinned at the top');
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
            // CRITICAL: Ensure we use the current base currency, not override it
            baseCurrencyCode: baseCurrencyCode
          );
          
          // Save to storage
          await _storageService.saveUserPreferences(updatedPrefs);
          
          // Update in memory
          _userPreferences = updatedPrefs;
          
          // Verify save was successful
          final verification = await _storageService.loadUserPreferences();
          print('✅ Verification - Saved currencies: ${verification.selectedCurrencyCodes.join(", ")}');
          print('✅ Verification - Saved base currency: ${verification.baseCurrencyCode}');
        }
      }
      
      print('✅ Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
    } catch (e) {
      print('❌ Error setting up selected currencies: $e');
      // Fallback to empty list
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
    
    // Before making any changes, ensure we have the latest user preferences
    try {
      _userPreferences = await _storageService.loadUserPreferences();
    } catch (e) {
      print('❌ Error loading user preferences: $e');
    }
    
    // Get base currency code from preferences
    final baseCurrencyCode = _userPreferences?.baseCurrencyCode ?? '';
    print('🔄 Base currency from preferences: $baseCurrencyCode');
    
    // Sort currency codes to ensure base currency is first
    final sortedCodes = List<String>.from(currencyCodes);
    
    // Always make sure base currency is included and at the top
    if (baseCurrencyCode.isNotEmpty) {
      // First remove it if it exists elsewhere in the list
      sortedCodes.remove(baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.insert(0, baseCurrencyCode);
      print('📌 Ensuring base currency $baseCurrencyCode is pinned at the top');
      print('📌 Sorted currency order: ${sortedCodes.join(", ")}');
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
      
      // Extra check to ensure base currency is first
      if (_selectedCurrencies.isNotEmpty && 
          baseCurrencyCode.isNotEmpty &&
          _selectedCurrencies[0].code != baseCurrencyCode) {
        
        print('⚠️ Base currency not at top after sorting! Re-sorting...');
        
        // Find the base currency
        final baseIndex = _selectedCurrencies.indexWhere((c) => c.code == baseCurrencyCode);
        if (baseIndex > 0) {
          // Move it to the top
          final baseCurrency = _selectedCurrencies.removeAt(baseIndex);
          _selectedCurrencies.insert(0, baseCurrency);
          print('📌 Manually moved $baseCurrencyCode to the top position');
        }
      }
      
      print('✅ Final selected currencies order: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
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
      
      // Always try cached rates first
      final cachedRates = await _storageService.loadExchangeRates();
      if (cachedRates != null) {
        print('💾 Found cached exchange rates from: ${cachedRates.timestamp}');
        // Load cached rates first to ensure we have something to display
        _exchangeRates = cachedRates;
        _updateCurrencyValues();
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
          
          // Try to load cached rates (again as a double-check)
          if (cachedRates != null && _exchangeRates == null) {
            print('✅ Using cached exchange rates from: ${cachedRates.timestamp}');
            _exchangeRates = cachedRates;
          } else if (_exchangeRates == null) {
            // If no cached rates, use mock data as last resort
            print('⚠️ No cached rates available, using mock data');
            _exchangeRates = _getMockExchangeRates();
          }
        } else {
          print('✅ Successfully received fresh exchange rates from API');
          
          // Ensure we have rates for all selected currencies
          final missingCurrencies = _selectedCurrencies
              .where((c) => !rates.rates.containsKey(c.code.toUpperCase()))
              .map((c) => c.code)
              .toList();
          
          if (missingCurrencies.isNotEmpty) {
            print('⚠️ Missing rates for: ${missingCurrencies.join(", ")}');
            print('⚠️ Adding mock rates for missing currencies');
            
            // Get mock rates for these currencies
            final mockRates = _getMockExchangeRates();
            
            // Add missing rates from mock data
            final updatedRates = Map<String, double>.from(rates.rates);
            for (final code in missingCurrencies) {
              final mockRate = mockRates.rates[code.toUpperCase()];
              if (mockRate != null) {
                updatedRates[code.toUpperCase()] = mockRate;
                print('   Added mock rate for $code: $mockRate');
              }
            }
            
            // Create updated exchange rates object
            _exchangeRates = ExchangeRates(
              base: rates.base,
              timestamp: rates.timestamp,
              rates: updatedRates,
            );
          } else {
            _exchangeRates = rates;
          }
          
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
            
            // Clear debug message that timestamp was updated
            print('📅📅📅 TIMESTAMP UPDATED: Last refresh time set to ${_userPreferences?.lastRatesRefresh}');
          } else {
            print('⚠️ Cannot update last refresh time: user preferences is null');
          }
        }
      } else {
        // Skip the API call for free users who already refreshed today
        print('⏩ Skipping API call - free user already refreshed today');
        
        // Ensure we have cached rates
        if (_exchangeRates == null && cachedRates != null) {
          print('✅ Using cached exchange rates from: ${cachedRates.timestamp}');
          
          // Ensure rates include all selected currencies
          final missingCurrencies = _selectedCurrencies
              .where((c) => !cachedRates.rates.containsKey(c.code.toUpperCase()))
              .map((c) => c.code)
              .toList();
          
          if (missingCurrencies.isNotEmpty) {
            print('⚠️ Cached rates missing data for: ${missingCurrencies.join(", ")}');
            print('⚠️ Adding mock rates for missing currencies');
            
            // Get mock rates for these currencies
            final mockRates = _getMockExchangeRates();
            
            // Add missing rates from mock data
            final updatedRates = Map<String, double>.from(cachedRates.rates);
            for (final code in missingCurrencies) {
              final mockRate = mockRates.rates[code.toUpperCase()];
              if (mockRate != null) {
                updatedRates[code.toUpperCase()] = mockRate;
                print('   Added mock rate for $code: $mockRate');
              }
            }
            
            // Create updated exchange rates object
            _exchangeRates = ExchangeRates(
              base: cachedRates.base,
              timestamp: cachedRates.timestamp,
              rates: updatedRates,
            );
          } else {
            _exchangeRates = cachedRates;
          }
          
          _isOffline = true;
        } else if (_exchangeRates == null) {
          // If no cached rates are available, use mock data
          print('⚠️ No cached rates available, using mock data');
          _exchangeRates = _getMockExchangeRates();
          _isOffline = true;
        }
      }
      
      // FINAL CHECK: Always ensure we have rates, even if it's mock data
      if (_exchangeRates == null) {
        print('⚠️ FINAL CHECK: No exchange rates available after all attempts, using mock data');
        _exchangeRates = _getMockExchangeRates();
        _isOffline = true;
      }
      
      // Do a final check to ensure all selected currencies have rates
      final missingCurrencies = _selectedCurrencies
          .where((c) => !_exchangeRates!.rates.containsKey(c.code.toUpperCase()))
          .map((c) => c.code)
          .toList();
      
      if (missingCurrencies.isNotEmpty) {
        print('⚠️ FINAL CHECK: Still missing rates for: ${missingCurrencies.join(", ")}');
        print('⚠️ Adding mock rates one last time');
        
        // Get mock rates as a last resort
        final mockRates = _getMockExchangeRates();
        
        // Add missing rates from mock data
        final updatedRates = Map<String, double>.from(_exchangeRates!.rates);
        for (final code in missingCurrencies) {
          // Use a default rate if nothing else is available
          updatedRates[code.toUpperCase()] = mockRates.rates[code.toUpperCase()] ?? 1.0;
          print('   Added last-resort rate for $code: ${updatedRates[code.toUpperCase()]}');
        }
        
        // Create updated exchange rates object
        _exchangeRates = ExchangeRates(
          base: _exchangeRates!.base,
          timestamp: _exchangeRates!.timestamp,
          rates: updatedRates,
        );
      }
      
      // Update the values of all selected currencies
      _updateCurrencyValues();
      
      print('✅ Exchange rates ready - contains rates for ${_exchangeRates!.rates.length} currencies');
      print('✅ Selected currencies (${_selectedCurrencies.length}): ${_selectedCurrencies.map((c) => c.code).join(", ")}');
      
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
        
        // Ensure rates include all selected currencies
        final missingCurrencies = _selectedCurrencies
            .where((c) => !cachedRates.rates.containsKey(c.code.toUpperCase()))
            .map((c) => c.code)
            .toList();
        
        if (missingCurrencies.isNotEmpty) {
          print('⚠️ Cached rates missing data for: ${missingCurrencies.join(", ")}');
          print('⚠️ Adding mock rates for missing currencies');
          
          // Get mock rates as a last resort
          final mockRates = _getMockExchangeRates();
          
          // Add missing rates from mock data
          final updatedRates = Map<String, double>.from(cachedRates.rates);
          for (final code in missingCurrencies) {
            // Use a default rate if nothing else is available
            updatedRates[code.toUpperCase()] = mockRates.rates[code.toUpperCase()] ?? 1.0;
            print('   Added fallback rate for $code: ${updatedRates[code.toUpperCase()]}');
          }
          
          // Create updated exchange rates object
          _exchangeRates = ExchangeRates(
            base: cachedRates.base,
            timestamp: cachedRates.timestamp,
            rates: updatedRates,
          );
        }
        
        // Even with cached rates, we should update the UI
        _updateCurrencyValues();
      } else {
        // Last resort - use mock data
        print('❌ No cached rates available, using mock data as last resort');
        _exchangeRates = _getMockExchangeRates();
        _isOffline = true;
        // Update values with mock data
        _updateCurrencyValues();
      }
      
      _isLoadingRates = false;
      notifyListeners();
      return false;
    } finally {
      // GUARANTEED FINAL CHECK - make absolutely sure we have rates
      if (_exchangeRates == null) {
        _exchangeRates = _getMockExchangeRates();
        _updateCurrencyValues();
      }
      
      // Make sure we have a rate for the base currency
      if (_exchangeRates != null && _baseCurrencyCode.isNotEmpty) {
        final baseCurrencyUppercase = _baseCurrencyCode.toUpperCase();
        if (!_exchangeRates!.rates.containsKey(baseCurrencyUppercase)) {
          print('⚠️ FINAL CHECK: Still missing rates for: $_baseCurrencyCode');
          print('⚠️ Adding mock rates one last time');
          
          // Create a modified map with the base currency included
          final updatedRates = Map<String, double>.from(_exchangeRates!.rates);
          // The base currency needs to be 1.0 when converted to itself
          updatedRates[baseCurrencyUppercase] = 1.0;
          print('   Added last-resort rate for $_baseCurrencyCode: 1.0');
          
          // Update the exchange rates object
          _exchangeRates = ExchangeRates(
            base: _exchangeRates!.base,
            timestamp: _exchangeRates!.timestamp,
            rates: updatedRates
          );
        }
      }
    }
  }
  
  // Helper method to get mock exchange rates
  ExchangeRates _getMockExchangeRates() {
    // Define standard exchange rates relative to USD
    final Map<String, double> usdBasedRates = {
      'USD': 1.0,
      'EUR': 0.93,
      'GBP': 0.79,
      'JPY': 150.2,
      'AUD': 1.53,
      'CAD': 1.36,
      'CHF': 0.89,
      'CNY': 7.24,
      'INR': 83.4,
      'BTC': 0.000016,
      'AED': 3.67,
      'KZT': 447.5,
      'TRY': 32.03,
      'BAT': 0.21,    // Basic Attention Token
      'BTT': 0.0000007, // BitTorrent
      'BTN': 83.17,   // Bhutan Ngultrum
      'BTG': 40.72,   // Bitcoin Gold
    };
    
    // If the base currency is USD, return as is
    if (_baseCurrencyCode == 'USD') {
      final rates = Map<String, double>.from(usdBasedRates);
      rates.remove('USD'); // Remove base currency
      return ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: rates
      );
    }
    
    // For non-USD base, convert rates
    final baseToUsd = usdBasedRates[_baseCurrencyCode.toUpperCase()] ?? 1.0;
    final Map<String, double> convertedRates = {};
    
    usdBasedRates.forEach((code, usdRate) {
      if (code != _baseCurrencyCode.toUpperCase()) {
        convertedRates[code] = usdRate / baseToUsd;
      }
    });
    
    return ExchangeRates(
      base: _baseCurrencyCode.toUpperCase(),
      timestamp: DateTime.now(),
      rates: convertedRates
    );
  }
  
  // Try to refresh rates, respecting rate limits for free users
  Future<RefreshResult> tryRefreshRates() async {
    try {
      final isPremium = _userPreferences?.isPremium ?? false;
      final canRefresh = canRefreshRatesToday;
      
      print('🔄 REFRESH CHECK:');
      print('   🎖️ User is premium: $isPremium');
      print('   📅 Can refresh today: $canRefresh');
      print('   📅 Last refresh: ${_userPreferences?.lastRatesRefresh}');
      
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
      if (canRefresh) {
        print('🔄 Free user - has not refreshed today - refreshing rates');
        final success = await fetchExchangeRates();
        
        if (!success) {
          return RefreshResult(
            success: false, 
            errorMessage: error ?? 'Failed to fetch exchange rates'
          );
        }
        
        // Make sure the lastRatesRefresh timestamp is updated correctly
        await updateLastRefreshTimestamp(DateTime.now());
        
        print('✅ Free user refresh completed successfully');
        print('📅 Updated last refresh timestamp: ${_userPreferences?.lastRatesRefresh}');
        print('📅 Can refresh again: ${_userPreferences?.canRefreshRatesToday()}');
        
        return RefreshResult(success: true);
      } else {
        print('🔄 Free user - already refreshed today - showing limit message');
        return RefreshResult(
          success: false,
          limitReached: true,
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
  Future<void> selectCurrencies(List<String> currencyCodes, {bool shouldRecalculate = true}) async {
    print('🔄 Selecting currencies: ${currencyCodes.join(", ")}');
    
    // Store current values before processing
    final currentValues = Map<String, double>.fromEntries(
      _selectedCurrencies.map((c) => MapEntry(c.code, c.value))
    );
    
    // Get base currency code
    final baseCurrencyCode = _userPreferences?.baseCurrencyCode ?? '';
    
    // CRITICAL FIX: Check if the base currency is included in the provided list
    if (baseCurrencyCode.isNotEmpty && !currencyCodes.contains(baseCurrencyCode)) {
      print('⚠️ Base currency $baseCurrencyCode missing from provided currency codes! Adding it.');
      // Always insert at position 0
      currencyCodes.insert(0, baseCurrencyCode);
    }
    
    // CRITICAL FIX: Deduplicate currency codes first, in case there are multiple entries for the same currency
    final Set<String> uniqueCodes = Set<String>.from(currencyCodes);
    
    // Check - if base currency exists, make sure it comes first
    final List<String> sortedCodes = [];
    if (baseCurrencyCode.isNotEmpty) {
      // First remove the base currency if it exists in the unique codes
      uniqueCodes.remove(baseCurrencyCode);
      // Then add it at the beginning
      sortedCodes.add(baseCurrencyCode);
    }
    // Add all other currencies
    sortedCodes.addAll(uniqueCodes);
    
    print('📌 Currency order: Base=$baseCurrencyCode, Others=${sortedCodes.where((c) => c != baseCurrencyCode).join(", ")}');
    
    // Safety check - make sure we have loaded currencies
    if (_allCurrencies.isEmpty) {
      print('⚠️ No currencies loaded yet, loading them first');
      await loadAllCurrencies();
    }
    
    try {
      // Double-check the base currency is at the first position
      if (sortedCodes.isNotEmpty && sortedCodes.first != baseCurrencyCode && baseCurrencyCode.isNotEmpty) {
        print('⚠️ Base currency not at first position! Fixing the order...');
        sortedCodes.remove(baseCurrencyCode);
        sortedCodes.insert(0, baseCurrencyCode);
      }
      
      // Map sorted codes to Currency objects
      _selectedCurrencies = sortedCodes
          .where((code) => _allCurrencies.any((c) => c.code == code))
          .map((code) => _allCurrencies.firstWhere((c) => c.code == code, 
                orElse: () {
                  print('⚠️ Could not find currency $code in all currencies');
                  return Currency(
                    code: code, 
                    name: 'Unknown Currency', 
                    value: 1.0, 
                    symbol: '', 
                    flagUrl: ''
                  );
                }))
          .toList();
      
      // VERIFICATION: Check base currency is at the top of selected currencies
      if (_selectedCurrencies.isNotEmpty && baseCurrencyCode.isNotEmpty) {
        if (_selectedCurrencies.first.code != baseCurrencyCode) {
          print('⚠️ ERROR: Base currency not at first position after selection!');
          // Try to fix the order one more time
          final baseCurrencyIndex = _selectedCurrencies.indexWhere((c) => c.code == baseCurrencyCode);
          if (baseCurrencyIndex >= 0) {
            final baseCurrency = _selectedCurrencies.removeAt(baseCurrencyIndex);
            _selectedCurrencies.insert(0, baseCurrency);
            print('✅ Fixed: Base currency moved to first position');
          } else {
            print('⚠️ CRITICAL ERROR: Base currency missing from selected currencies!');
            // Try to add it if possible
            final baseCurrency = _allCurrencies.firstWhere(
              (c) => c.code == baseCurrencyCode,
              orElse: () => Currency(
                code: baseCurrencyCode,
                name: 'Unknown Currency',
                value: 1.0,
                symbol: '',
                flagUrl: ''
              )
            );
            _selectedCurrencies.insert(0, baseCurrency);
            print('✅ Added missing base currency to selected currencies');
          }
        }
      }
      
      // Restore previous values if we're not recalculating
      if (!shouldRecalculate) {
        print('🔄 Preserving existing values during reordering');
        for (var currency in _selectedCurrencies) {
          if (currentValues.containsKey(currency.code)) {
            currency.value = currentValues[currency.code]!;
          }
        }
      }
      
      print('✅ Selected currencies: ${_selectedCurrencies.map((c) => c.code).join(", ")}');
      
      // Make sure the currency selection is saved to user preferences
      if (_userPreferences != null) {
        // Get the final list of currency codes after all our processing
        final finalCodes = _selectedCurrencies.map((c) => c.code).toList();
        
        // Create updated user preferences
        final updatedPrefs = _userPreferences!.copyWith(
          selectedCurrencyCodes: finalCodes,
          baseCurrencyCode: baseCurrencyCode.isNotEmpty ? baseCurrencyCode : 
            (finalCodes.isNotEmpty ? finalCodes.first : 'USD')
        );
        
        // Save to storage
        await _storageService.saveUserPreferences(updatedPrefs);
        
        // Update in memory
        _userPreferences = updatedPrefs;
        
        // Verify save was successful
        final verification = await _storageService.loadUserPreferences();
        print('📝 Verification - Saved currencies: ${verification.selectedCurrencyCodes.join(", ")}');
        print('📝 Verification - Saved base currency: ${verification.baseCurrencyCode}');
      }
    } catch (e) {
      print('❌ Error selecting currencies: $e');
      // In case of error, keep at least the base currency
      if (_selectedCurrencies.isEmpty && baseCurrencyCode.isNotEmpty) {
        try {
          final baseCurrency = _allCurrencies.firstWhere((c) => c.code == baseCurrencyCode);
          _selectedCurrencies = [baseCurrency];
        } catch (e) {
          print('❌ Error finding currency: $e');
        }
      }
    }
    
    // Set initial values based on base currency if we have rates AND we should recalculate
    if (shouldRecalculate && baseCurrencyCode.isNotEmpty) {
      _recalculateValuesFromCurrency(baseCurrencyCode, 1.0);
    }
    
    // CRITICAL FIX: Call method to ensure base currency is in the selected currencies
    _updateSelectedCurrencies();
    
    // Fetch latest rates for selected currencies only if we should recalculate
    if (shouldRecalculate) {
      await fetchExchangeRates();
    }
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
  void setCurrentlyEditedCurrencyCode(String code) {
    print('📝 Setting currently edited currency: $code');
    _currentlyEditedCurrencyCode = code;
    notifyListeners();
  }
  
  void clearCurrentlyEditedCurrencyCode() {
    if (_currentlyEditedCurrencyCode != null) {
      print('📝 Clearing currently edited currency: $_currentlyEditedCurrencyCode');
      _currentlyEditedCurrencyCode = null;
      notifyListeners();
    }
  }
  
  // Update the value of a specific currency and recalculate other currency values
  Future<bool> updateCurrencyValue(String code, double value) async {
    // Check if exchange rates are available
    if (_exchangeRates == null || _exchangeRates!.rates.isEmpty) {
      _error = 'Exchange rates not available';
      notifyListeners(); // Notify listeners about the error so UI can show a message
      return false;
    }
    
    // Find the currency in the selected list
    final index = _selectedCurrencies.indexWhere((c) => c.code == code);
    if (index == -1) {
      return false;
    }
    
    final oldValue = _selectedCurrencies[index].value;
    
    // Skip update if the new value is too close to the old value to avoid unnecessary refreshes
    if ((oldValue - value).abs() < 0.0001) {
      return true; // This is not a failure, just no update needed
    }
    
    try {
      // Use the comprehensive recalculation method instead of duplicating calculation logic
      await _recalculateValuesFromCurrency(code, value);
      return true;
    } catch (e) {
      print('❌ Error updating currency value: $e');
      return false;
    }
  }

  // PRIVATE: Recalculate all currency values when base currency changes
  void _updateCurrencyValues() {
    try {
      if (_exchangeRates == null) {
        print('⚠️ Cannot recalculate: No exchange rates available');
        return;
      }

      if (_selectedCurrencies.isEmpty) {
        print('⚠️ Cannot recalculate: No selected currencies available');
        
        // Critical fix: If no currencies are selected, try to add at least the base currency
        if (_baseCurrencyCode.isNotEmpty && _allCurrencies.isNotEmpty) {
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
          
          _selectedCurrencies = [baseCurrency];
          print('✅ Added base currency $_baseCurrencyCode to empty selected currencies list');
        }
        
        // If we still don't have any currencies, return
        if (_selectedCurrencies.isEmpty) {
          return;
        }
      }

      // Critical fix: Check if base currency is missing from selected currencies
      final hasBaseCurrency = _selectedCurrencies.any((c) => c.code == _baseCurrencyCode);
      if (!hasBaseCurrency && _baseCurrencyCode.isNotEmpty) {
        print('⚠️ Base currency $_baseCurrencyCode is missing from selected currencies');
        
        // Find the base currency object
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
        
        // Add it to the beginning of the list
        _selectedCurrencies.insert(0, baseCurrency);
        print('✅ Added base currency $_baseCurrencyCode to selected currencies');
      }

      // Set all selected currency values based on the exchange rates
      for (final currency in _selectedCurrencies) {
        if (currency.code == _baseCurrencyCode) {
          currency.value = 1.0;
        } else {
          final rate = _exchangeRates!.rates[currency.code.toUpperCase()];
          if (rate != null) {
            currency.value = rate;
          } else {
            print('⚠️ Missing rate for ${currency.code}');
            currency.value = 1.0; // Default if not found
          }
        }
      }
      
      print('📊 Recalculated values based on exchange rates');
    } catch (e) {
      print('❌ Error updating currency values: $e');
    }
  }

  // PRIVATE: COMPREHENSIVE recalculation based on a changed currency
  Future<void> _recalculateValuesFromCurrency(String sourceCurrencyCode, double sourceValue) async {
    if (_exchangeRates == null || _exchangeRates!.rates.isEmpty) {
      print('⚠️ Cannot recalculate: No exchange rates available');
      _error = "Exchange rates not available";
      return; // Return silently instead of throwing exception
    }
    
    // Safety check - make sure we have currencies to work with
    if (_selectedCurrencies.isEmpty) {
      print('⚠️ Cannot recalculate: No selected currencies available');
      return; // Return silently instead of throwing exception
    }
    
    try {
      // IMPORTANT: First, convert the source value to USD equivalent 
      // This is because our exchange rates are USD-based
      double sourceUsdRate = _exchangeRates!.getUsdRate(sourceCurrencyCode);
      
      // Check if rate is too small, which could cause overflow with large numbers
      if (sourceUsdRate <= 0.000001) {
        print('⚠️ Invalid exchange rate for $sourceCurrencyCode: $sourceUsdRate');
        sourceUsdRate = 1.0; // Use default rate as fallback
      }
      
      // Calculate USD value with extra precision
      double sourceValueInUsd = sourceValue / sourceUsdRate;
      
      // Create a brand new list to store all updated currencies
      List<Currency> updatedCurrencies = [];
      
      // Process each selected currency
      for (final currency in _selectedCurrencies) {
        double newValue;
        
        if (currency.code == sourceCurrencyCode) {
          // Source currency gets the input value directly (no calculation)
          newValue = sourceValue;
        } else {
          // Get the target currency's USD rate
          final targetUsdRate = _exchangeRates!.getUsdRate(currency.code);
          
          // Verify we have a valid rate
          if (targetUsdRate <= 0.000001) {
            print('⚠️ Invalid rate for ${currency.code}: $targetUsdRate, using 1.0 as fallback');
            // Use a fallback rate instead of skipping
            newValue = sourceValueInUsd;
          } else {
            // Calculate the new value based on USD conversion
            newValue = sourceValueInUsd * targetUsdRate;
            
            // Handle very large numbers gracefully
            if (newValue.isInfinite || newValue.isNaN) {
              print('⚠️ Invalid calculation result for ${currency.code}, using 1.0 as fallback');
              newValue = 1.0; // Use fallback value
            }
          }
        }
        
        // Add the currency with updated value to our list
        updatedCurrencies.add(Currency(
          code: currency.code,
          name: currency.name,
          symbol: currency.symbol,
          flagUrl: currency.flagUrl,
          value: newValue
        ));
      }
      
      // Safety check - if we somehow ended up with no currencies
      if (updatedCurrencies.isEmpty) {
        print('⚠️ No valid currencies after recalculation, restoring original list');
        return; // Keep the existing values instead of throwing an exception
      }
      
      // Important: replace the entire list with the new list
      _selectedCurrencies = updatedCurrencies;
      
      // Save values to storage
      await _storageService.saveCurrencyValues(_selectedCurrencies);
      
      // IMPORTANT: Always notify listeners to refresh the UI
      notifyListeners();
    } catch (e) {
      print('❌ Error during recalculation: $e');
      // Don't re-throw, just continue with existing values
    }
  }

  // Set the base currency and update all rates
  Future<bool> setBaseCurrency(String currencyCode) async {
    print('🔄 Setting base currency to: $currencyCode (current: $_baseCurrencyCode)');
    
    try {
      // Get the original base currency code before we change it
      final originalBaseCurrency = _baseCurrencyCode;
      
      // Update the base currency code
      _baseCurrencyCode = currencyCode;
      
      // Get the currency to set as base
      Currency? baseCurrency;
      
      // Try to find it in selected currencies first
      try {
        baseCurrency = _selectedCurrencies.firstWhere((c) => c.code == currencyCode);
      } catch (e) {
        // Not in selected currencies, try to find it in all currencies
        try {
          if (_allCurrencies.isEmpty) {
            await loadAllCurrencies();
          }
          
          baseCurrency = _allCurrencies.firstWhere((c) => c.code == currencyCode);
          
          // Add to selected currencies if it's not already there
          if (!_selectedCurrencies.any((c) => c.code == currencyCode)) {
            _selectedCurrencies.add(baseCurrency);
            print('📌 Added new base currency to selected currencies: $currencyCode');
          }
        } catch (e) {
          print('❌ Error finding currency: $e');
          // Create a placeholder currency as last resort
          baseCurrency = Currency(
            code: currencyCode,
            name: currencyCode,
            symbol: currencyCode,
            value: 1.0,
            flagUrl: ''
          );
          
          // Add to selected currencies
          _selectedCurrencies.add(baseCurrency);
        }
      }
      
      // Ensure the base currency is at the top of the list
      final index = _selectedCurrencies.indexWhere((c) => c.code == currencyCode);
      if (index > 0) {
        final currency = _selectedCurrencies.removeAt(index);
        _selectedCurrencies.insert(0, currency);
        print('📌 Moved base currency to top position');
      } else if (index == -1) {
        // This should not happen now that we added it above, but just in case
        _selectedCurrencies.insert(0, baseCurrency!);
        print('⚠️ Base currency not found in list, adding it to top position');
      }
      
      // If we have exchange rates, recalculate values
      if (_exchangeRates != null && _exchangeRates!.rates.isNotEmpty) {
        _recalculateValuesFromCurrency(currencyCode, 1.0);
        print('📊 Recalculated values based on new base currency');
      } else if (_userPreferences != null && !(_userPreferences!.isPremium || _userPreferences!.canRefreshRatesToday())) {
        // Free user who can't fetch new rates
        print('⚠️ Free user has already refreshed today - calculating with existing rates');
        // We still need to recalculate from old base to new base
        _recalculateValuesFromCurrency(currencyCode, 1.0);
      } else {
        print('⚠️ No exchange rates available for recalculation');
      }
      
      // Save the base currency to user preferences
      if (_userPreferences != null) {
        print('💾 Saving base currency to user preferences: $currencyCode');
        
        // Make a copy of the current selected currency codes
        final currencyCodes = _selectedCurrencies.map((c) => c.code).toList();
        
        // Update user preferences
        final updatedPrefs = _userPreferences!.copyWith(
          baseCurrencyCode: currencyCode,
          selectedCurrencyCodes: currencyCodes
        );
        
        // Save to storage
        await _storageService.saveUserPreferences(updatedPrefs);
        
        // Update in-memory preferences
        _userPreferences = updatedPrefs;
        
        // Verify the save
        final verification = await _storageService.loadUserPreferences();
        print('✅ Verification - saved base currency: ${verification.baseCurrencyCode}');
        print('✅ Verification - saved selected currencies: ${verification.selectedCurrencyCodes.join(", ")}');
      }
      
      // Notify listeners
      notifyListeners();
      
      return true;
    } catch (e) {
      print('❌ Error setting base currency: $e');
      return false;
    }
  }

  // Make sure the base currency is in the selected currencies and at the top
  Future<void> ensureBaseCurrencyIsLoaded() async {
    print('📌 Ensuring base currency $_baseCurrencyCode is in the selected currencies list');
    
    // Always use preferences first!
    if (_userPreferences != null && _userPreferences!.baseCurrencyCode.isNotEmpty) {
      // Critical fix: Update the base currency from preferences here
      final savedBaseCurrency = _userPreferences!.baseCurrencyCode;
      if (savedBaseCurrency != _baseCurrencyCode) {
        print('⚠️ Fixing base currency to match preferences: $savedBaseCurrency (was: $_baseCurrencyCode)');
        _baseCurrencyCode = savedBaseCurrency;
      }
    }
    
    if (!_selectedCurrencies.any((currency) => currency.code == _baseCurrencyCode)) {
      print('⚠️ Base currency $_baseCurrencyCode is missing from selected currencies');
      
      // Safety check - make sure we have loaded currencies
      if (_allCurrencies.isEmpty) {
        print('⚠️ No currencies loaded yet, loading them first');
        await loadAllCurrencies();
      }
      
      // Find the base currency in all currencies
      final baseCurrency = _allCurrencies.firstWhere(
        (currency) => currency.code == _baseCurrencyCode,
        orElse: () => Currency(
          code: _baseCurrencyCode,
          name: _baseCurrencyCode,
          symbol: _baseCurrencyCode,
          value: 1.0,
          flagUrl: ''
        )
      );
      
      // Add at position 0
      _selectedCurrencies.insert(0, baseCurrency);
      print('✅ Added base currency $_baseCurrencyCode to selected currencies');
      
      // Update user preferences to include this currency
      if (_userPreferences != null) {
        final updatedCodes = _selectedCurrencies.map((c) => c.code).toList();
        final updatedPrefs = _userPreferences!.copyWith(
          selectedCurrencyCodes: updatedCodes,
          baseCurrencyCode: _baseCurrencyCode
        );
        await _storageService.saveUserPreferences(updatedPrefs);
        _userPreferences = updatedPrefs;
        
        print('💾 Saved user preferences with base currency $_baseCurrencyCode');
        print('    VERIFICATION - stored currencies: ${updatedPrefs.selectedCurrencyCodes.join(", ")}');
        print('    VERIFICATION - stored base currency: ${updatedPrefs.baseCurrencyCode}');
      }
    } else {
      // Check if the base currency is at position 0
      final index = _selectedCurrencies.indexWhere((c) => c.code == _baseCurrencyCode);
      if (index > 0) {
        // Move the base currency to position 0
        final baseCurrency = _selectedCurrencies.removeAt(index);
        _selectedCurrencies.insert(0, baseCurrency);
        print('✅ Reordered currencies: Moved $_baseCurrencyCode from position $index to 0');
        
        // Save the new order to preferences
        if (_userPreferences != null) {
          final updatedCodes = _selectedCurrencies.map((c) => c.code).toList();
          final updatedPrefs = _userPreferences!.copyWith(
            selectedCurrencyCodes: updatedCodes,
            baseCurrencyCode: _baseCurrencyCode
          );
          await _storageService.saveUserPreferences(updatedPrefs);
          _userPreferences = updatedPrefs;
          
          print('💾 Saved updated currency order with new base to preferences');
          print('    VERIFICATION - stored currencies: ${updatedCodes.join(", ")}');
          print('    VERIFICATION - stored base currency: ${updatedPrefs.baseCurrencyCode}');
        }
      } else {
        print('✅ Base currency $_baseCurrencyCode is already at the top position');
      }
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

  // Check if the user can refresh rates today
  Future<bool> _canRefreshToday() async {
    if (_userPreferences == null) {
      // Without preferences, just use the local state
      return canRefreshRatesToday;
    }
    
    // For premium users, always allow refresh
    if (_userPreferences!.isPremium) {
      print('✅ User is premium - can refresh anytime');
      return true;
    }
    
    // For free users, check if they've already refreshed today
    final canRefresh = _userPreferences!.canRefreshRatesToday();
    print('📆 Free user can refresh today: $canRefresh');
    return canRefresh;
  }

  // Fetch exchange rates directly from the API
  Future<void> _fetchExchangeRatesFromApi() async {
    print('🔄 Fetching fresh exchange rates from API for base currency: $_baseCurrencyCode');
    
    if (_baseCurrencyCode.isEmpty) {
      print('⚠️ Base currency code is empty, defaulting to USD');
      _baseCurrencyCode = 'USD';
    }
    
    try {
      // Show loading state
      _isLoadingRates = true;
      _error = null;
      notifyListeners();
      
      // Fetch exchange rates from the API
      final rates = await _apiService.fetchExchangeRates(_baseCurrencyCode);
      
      if (rates != null) {
        print('✅ Successfully fetched exchange rates from API');
        _exchangeRates = rates;
        _isOffline = false;
        
        // Cache the rates for offline use
        await _storageService.saveExchangeRates(rates);
        print('💾 Cached exchange rates');
        
        // Update the last refresh time in user preferences
        if (_userPreferences != null) {
          final updatedPrefs = _userPreferences!.copyWith(
            lastRatesRefresh: DateTime.now()
          );
          await _storageService.saveUserPreferences(updatedPrefs);
          _userPreferences = updatedPrefs;
          print('📅 Updated last refresh time in preferences');
        }
        
        // Recalculate all currency values
        _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      } else {
        print('❌ Failed to fetch exchange rates from API');
        _error = 'Failed to fetch exchange rates.';
        _isOffline = true;
        
        // Try to fallback to cached rates
        final cachedRates = await _storageService.loadExchangeRates();
        if (cachedRates != null) {
          print('💾 Using cached exchange rates as fallback');
          _exchangeRates = cachedRates;
          _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
        }
      }
    } catch (e) {
      print('❌ Error fetching exchange rates: $e');
      _error = 'Error fetching exchange rates: $e';
      _isOffline = true;
      
      // Try to fallback to cached rates
      final cachedRates = await _storageService.loadExchangeRates();
      if (cachedRates != null) {
        print('💾 Using cached exchange rates after error');
        _exchangeRates = cachedRates;
        _recalculateValuesFromCurrency(_baseCurrencyCode, 1.0);
      }
    } finally {
      _isLoadingRates = false;
      notifyListeners();
    }
  }

  // Update the list of selected currencies with any missing currencies
  void _updateSelectedCurrencies() {
    // Make sure base currency is included in the selected currencies
    if (_baseCurrencyCode.isNotEmpty && _allCurrencies.isNotEmpty) {
      final baseCurrencyIndex = _selectedCurrencies.indexWhere((c) => c.code == _baseCurrencyCode);
      
      // If base currency is not in the selected currencies, add it
      if (baseCurrencyIndex == -1) {
        try {
          print('⚠️ Base currency $_baseCurrencyCode missing from selected currencies. Adding it.');
          final baseCurrency = _allCurrencies.firstWhere(
            (c) => c.code == _baseCurrencyCode,
            orElse: () => Currency(
              code: _baseCurrencyCode,
              name: 'Unknown Currency',
              value: 1.0,
              symbol: '',
              flagUrl: ''
            )
          );
          
          // Insert at the beginning
          _selectedCurrencies.insert(0, baseCurrency);
          print('✅ Added base currency to selected currencies list');
        } catch (e) {
          print('❌ Error adding base currency: $e');
        }
      } else if (baseCurrencyIndex > 0) {
        // If base currency is not at the first position, move it there
        print('⚠️ Base currency $_baseCurrencyCode not at first position. Moving it.');
        final baseCurrency = _selectedCurrencies.removeAt(baseCurrencyIndex);
        _selectedCurrencies.insert(0, baseCurrency);
        print('✅ Moved base currency to first position');
      }
    }
    
    // Notify listeners of the changes
    notifyListeners();
  }
}