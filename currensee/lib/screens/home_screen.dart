import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/currency_list_item.dart';
import '../widgets/refresh_indicator.dart';
import '../widgets/ad_banner.dart';
import '../models/currency.dart';
import '../services/purchase_service.dart';
import '../services/ad_service.dart';
import 'currencies_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AdService _adService = AdService();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _adService.loadInterstitialAd(); // Preload interstitial ad
    
    // Schedule loading after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSelectedCurrencies();
    });
  }
  
  Future<void> _loadSelectedCurrencies() async {
    if (!mounted) return;
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    if (userPrefs.selectedCurrencyCodes.isNotEmpty) {
      await currencyProvider.reloadSelectedCurrencies(userPrefs.selectedCurrencyCodes);
    }
  }

  // Handle premium purchase flow
  void _handlePremiumPurchase() {
    print('🔰 Starting simplified premium purchase flow');
    _showPremiumPrompt();
  }

  // Helper method to show premium prompt
  void _showPremiumPrompt() {
    print('📱 Showing premium prompt dialog');
    showDialog(
      context: context,
      barrierDismissible: true, // Allow user to dismiss by tapping outside
      builder: (BuildContext dialogContext) => PremiumPromptDialog(
        onPurchase: () {
          // The dialog already pops itself, so we don't need to do it here
          print('📱 User agreed to purchase premium');
          _purchasePremium();
        },
        onCancel: () {
          // Dialog already handles its own dismissal
          print('📱 User canceled premium prompt');
        },
      ),
    );
  }

  // Process the actual payment - redirects to the emulated version
  Future<void> _processPremiumPayment() async {
    print('🔰 Redirecting old premium payment process to emulated version');
    if (mounted) {
      _purchasePremium();
    }
  }

  Future<void> _refreshRates() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    // Force reload preferences to get the latest state
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    await currencyProvider.forceReloadPreferences();
    
    // Check if user is premium or can refresh today
    final isPremium = currencyProvider.userPreferences?.isPremium ?? false;
    final canRefreshToday = currencyProvider.canRefreshRatesToday;
    final lastRefresh = currencyProvider.userPreferences?.lastRatesRefresh;
    
    print('🔄 REFRESH CHECK:');
    print('   isPremium: $isPremium');
    print('   canRefreshToday: $canRefreshToday');
    print('   lastRefresh: $lastRefresh');
    
    // If user is free and already used their daily refresh, show premium dialog
    if (!isPremium && !canRefreshToday) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        
        print('🔄 Free user has used daily refresh, showing premium prompt');
        
        // Add a small delay to ensure UI is updated
        await Future.delayed(Duration(milliseconds: 100));
        
        // Show premium prompt
        _showPremiumPrompt();
      }
      return; // Exit early, no need to proceed with refresh
    }
    
    try {
      print('🔄 Attempting to refresh rates...');
      final result = await currencyProvider.tryRefreshRates();
      
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        
        // When a free user has just used their daily refresh, force an update of the timestamp
        if (!isPremium && result.success) {
          print('🔄 Free user successful refresh - updating lastRatesRefresh to now');
          
          // This ensures next refresh attempt will show premium prompt
          currencyProvider.updateLastRefreshTimestamp(DateTime.now());
        }
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exchange rates updated')),
          );
        } else if (result.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage!)),
          );
        }
      }
    } catch (e) {
      print('❌ Error in _refreshRates: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update rates: ${e.toString()}')),
        );
      }
    }
  }

  void _showSettingsScreen() {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Show ad for free users
    if (!userPrefs.isPremium) {
      _adService.showInterstitialAd();
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showCurrenciesScreen() async {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Show ad for free users
    if (!userPrefs.isPremium) {
      _adService.showInterstitialAd();
    }
    
    // Store the current number of selected currencies to detect changes
    final int currentCurrencyCount = userPrefs.selectedCurrencyCodes.length;
    
    // Navigate to currencies screen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CurrenciesScreen()),
    );
    
    // Check if currencies were added/removed and refresh if needed
    if (mounted) {
      final int newCurrencyCount = userPrefs.selectedCurrencyCodes.length;
      
      if (currentCurrencyCount != newCurrencyCount) {
        // Force refresh of currency provider
        await Provider.of<CurrencyProvider>(context, listen: false).fetchExchangeRates();
      }
    }
  }

  void _setBaseCurrency(String currencyCode) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    userPrefs.setBaseCurrency(currencyCode);
    currencyProvider.setBaseCurrency(currencyCode);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$currencyCode set as base currency')),
    );
  }

  Future<void> _purchasePremium() async {
    print('💰 Starting emulated premium purchase process');
    
    // Make sure we're using the main context and mounted
    if (!mounted) return;
    
    // Store a reference to the scaffold messenger to avoid context issues
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Show a loading snackbar instead of navigating
    final loadingSnackBar = SnackBar(
      content: Row(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2.0,
          ),
          const SizedBox(width: 20),
          const Text('Processing purchase...'),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Use the stored reference
              scaffoldMessenger.hideCurrentSnackBar();
              print('💰 User canceled purchase during processing');
              
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Purchase canceled')),
              );
            },
            child: const Text('CANCEL', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      duration: const Duration(seconds: 3),
    );
    
    // Safely show the loading snackbar
    scaffoldMessenger.showSnackBar(loadingSnackBar);
    
    try {
      // Simulate a brief delay for the payment process - but shorter
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if still mounted after the delay
      if (!mounted) return;
      
      // Get the providers we need
      final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      
      // Hide the loading snackbar
      scaffoldMessenger.hideCurrentSnackBar();
    
      // Set premium status directly (emulated successful purchase)
      await userPrefs.setPremiumStatus(true);
      print('💰 Emulated purchase successful, user is now premium');
      
      // Show success message
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Premium purchase successful! You now have unlimited refreshes.'),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Update UI state - force reload preferences
      await currencyProvider.forceReloadPreferences();
      
      // Trigger a refresh to show that it works now - check if mounted first
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('💰 Error during emulated purchase: $e');
      
      // Use the stored reference
      scaffoldMessenger.hideCurrentSnackBar();
      
      // Show error message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error processing purchase: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isOffline = currencyProvider.isOffline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark 
          ? Theme.of(context).scaffoldBackgroundColor
          : Theme.of(context).colorScheme.background.withOpacity(0.98),
      appBar: AppBar(
        title: const Text(
          'Currency Converter',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: _isRefreshing 
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.primary,
            ),
            onPressed: _isRefreshing ? null : _refreshRates,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              onPressed: _showSettingsScreen,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isOffline)
            Container(
              color: isDark 
                  ? Colors.amber.shade900.withOpacity(0.15)
                  : Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 20,
                    color: isDark ? Colors.amber.shade500 : Colors.amber.shade900,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Using offline data. Last updated: ${currencyProvider.exchangeRates?.timestamp.toString() ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.amber.shade500 : Colors.amber.shade900,
                        height: 1.2,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: currencyProvider.selectedCurrencies.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.currency_exchange_rounded,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No currencies selected',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add currencies to start converting between different currencies in real-time',
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _showCurrenciesScreen,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: const Text(
                            'Add Currencies',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : currencyProvider.selectedCurrencies.length == 1
                ? ReorderableListView.builder(
                    itemCount: currencyProvider.selectedCurrencies.length,
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    onReorder: (oldIndex, newIndex) {
                      // Get the base currency index
                      final baseCurrencyIndex = currencyProvider.selectedCurrencies
                          .indexWhere((c) => c.code == userPrefs.baseCurrencyCode);
                      
                      // Skip reordering if trying to move base currency
                      if (oldIndex == baseCurrencyIndex) return;
                      
                      // Adjust indices for ReorderableListView behavior
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      
                      // Skip if trying to move an item before the base currency
                      if (newIndex < baseCurrencyIndex && baseCurrencyIndex > 0) {
                        newIndex = baseCurrencyIndex;
                      }
                      
                      // Process the reordering
                      final currencies = List<Currency>.from(currencyProvider.selectedCurrencies);
                      final currency = currencies.removeAt(oldIndex);
                      currencies.insert(newIndex, currency);
                      
                      // Update user preferences with new order
                      final newOrder = currencies.map((c) => c.code).toList();
                      userPrefs.setInitialCurrencies(
                        baseCurrency: userPrefs.baseCurrencyCode,
                        selectedCurrencies: newOrder,
                      );
                      currencyProvider.selectCurrencies(newOrder);
                    },
                    itemBuilder: (context, index) {
                      final currency = currencyProvider.selectedCurrencies[index];
                      final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                      
                      return ReorderableDragStartListener(
                        key: ValueKey('draggable_${currency.code}'),
                        index: index,
                        enabled: !isBaseCurrency, // Only non-base currencies can be dragged
                        child: CurrencyListItem(
                          currency: currency,
                          isBaseCurrency: isBaseCurrency,
                          onValueChanged: (code, value) {
                            currencyProvider.updateCurrencyValue(code, value);
                          },
                          onLongPress: () {
                            // No action for long press anymore
                          },
                          onSetAsBase: () {
                            _setBaseCurrency(currency.code);
                          },
                          index: index,
                        ),
                      );
                    },
                  )
                : ReorderableListView.builder(
                    itemCount: currencyProvider.selectedCurrencies.length,
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    onReorder: (oldIndex, newIndex) {
                      // Get the base currency index
                      final baseCurrencyIndex = currencyProvider.selectedCurrencies
                          .indexWhere((c) => c.code == userPrefs.baseCurrencyCode);
                      
                      // Skip reordering if trying to move base currency
                      if (oldIndex == baseCurrencyIndex) return;
                      
                      // Adjust indices for ReorderableListView behavior
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      
                      // Skip if trying to move an item before the base currency
                      if (newIndex < baseCurrencyIndex && baseCurrencyIndex > 0) {
                        newIndex = baseCurrencyIndex;
                      }
                      
                      // Process the reordering
                      final currencies = List<Currency>.from(currencyProvider.selectedCurrencies);
                      final currency = currencies.removeAt(oldIndex);
                      currencies.insert(newIndex, currency);
                      
                      // Update user preferences with new order
                      final newOrder = currencies.map((c) => c.code).toList();
                      userPrefs.setInitialCurrencies(
                        baseCurrency: userPrefs.baseCurrencyCode,
                        selectedCurrencies: newOrder,
                      );
                      currencyProvider.selectCurrencies(newOrder);
                    },
                    itemBuilder: (context, index) {
                      final currency = currencyProvider.selectedCurrencies[index];
                      final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                      
                      return ReorderableDragStartListener(
                        key: ValueKey('draggable_${currency.code}'),
                        index: index,
                        enabled: !isBaseCurrency, // Only non-base currencies can be dragged
                        child: CurrencyListItem(
                          currency: currency,
                          isBaseCurrency: isBaseCurrency,
                          onValueChanged: (code, value) {
                            currencyProvider.updateCurrencyValue(code, value);
                          },
                          onLongPress: () {
                            // No action for long press anymore
                          },
                          onSetAsBase: () {
                            _setBaseCurrency(currency.code);
                          },
                          index: index,
                        ),
                      );
                    },
                  ),
          ),
          if (currencyProvider.selectedCurrencies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: ElevatedButton(
                onPressed: _showCurrenciesScreen,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Add Currency',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          // Banner ad at the bottom for free users
          AdBannerWidget(isPremium: userPrefs.isPremium),
        ],
      ),
    );
  }
} 