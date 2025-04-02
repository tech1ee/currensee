import 'dart:async';
import 'dart:ui';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../utils/keyboard_util.dart';
import '../widgets/currency_list_item.dart';
import '../widgets/refresh_indicator.dart';
import '../widgets/ad_banner.dart';
import '../models/currency.dart';
import '../services/purchase_service.dart';
import '../services/ad_service.dart';
import 'currencies_screen.dart';
import 'settings_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Create a custom method channel for iOS keyboard control
const MethodChannel _keyboardChannel = MethodChannel('com.currensee.app/keyboard');

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;
  bool _isRefreshing = false;
  String _errorMessage = '';
  final TextEditingController _amountController = TextEditingController();
  final AdService _adService = AdService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAutoRefresh();
    _adService.loadInterstitialAd();
    
    // Set up auto refresh logic
    _setupAutoRefresh();
    
    // Force a refresh of exchange rates on app startup if needed
    _ensureExchangeRatesLoaded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No need to handle keyboard visibility on app resume
  }

  void _setupAutoRefresh() {
    // Schedule loading after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSelectedCurrencies();
      await _handleAutoRefresh();
    });
  }

  Future<void> _loadSelectedCurrencies() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
      
      print('🔄 Home screen: Loading selected currencies from preferences');
      print('   Base currency: ${userPrefs.baseCurrencyCode}');
      print('   Selected currencies: ${userPrefs.selectedCurrencyCodes.join(", ")}');
      
      // First, ensure base currency in provider matches user preferences
      if (currencyProvider.baseCurrencyCode != userPrefs.baseCurrencyCode) {
        print('🔄 Setting base currency in provider to match preferences: ${userPrefs.baseCurrencyCode}');
        await currencyProvider.setBaseCurrency(userPrefs.baseCurrencyCode);
      }
      
      // Now get the list of selected currencies
      final List<String> selectedCurrencies = userPrefs.selectedCurrencyCodes.toList();
      
      // Deduplicate the selected currencies
      final Set<String> uniqueSelectedCurrencies = selectedCurrencies.toSet();
      final List<String> uniqueSelectedCurrenciesList = uniqueSelectedCurrencies.toList();
      
      // Make sure the base currency is included in the list
      final String baseCurrency = userPrefs.baseCurrencyCode;
      print('📌 Ensuring base currency $baseCurrency is in the selected currencies list');
      
      bool hasBaseCurrency = uniqueSelectedCurrencies.contains(baseCurrency);
      if (!hasBaseCurrency && baseCurrency.isNotEmpty) {
        print('⚠️ Base currency $baseCurrency is missing from selected currencies');
        uniqueSelectedCurrenciesList.insert(0, baseCurrency);
      }
      
      // If reordering is needed, ensure base currency is first
      if (uniqueSelectedCurrenciesList.isNotEmpty && 
          uniqueSelectedCurrenciesList.first != baseCurrency && 
          baseCurrency.isNotEmpty) {
        print('📌 Ensuring base currency $baseCurrency is pinned at the top');
        
        // Remove the base currency from its current position
        uniqueSelectedCurrenciesList.remove(baseCurrency);
        // Add it back at the beginning
        uniqueSelectedCurrenciesList.insert(0, baseCurrency);
        
        // Log the new order
        print('📌 Sorted currency order: ${uniqueSelectedCurrenciesList.join(", ")}');
      }
      
      // Load the currencies with the base currency first
      print('🔄 Reloading selected currencies: ${uniqueSelectedCurrenciesList.join(", ")}');
      await currencyProvider.selectCurrencies(uniqueSelectedCurrenciesList);
      
      // After loading, verify one more time
      print('📌 Home screen: Final check to ensure base currency is loaded');
      print('📌 Ensuring base currency $baseCurrency is in the selected currencies list');
      
      // Final safety check to make sure selected currencies includes base currency
      bool finalHasBaseCurrency = currencyProvider.selectedCurrencies
          .any((c) => c.code == baseCurrency);
          
      if (!finalHasBaseCurrency && baseCurrency.isNotEmpty) {
        print('⚠️ Base currency $baseCurrency is missing from selected currencies');
        
        // Force add the base currency and update again
        final updatedList = [baseCurrency, ...currencyProvider.selectedCurrencies.map((c) => c.code)];
        print('✅ Added base currency $baseCurrency to selected currencies');
        
        // Save to user preferences
        userPrefs.setInitialCurrencies(
          baseCurrency: baseCurrency,
          selectedCurrencies: updatedList,
        );
        
        // Update provider one last time
        await currencyProvider.selectCurrencies(updatedList);
        
        // Get final verification from preferences
        print('💾 Saved user preferences with base currency $baseCurrency');
        print('     VERIFICATION - stored currencies: ${userPrefs.selectedCurrencyCodes.join(", ")}');
        print('     VERIFICATION - stored base currency: ${userPrefs.baseCurrencyCode}');
      }
      
      print('✅ Home screen: Currencies loaded and ordered correctly');
    });
  }

  // Handle automatic refresh on app launch
  Future<void> _handleAutoRefresh() async {
    if (!mounted) return;
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final isPremium = currencyProvider.userPreferences?.isPremium ?? false;
    final canRefreshToday = currencyProvider.canRefreshRatesToday;
    
    print('🔄 AUTO REFRESH CHECK:');
    print('   isPremium: $isPremium');
    print('   canRefreshToday: $canRefreshToday');
    
    // Premium users get automatic refresh on every launch
    if (isPremium) {
      print('🔄 Premium user - auto refreshing rates');
      await _refreshRates();
    } 
    // Free users only get automatic refresh if they haven't refreshed today
    else if (canRefreshToday) {
      print('🔄 Free user - has not refreshed today - auto refreshing rates');
      await _refreshRates();
    } else {
      print('🔄 Free user - already refreshed today - skipping auto refresh');
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

  // Refresh currency rates with proper handling of rate limits
  Future<void> _refreshRates() async {
    setState(() {
      _isRefreshing = true;
    });
    
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    final isPremium = userPrefs.isPremium;
    final canRefreshToday = currencyProvider.canRefreshRatesToday;
    final lastRefresh = currencyProvider.userPreferences?.lastRatesRefresh;
    
    print('🔄 MANUAL REFRESH CHECK:');
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
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exchange rates updated')),
          );
        } else if (result.limitReached ?? false) {
          // Handle the case where refresh limit is reached during the process
          // (this is a failsafe, should be caught by the earlier check)
          print('🔄 Refresh limit reached during refresh, showing premium prompt');
          _showPremiumPrompt();
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
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showCurrenciesScreen() async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    print('Before navigation - selected currencies: ${userPrefs.selectedCurrencyCodes.join(", ")}');
    print('Before navigation - base currency: ${userPrefs.baseCurrencyCode}');
    
    // Dismiss keyboard if it's open
    KeyboardUtil.hideKeyboard();
    
    if (Platform.isIOS) {
      try {
        // For iOS, native method to dismiss keyboard
        await _keyboardChannel.invokeMethod('hideKeyboard');
      } catch (e) {
        print('Failed to hide keyboard via method channel: $e');
      }
    }
    
    // Show interstitial ad only for non-premium users
    _adService.showInterstitialAdIfNotPremium(userPrefs.isPremium);

    // Navigate to the currencies screen with isInitialSetup explicitly set to false
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CurrenciesScreen(isInitialSetup: false)),
    );
    
    if (!mounted) return;
    
    // After returning, force reload preferences to ensure we have the latest data
    await userPrefs.reloadPreferences();
    
    // Reload selected currencies in the currency provider
    await currencyProvider.reloadSelectedCurrencies(userPrefs.selectedCurrencyCodes);
    
    print('After navigation - selected currencies: ${userPrefs.selectedCurrencyCodes.join(", ")}');
    print('After navigation - base currency: ${userPrefs.baseCurrencyCode}');
    
    // Update UI to reflect any changes
    setState(() {});
  }
  
  // Helper to check if two lists have the same elements (order doesn't matter)
  bool _areListsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    
    final sortedList1 = List<String>.from(list1)..sort();
    final sortedList2 = List<String>.from(list2)..sort();
    
    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) return false;
    }
    
    return true;
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

  // Handle currency value change events
  void _handleValueChange(String code, double value) async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Check if exchange rates are available first
    if (currencyProvider.exchangeRates == null || currencyProvider.exchangeRates!.rates.isEmpty) {
      // Show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please refresh exchange rates to update values'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Check if we have a valid exchange rate for this specific currency
    try {
      double rate = currencyProvider.exchangeRates!.getUsdRate(code);
      if (rate <= 0.000001) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No valid exchange rate for $code. Please try refreshing rates.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking exchange rate: $e'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Direct update with response handling
    final updateSucceeded = await currencyProvider.updateCurrencyValue(code, value);
    
    // Check result after the update is completed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !updateSucceeded) {
        // Show error message to user if update failed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update $code. Please try refreshing rates.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _handleCurrencyTap(Currency currency) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    if (currency.code != userPrefs.baseCurrencyCode) {
      _setBaseCurrency(currency.code);
    }
  }

  void _handleCurrencyLongPress(Currency currency) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    if (currency.code != userPrefs.baseCurrencyCode) {
      _showCurrencyOptions(currency);
    }
  }

  void _showCurrencyOptions(Currency currency) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Only show removal option if this isn't the base currency
    if (currency.code != userPrefs.baseCurrencyCode) {
      showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          return Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text('Remove ${currency.name}'),
                onTap: () async {
                  Navigator.pop(context); // Close the bottom sheet
                  
                  // Remove the currency
                  userPrefs.removeCurrency(currency.code);
                  
                  // Show ad occasionally after removing a currency
                  _adService.showInterstitialAdIfNotPremium(userPrefs.isPremium);
                  
                  // Show success message
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${currency.name} removed'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    }
  }

  void _ensureExchangeRatesLoaded() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
      final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
      
      // FIXED: Get the base currency from user preferences
      final baseCurrency = userPrefs.baseCurrencyCode;
      
      // First, ensure the base currency is loaded and at the top
      print('📌 HomeScreen: Ensuring base currency is loaded');
      print('📌 Using user preference base currency: $baseCurrency');
      
      // Set the base currency in the provider first
      if (baseCurrency.isNotEmpty && currencyProvider.baseCurrencyCode != baseCurrency) {
        print('📌 Updating base currency in provider to: $baseCurrency');
        await currencyProvider.setBaseCurrency(baseCurrency);
      }
      
      // Now ensure it's loaded
      await currencyProvider.ensureBaseCurrencyIsLoaded();
      
      // Check if exchange rates are available
      if (currencyProvider.exchangeRates == null || 
          currencyProvider.exchangeRates!.rates.isEmpty) {
        print('⚠️ No exchange rates available on startup - forcing load');
        
        // Try to fetch exchange rates silently
        try {
          await currencyProvider.fetchExchangeRates();
          print('✅ Successfully loaded exchange rates on startup');
        } catch (e) {
          print('❌ Error loading exchange rates on startup: $e');
          // Show a snackbar if rates couldn't be loaded
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Please refresh exchange rates to update values'),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Refresh',
                  onPressed: () {
                    _handleRefresh();
                  },
                ),
              ),
            );
          }
        }
      } else {
        print('✅ Exchange rates already available on startup');
      }
    });
  }

  // Handle currency refresh button press
  Future<void> _handleRefresh() async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Try to refresh rates
      final result = await currencyProvider.tryRefreshRates();
      
      if (result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Exchange rates updated successfully'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          if (result.limitReached) {
            // Free users hit their limit
            _showRefreshLimitDialog();
          } else {
            // Generic error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.errorMessage ?? 'Failed to update exchange rates'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error refreshing rates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // Show dialog when free user hits refresh limit
  void _showRefreshLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh Limit Reached'),
        content: const Text(
          'Free users can refresh exchange rates once per day. Upgrade to premium for unlimited refreshes!'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to premium screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isOffline = currencyProvider.isOffline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Debug print to check if lastRatesRefresh is available
    if (currencyProvider.userPreferences?.lastRatesRefresh != null) {
      print('🕒 Last refresh timestamp: ${currencyProvider.userPreferences!.lastRatesRefresh}');
    } else {
      print('🕒 No last refresh timestamp available');
    }
    
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        // Prevent keyboard from pushing up the content
        resizeToAvoidBottomInset: false,
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
            // Refresh button with timestamp
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currencyProvider.userPreferences?.lastRatesRefresh != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Last refresh',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                            ),
                          ),
                          Text(
                            DateFormat('dd.MM HH:mm').format(currencyProvider.userPreferences!.lastRatesRefresh!),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Add a small gap
                const SizedBox(width: 4),
                // Refresh button
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: _isRefreshing 
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _isRefreshing ? null : _refreshRates,
                ),
              ],
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
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.background,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Flag column
                        const SizedBox(width: 36),
                        const SizedBox(width: 16),
                        // Currency code column
                        SizedBox(
                          width: 55,
                          child: Text(
                            'Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Currency name column
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Currency',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        // Value column
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Value',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Currency list with "Add Currency" button
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
                      : Column(
                          children: [
                            Expanded(
                              child: ReorderableListView.builder(
                                buildDefaultDragHandles: false, // Disable default drag handles
                                itemCount: currencyProvider.selectedCurrencies.length + 1,
                                padding: EdgeInsets.zero,
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (BuildContext context, Widget? child) {
                                      final double animValue = Curves.easeInOut.transform(animation.value);
                                      final double elevation = lerpDouble(0, 6, animValue)!;
                                      return Material(
                                        elevation: elevation,
                                        color: Theme.of(context).colorScheme.surface,
                                        shadowColor: Theme.of(context).shadowColor.withOpacity(0.1),
                                        child: child,
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  // Additional debugging
                                  print('🔍 REORDER: oldIndex=$oldIndex, newIndex=$newIndex');
                                  print('🔍 Before reordering:');
                                  print('🔍   Selected currencies: ${currencyProvider.selectedCurrencies.map((c) => c.code).join(", ")}');
                                  print('🔍   Base currency: ${userPrefs.baseCurrencyCode}');
                                  print('🔍   Current display indices: oldIndex=$oldIndex, newIndex=$newIndex, max=${currencyProvider.selectedCurrencies.length}');
                                  
                                  // Handle "Add Currency" button which is always at the end
                                  if (oldIndex == currencyProvider.selectedCurrencies.length || 
                                      newIndex == currencyProvider.selectedCurrencies.length) {
                                    print('⚠️ Cannot reorder the "Add Currency" button');
                                    return;
                                  }

                                  final currencies = currencyProvider.selectedCurrencies;
                                  
                                  // Always keep base currency at index 0 (disallow moving it or replacing it)
                                  if (oldIndex == 0 || newIndex == 0) {
                                    print('🔒 Base currency must stay at the top');
                                    return;
                                  }

                                  // Store current values before reordering
                                  final values = Map<String, double>.fromEntries(
                                    currencies.map((c) => MapEntry(c.code, c.value))
                                  );

                                  // Adjust indices for actual move
                                  final actualNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;

                                  // Create new order - MAKE SURE TO INCLUDE THE BASE CURRENCY
                                  final List<String> newOrder = currencies.map((c) => c.code).toList();
                                  print('🔍 Original order: ${newOrder.join(", ")}');
                                  
                                  final item = newOrder.removeAt(oldIndex);
                                  newOrder.insert(actualNewIndex, item);
                                  print('🔍 After reordering: ${newOrder.join(", ")}');
                                  
                                  // CRITICAL FIX: Ensure base currency is in the list and at position 0
                                  final baseCurrency = userPrefs.baseCurrencyCode;
                                  if (baseCurrency.isNotEmpty) {
                                    // Check if base currency is already in the list
                                    if (!newOrder.contains(baseCurrency)) {
                                      print('⚠️ CRITICAL: Base currency $baseCurrency is missing from list! Adding it.');
                                      newOrder.insert(0, baseCurrency);
                                    } else if (newOrder.indexOf(baseCurrency) != 0) {
                                      print('⚠️ Base currency not at first position! Moving it to the top.');
                                      // Remove base currency if it exists elsewhere in the list
                                      newOrder.remove(baseCurrency);
                                      // Insert it at the beginning
                                      newOrder.insert(0, baseCurrency);
                                    }
                                    print('📌 Ensured base currency $baseCurrency is at the top after reordering');
                                  }

                                  print('📝 Final currency order: ${newOrder.join(", ")}');
                                  
                                  // Update order in preferences and provider
                                  userPrefs.setInitialCurrencies(
                                    baseCurrency: userPrefs.baseCurrencyCode,
                                    selectedCurrencies: newOrder,
                                  );
                                  
                                  // Update the order in the provider while preserving values
                                  currencyProvider.selectCurrencies(newOrder, shouldRecalculate: false);
                                },
                                itemBuilder: (context, index) {
                                  // Debug the current state of currencies
                                  print('Building currency item at index $index. Total currencies: ${currencyProvider.selectedCurrencies.length}');
                                  print('Current currency codes: ${currencyProvider.selectedCurrencies.map((c) => c.code).join(", ")}');
                                  print('Base currency code: ${userPrefs.baseCurrencyCode}');
                                  
                                  // If this is the last index, show the add button
                                  if (index == currencyProvider.selectedCurrencies.length) {
                                    return Container(
                                      key: const ValueKey('add_currency_button'),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Theme.of(context).dividerColor.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: TextButton(
                                        onPressed: _showCurrenciesScreen,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                          alignment: Alignment.center,
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_rounded,
                                              size: 20,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Add Currency',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // Get the currency for this index
                                  final currency = currencyProvider.selectedCurrencies[index];
                                  final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                                  
                                  return Container(
                                    key: ValueKey('currency_${currency.code}_$index'),
                                    child: Row(
                                      children: [
                                        // Add a dedicated drag handle that only appears for non-base currencies
                                        if (!isBaseCurrency)
                                          ReorderableDragStartListener(
                                            index: index,
                                            child: Container(
                                              width: 40,
                                              height: 48, // Make sure height is defined
                                              color: Colors.transparent,
                                              child: Icon(
                                                Icons.drag_handle_rounded,
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                                size: 18,
                                              ),
                                            ),
                                          )
                                        else
                                          const SizedBox(width: 40),
                                        
                                        // The actual currency item takes up the rest of the space
                                        Expanded(
                                          child: CurrencyListItem(
                                            currency: currency,
                                            onValueChanged: _handleValueChange,
                                            isBaseCurrency: currencyProvider.baseCurrencyCode == currency.code,
                                            isEditing: currencyProvider.currentlyEditedCurrencyCode == currency.code,
                                            onEditStart: () => currencyProvider.setCurrentlyEditedCurrencyCode(currency.code),
                                            onEditEnd: () => currencyProvider.clearCurrentlyEditedCurrencyCode(),
                                            onTap: () => _handleCurrencyTap(currency),
                                            isSelected: false,
                                            showDragHandle: false,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdBannerWidget(isPremium: userPrefs.isPremium),
          ],
        ),
      ),
    );
  }
} 