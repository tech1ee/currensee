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
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    if (_selectedCurrencies.contains(currencyCode)) {
      // Remove currency
      _selectedCurrencies.remove(currencyCode);
      // Save changes immediately
      await userPrefs.setInitialCurrencies(
        baseCurrency: _baseCurrencyCode,
        selectedCurrencies: _selectedCurrencies.toList(),
      );
    } else {
      // Add currency
      if (!userPrefs.isPremium && _selectedCurrencies.length >= 5) {
        // Show premium limit dialog
        showCurrencyLimitDialog(context);
        return;
      }
      
      _selectedCurrencies.add(currencyCode);
      // Save changes immediately
      await userPrefs.setInitialCurrencies(
        baseCurrency: _baseCurrencyCode,
        selectedCurrencies: _selectedCurrencies.toList(),
      );
    }
    
    setState(() {});
  }
  
  // Method to set a currency as the base currency
  void _setBaseCurrency(String currencyCode) async {
    // Make sure the currency is in the selected list
    if (!_selectedCurrencies.contains(currencyCode)) {
      _selectedCurrencies.add(currencyCode);
    }
    
    _baseCurrencyCode = currencyCode;
    
    // Save changes immediately
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Update storage
    await userPrefs.setInitialCurrencies(
      baseCurrency: _baseCurrencyCode,
      selectedCurrencies: _selectedCurrencies.toList(),
    );
    
    // Update currency provider
    currencyProvider.setBaseCurrency(_baseCurrencyCode);
    currencyProvider.selectCurrencies(_selectedCurrencies);
    
    setState(() {});
    
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$currencyCode set as base currency'),
          duration: const Duration(seconds: 1),
        ),
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
        // Just return true to allow popping without showing save dialog
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Currencies'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            // Search field
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search currencies',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF8FD584),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF8FD584),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF8FD584),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            
            // Selected count
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
            
            // Currency list
            Expanded(
              child: ListView(
                children: [
                  // Selected currencies section
                  if (selectedCurrencies.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Selected Currencies',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...selectedCurrencies.map((currency) => ListTile(
                      leading: SizedBox(
                        width: 36,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            currency.flagUrl,
                            width: 36,
                            height: 24,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.flag, color: Colors.grey),
                          ),
                        ),
                      ),
                      title: Text(
                        currency.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(currency.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Star container with fixed width
                          SizedBox(
                            width: 40,
                            child: currency.code == _baseCurrencyCode
                              ? const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFF8FD584),
                                  size: 28,
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.star_outline_rounded,
                                    size: 28,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _setBaseCurrency(currency.code),
                                  tooltip: 'Set as base currency',
                                ),
                          ),
                          // Checkbox with consistent spacing
                          Transform.scale(
                            scale: 1.2,
                            child: Checkbox(
                              value: true,
                              onChanged: (bool? value) {
                                _toggleCurrency(currency.code);
                              },
                              activeColor: const Color(0xFF8FD584),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    
                    // Divider between sections
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Divider(),
                    ),
                  ],
                  
                  // Available currencies section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        const Text(
                          'Available Currencies',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${unselectedCurrencies.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...unselectedCurrencies.map((currency) => ListTile(
                    leading: SizedBox(
                      width: 36,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          currency.flagUrl,
                          width: 36,
                          height: 24,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.flag, color: Colors.grey),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(currency.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Empty space to match selected items layout
                        const SizedBox(width: 40),
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: false,
                            onChanged: (bool? value) {
                              _toggleCurrency(currency.code);
                            },
                            activeColor: const Color(0xFF8FD584),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 