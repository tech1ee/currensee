import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/currency_limit_dialog.dart';

class CurrenciesScreen extends StatefulWidget {
  const CurrenciesScreen({Key? key}) : super(key: key);

  @override
  State<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends State<CurrenciesScreen> {
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    if (currencyProvider.allCurrencies.isEmpty) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        await currencyProvider.loadAllCurrencies();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load currencies: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _toggleCurrency(String currencyCode) async {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    bool wasAdded = false;
    
    try {
      if (userPrefs.selectedCurrencyCodes.contains(currencyCode)) {
        // Remove currency
        if (currencyCode == userPrefs.baseCurrencyCode) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove base currency')),
          );
          return;
        }
        
        await userPrefs.removeCurrency(currencyCode);
      } else {
        // Add currency
        await userPrefs.addCurrency(currencyCode);
        wasAdded = true;
      }
      
      // Update the selected currencies in the currency provider
      currencyProvider.selectCurrencies(userPrefs.selectedCurrencyCodes);
      
      // If a currency was added, return to home screen to see it
      if (wasAdded) {
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      // Show currency limit dialog if that's the error
      if (e.toString().contains('Free users can only add up to 5 currencies')) {
        showCurrencyLimitDialog(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    
    // Filter currencies based on search query
    final filteredCurrencies = currencyProvider.allCurrencies
        .where((currency) => 
            currency.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            currency.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Currencies'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search currencies',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Loading indicator or currency list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCurrencies.isEmpty
                    ? const Center(child: Text('No currencies found'))
                    : ListView.builder(
                        itemCount: filteredCurrencies.length,
                        itemBuilder: (context, index) {
                          final currency = filteredCurrencies[index];
                          final isSelected = userPrefs.selectedCurrencyCodes
                              .contains(currency.code);
                          final isBaseCurrency = currency.code == userPrefs.baseCurrencyCode;
                          
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                currency.flagUrl,
                                width: 32,
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 32,
                                    height: 24,
                                    color: Colors.grey.shade300,
                                    child: Center(
                                      child: Text(
                                        currency.code.substring(0, 2),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            title: Text(
                              currency.code,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isBaseCurrency
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                            subtitle: Text(currency.name),
                            trailing: isSelected
                                ? isBaseCurrency
                                    ? const Icon(Icons.star, color: Colors.amber)
                                    : const Icon(Icons.check, color: Colors.green)
                                : null,
                            onTap: () => _toggleCurrency(currency.code),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 