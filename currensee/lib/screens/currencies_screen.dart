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
  bool _hasChanges = false;
  List<String> _selectedCurrencies = [];
  String _baseCurrencyCode = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    _initSelectedCurrencies();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _initSelectedCurrencies() {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    _selectedCurrencies = List.from(userPrefs.selectedCurrencyCodes);
    _baseCurrencyCode = userPrefs.baseCurrencyCode;
    
    print('Loaded currencies from preferences: Base=${_baseCurrencyCode}, Selected=${_selectedCurrencies.join(", ")}');
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
    // Check if this is the base currency
    if (currencyCode == _baseCurrencyCode && _selectedCurrencies.contains(currencyCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove base currency')),
      );
      return;
    }
    
    setState(() {
      if (_selectedCurrencies.contains(currencyCode)) {
        // Remove currency
        _selectedCurrencies.remove(currencyCode);
      } else {
        // Add currency
        final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
        if (!userPrefs.isPremium && _selectedCurrencies.length >= 5) {
          // Show premium limit dialog
          showCurrencyLimitDialog(context);
          return;
        }
        
        _selectedCurrencies.add(currencyCode);
      }
      _hasChanges = true;
    });
  }
  
  // Method to set a currency as the base currency
  void _setBaseCurrency(String currencyCode) {
    setState(() {
      // Make sure the currency is in the selected list
      if (!_selectedCurrencies.contains(currencyCode)) {
        _selectedCurrencies.add(currencyCode);
      }
      
      _baseCurrencyCode = currencyCode;
      _hasChanges = true;
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$currencyCode set as base currency')),
    );
  }
  
  void _saveChanges() async {
    if (!_hasChanges) {
      print('No changes to save, returning to previous screen');
      Navigator.pop(context);
      return;
    }
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('Saving currencies: Base=${_baseCurrencyCode}, Selected=${_selectedCurrencies.join(", ")}');
      
      // Set currencies in storage
      await userPrefs.setInitialCurrencies(
        baseCurrency: _baseCurrencyCode,
        selectedCurrencies: _selectedCurrencies,
      );
      
      // Update the currency provider
      currencyProvider.selectCurrencies(_selectedCurrencies);
      currencyProvider.setBaseCurrency(_baseCurrencyCode);
      
      print('Successfully saved currency preferences');
      
      // Return to home screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving currency preferences: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
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
    
    // Split currencies into selected and unselected
    final selectedCurrencies = filteredCurrencies
        .where((currency) => _selectedCurrencies.contains(currency.code))
        .toList();
    
    final unselectedCurrencies = filteredCurrencies
        .where((currency) => !_selectedCurrencies.contains(currency.code))
        .toList();
    
    return WillPopScope(
      onWillPop: () async {
        // If there are changes, save them or confirm discard
        if (_hasChanges) {
          // Ask the user if they want to save changes before leaving
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Save changes?'),
              content: const Text('You have unsaved changes. Do you want to save them before leaving?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false); // Don't save, just leave
                  },
                  child: const Text('Discard'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // Save and leave
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          
          // If user clicked "Save", or the dialog was dismissed, save changes
          if (result == true) {
            _saveChanges();
            return false; // Don't pop here, _saveChanges will handle navigation
          }
          
          // If user clicked "Discard", allow the screen to be popped
          return true;
        }
        
        // No changes, allow the screen to be popped
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Currencies'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton(
                onPressed: _saveChanges,
                style: ButtonStyle(
                  foregroundColor: MaterialStateProperty.all(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                  textStyle: MaterialStateProperty.all(
                    const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  padding: MaterialStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                child: const Text('SAVE'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search currencies',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
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
            
            // Selected Count
            if (_selectedCurrencies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      'Selected: ${_selectedCurrencies.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (!userPrefs.isPremium)
                      Text(
                        '(max 5 for free users)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                  ],
                ),
              ),
            
            // Loading indicator or currency list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredCurrencies.isEmpty
                      ? const Center(child: Text('No currencies found'))
                      : ListView(
                          children: [
                            // Show selected currencies section if there are any selected currencies in search results
                            if (selectedCurrencies.isNotEmpty) ...[
                              // Divider between selected count and list
                              const Divider(),
                              ...selectedCurrencies.map((currency) => _buildCurrencyTile(
                                currency: currency,
                                isSelected: true, 
                                isBaseCurrency: currency.code == _baseCurrencyCode
                              )),
                            ],
                            
                            // Show unselected currencies
                            if (unselectedCurrencies.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                child: Row(
                                  children: [
                                    Text(
                                      'Available Currencies',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        '${unselectedCurrencies.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              ...unselectedCurrencies.map((currency) => _buildCurrencyTile(
                                currency: currency,
                                isSelected: false, 
                                isBaseCurrency: false
                              )),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build currency tile
  Widget _buildCurrencyTile({
    required dynamic currency, 
    required bool isSelected, 
    required bool isBaseCurrency
  }) {
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
          ? SizedBox(
              width: 80, // Fixed width to ensure alignment
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Star icon with consistent position
                  Container(
                    width: 40,
                    alignment: Alignment.center,
                    child: isBaseCurrency
                      ? const Icon(Icons.star, color: Colors.amber)
                      : IconButton(
                          icon: const Icon(Icons.star_outline),
                          padding: EdgeInsets.zero,
                          iconSize: 24,
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Set as base currency',
                          onPressed: () => _setBaseCurrency(currency.code),
                        ),
                  ),
                  // Checkmark with consistent position
                  Container(
                    width: 24,
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, color: Colors.green),
                  ),
                ],
              ),
            )
          : null,
      onTap: () => _toggleCurrency(currency.code),
    );
  }
} 