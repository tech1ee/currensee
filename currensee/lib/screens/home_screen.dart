import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/currency_list_item.dart';
import '../widgets/ad_banner.dart';
import 'currencies_screen.dart';
import 'settings_screen.dart';
import '../services/ad_service.dart';

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

  Future<void> _refreshRates() async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      await Provider.of<CurrencyProvider>(context, listen: false).fetchExchangeRates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update rates: $e')),
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
            child: RefreshIndicator(
              onRefresh: _refreshRates,
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
                  : ListView.builder(
                      itemCount: currencyProvider.selectedCurrencies.length,
                      padding: const EdgeInsets.only(bottom: 16, top: 8),
                      itemBuilder: (context, index) {
                        final currency = currencyProvider.selectedCurrencies[index];
                        final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                        
                        return CurrencyListItem(
                          currency: currency,
                          isBaseCurrency: isBaseCurrency,
                          onValueChanged: (code, value) {
                            currencyProvider.updateCurrencyValue(code, value);
                          },
                          onLongPress: () {
                            // Handle long press if needed
                          },
                          onSetAsBase: () {
                            _setBaseCurrency(currency.code);
                          },
                          index: index,
                        );
                      },
                    ),
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