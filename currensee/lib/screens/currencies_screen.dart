import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../providers/currency_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/currency_limit_dialog.dart';
import '../widgets/currency_flag_placeholder.dart';
import 'home_screen.dart';

class CurrenciesScreen extends StatefulWidget {
  final bool isInitialSetup;
  
  const CurrenciesScreen({
    Key? key,
    this.isInitialSetup = false,
  }) : super(key: key);

  @override
  State<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends State<CurrenciesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _hasChanges = false;
  List<String> _selectedCurrencies = [];
  String _baseCurrencyCode = '';

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
    if (!widget.isInitialSetup) {
      // Only load existing selections if not in initial setup
      _selectedCurrencies = List.from(userPrefs.selectedCurrencyCodes);
      _baseCurrencyCode = userPrefs.baseCurrencyCode;
    } else {
      // Start with empty selections in initial setup
      _selectedCurrencies = [];
      _baseCurrencyCode = '';
    }
    
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
      setState(() {
        _selectedCurrencies.remove(currencyCode);
        _hasChanges = true;
      });
    } else {
      // Add currency
      if (!userPrefs.isPremium && _selectedCurrencies.length >= 5) {
        // Show premium limit dialog
        showCurrencyLimitDialog(context);
        return;
      }
      
      setState(() {
        _selectedCurrencies.add(currencyCode);
        _hasChanges = true;
      });
    }
  }
  
  // Method to set a currency as the base currency
  void _setBaseCurrency(String currencyCode) {
    // Make sure the currency is in the selected list
    if (!_selectedCurrencies.contains(currencyCode)) {
      setState(() {
        _selectedCurrencies.add(currencyCode);
        _baseCurrencyCode = currencyCode;
        _hasChanges = true;
      });
    } else {
      setState(() {
        _baseCurrencyCode = currencyCode;
        _hasChanges = true;
      });
    }
    
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

  Future<void> _saveChangesAndContinue() async {
    if (_selectedCurrencies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one currency')),
      );
      return;
    }

    if (_baseCurrencyCode.isEmpty && _selectedCurrencies.isNotEmpty) {
      // If no base currency is set, ask user to select one
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a base currency by tapping the star icon')),
      );
      return;
    }

    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);

    try {
      // Save changes
      await userPrefs.setInitialCurrencies(
        baseCurrency: _baseCurrencyCode,
        selectedCurrencies: _selectedCurrencies,
      );
      
      // Update currency provider
      await currencyProvider.reloadSelectedCurrencies(_selectedCurrencies);

      // Mark setup as complete
      if (widget.isInitialSetup) {
        await userPrefs.completeInitialSetup();
      }

      if (mounted) {
        if (widget.isInitialSetup) {
          // Navigate to home screen and remove all previous routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save changes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final allCurrencies = currencyProvider.allCurrencies;
    
    // Filter currencies based on search query
    final filteredCurrencies = _searchQuery.isEmpty
        ? allCurrencies
        : allCurrencies.where((currency) =>
            currency.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            currency.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    
    // Split currencies into selected and unselected
    final selectedCurrencies = filteredCurrencies
        .where((c) => _selectedCurrencies.contains(c.code))
        .toList();
    final unselectedCurrencies = filteredCurrencies
        .where((c) => !_selectedCurrencies.contains(c.code))
        .toList();

    return WillPopScope(
      onWillPop: () async {
        // If in initial setup, require at least one currency to be selected
        if (widget.isInitialSetup) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select currencies and tap Continue')),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isInitialSetup ? 'Select Currencies' : 'Currencies'),
          leading: widget.isInitialSetup ? null : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            if (widget.isInitialSetup)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select the currencies you want to convert between. You can add more later.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  textInputAction: TextInputAction.search,
                  keyboardType: TextInputType.text,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search currencies',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            
            // Selected count
            if (_selectedCurrencies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected: ${_selectedCurrencies.length}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (!userPrefs.isPremium)
                      Text(
                        '${_selectedCurrencies.length}/5',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            
            // Currency list
            Expanded(
              child: ListView.builder(
                itemCount: selectedCurrencies.length + unselectedCurrencies.length,
                itemBuilder: (context, index) {
                  // Move base currency to top if it exists
                  final baseIndex = selectedCurrencies.indexWhere((c) => c.code == _baseCurrencyCode);
                  if (baseIndex != -1) {
                    // Reorder the list to put base currency first
                    final baseCurrency = selectedCurrencies.removeAt(baseIndex);
                    selectedCurrencies.insert(0, baseCurrency);
                  }

                  // Show selected currencies first (with base currency at top)
                  if (index < selectedCurrencies.length) {
                    return _buildCurrencyTile(selectedCurrencies[index], true);
                  }

                  // Then show unselected currencies
                  final unselectedIndex = index - selectedCurrencies.length;
                  return _buildCurrencyTile(unselectedCurrencies[unselectedIndex], false);
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.isInitialSetup || _hasChanges
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton(
                    onPressed: _selectedCurrencies.isEmpty ? null : _saveChangesAndContinue,
                    child: Text(widget.isInitialSetup ? 'Continue' : 'Save Changes'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildCurrencyTile(dynamic currency, bool isSelected) {
    return ListTile(
      leading: SizedBox(
        width: 36,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            currency.flagUrl,
            width: 36,
            height: 24,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => CurrencyFlagPlaceholder(
              size: 36,
              currencyCode: currency.code,
            ),
          ),
        ),
      ),
      title: Text(
        currency.code,
        style: TextStyle(
          fontWeight: currency.code == _baseCurrencyCode ? FontWeight.w700 : FontWeight.w600,
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
              value: isSelected,
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
      tileColor: currency.code == _baseCurrencyCode ? const Color(0xFF8FD584).withOpacity(0.1) : null,
    );
  }
} 