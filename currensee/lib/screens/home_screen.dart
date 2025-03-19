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

// Create a custom method channel for iOS keyboard control
const MethodChannel _keyboardChannel = MethodChannel('com.currensee.app/keyboard');

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AdService _adService = AdService();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _adService.loadInterstitialAd(); // Preload interstitial ad
    
    // Schedule loading after build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSelectedCurrencies();
      await _handleAutoRefresh();
    });
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

  Future<void> _loadSelectedCurrencies() async {
    if (!mounted) return;
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    if (userPrefs.selectedCurrencyCodes.isNotEmpty) {
      await currencyProvider.reloadSelectedCurrencies(userPrefs.selectedCurrencyCodes);
    }
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

  void _handleCurrencyValueChanged(String code, double value) {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    currencyProvider.updateCurrencyValue(code, value);
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_rounded),
              title: const Text('Remove Currency'),
              onTap: () {
                Navigator.pop(context);
                _removeCurrency(currency.code);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _removeCurrency(String currencyCode) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Remove from selected currencies
    final updatedCurrencies = List<String>.from(userPrefs.selectedCurrencyCodes)
      ..remove(currencyCode);
    
    userPrefs.setInitialCurrencies(
      baseCurrency: userPrefs.baseCurrencyCode,
      selectedCurrencies: updatedCurrencies,
    );
    
    currencyProvider.selectCurrencies(updatedCurrencies);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$currencyCode removed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final isOffline = currencyProvider.isOffline;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
                    padding: const EdgeInsets.only(right: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('dd.MM').format(currencyProvider.userPreferences!.lastRatesRefresh!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4),
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(currencyProvider.userPreferences!.lastRatesRefresh!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                          width: 60,
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
                          flex: 2,
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
                        SizedBox(
                          width: 120,
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
                                  // Don't allow reordering the "Add Currency" button
                                  if (oldIndex >= currencyProvider.selectedCurrencies.length ||
                                      newIndex > currencyProvider.selectedCurrencies.length) {
                                    return;
                                  }

                                  // Adjust indices
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }

                                  // Get current order
                                  final currencies = currencyProvider.selectedCurrencies;
                                  
                                  // Don't allow moving the base currency
                                  if (currencies[oldIndex].code == userPrefs.baseCurrencyCode) {
                                    return;
                                  }

                                  // Create new order
                                  final List<String> newOrder = currencies.map((c) => c.code).toList();
                                  final item = newOrder.removeAt(oldIndex);
                                  newOrder.insert(newIndex, item);

                                  // Update order in preferences and provider
                                  userPrefs.setInitialCurrencies(
                                    baseCurrency: userPrefs.baseCurrencyCode,
                                    selectedCurrencies: newOrder,
                                  );
                                  currencyProvider.selectCurrencies(newOrder);
                                },
                                itemBuilder: (context, index) {
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

                                  // Get the sorted currencies with base currency at the top
                                  final currencies = List.of(currencyProvider.selectedCurrencies);
                                  final baseIndex = currencies.indexWhere((c) => c.code == userPrefs.baseCurrencyCode);
                                  if (baseIndex > 0) {
                                    final baseCurrency = currencies.removeAt(baseIndex);
                                    currencies.insert(0, baseCurrency);
                                  }
                                  
                                  final currency = currencies[index];
                                  final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                                  
                                  return ReorderableDragStartListener(
                                    key: ValueKey('draggable_${currency.code}'),
                                    index: index,
                                    enabled: !isBaseCurrency,
                                    child: CurrencyListItem(
                                      currency: currency,
                                      onValueChanged: (code, value) => currencyProvider.updateCurrencyValue(code, value),
                                      isBaseCurrency: isBaseCurrency,
                                      isEditing: currencyProvider.currentlyEditedCurrencyCode == currency.code,
                                      onEditStart: () => currencyProvider.setCurrentlyEditedCurrencyCode(currency.code),
                                      onEditEnd: () => currencyProvider.clearCurrentlyEditedCurrencyCode(),
                                      index: index,
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
            // Banner ad at the bottom for free users
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: AdBannerWidget(isPremium: userPrefs.isPremium),
            ),
          ],
        ),
      ),
    );
  }
} 