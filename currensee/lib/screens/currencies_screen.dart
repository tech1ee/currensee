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
  bool _isSaving = false;
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
  
  void _initSelectedCurrencies() async {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Force reload preferences to ensure we have the latest data
    await userPrefs.reloadPreferences();
    
    if (!widget.isInitialSetup) {
      // Only load existing selections if not in initial setup
      setState(() {
        _selectedCurrencies = List.from(userPrefs.selectedCurrencyCodes);
        _baseCurrencyCode = userPrefs.baseCurrencyCode;
      });
    } else {
      // Start with empty selections in initial setup
      setState(() {
        _selectedCurrencies = [];
        _baseCurrencyCode = '';
      });
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
    print('Toggle currency: $currencyCode');
    
    // Check if this is the base currency
    if (currencyCode == _baseCurrencyCode && _selectedCurrencies.contains(currencyCode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove base currency')),
      );
      return;
    }
    
    // Show saving indicator
    setState(() {
      _isSaving = true;
    });
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    List<String> newSelectionList = List.from(_selectedCurrencies);
    
    if (newSelectionList.contains(currencyCode)) {
      // Don't allow removing the base currency
      if (currencyCode == _baseCurrencyCode) {
        setState(() {
          _isSaving = false;
        });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove base currency')),
          );
          return;
        }
        
      // Remove currency
      newSelectionList.remove(currencyCode);
      print('Removed currency: $currencyCode, selected: ${newSelectionList.join(", ")}');
    } else {
      // Add currency
      if (!userPrefs.isPremium && newSelectionList.length >= 5) {
        // Hide saving indicator
        setState(() {
          _isSaving = false;
        });
        // Show premium limit dialog
        showCurrencyLimitDialog(context);
        return;
      }
      
      // Add currency
      newSelectionList.add(currencyCode);
      print('Added currency: $currencyCode, selected: ${newSelectionList.join(", ")}');
    }
    
    // Update the base currency if it was removed
    String newBaseCurrency = _baseCurrencyCode;
    if (newBaseCurrency == currencyCode && !newSelectionList.contains(currencyCode)) {
      // Base currency was removed, use first available currency
      if (newSelectionList.isNotEmpty) {
        newBaseCurrency = newSelectionList.first;
        print('Base currency was removed, new base: $newBaseCurrency');
      } else {
        newBaseCurrency = '';
        print('No currencies selected, base currency cleared');
      }
    } else if (newBaseCurrency.isEmpty && newSelectionList.isNotEmpty) {
      // No base currency but we have selected currencies
      newBaseCurrency = newSelectionList.first;
      print('No base currency set, using first selected: $newBaseCurrency');
    }
    
    // Update state with new selections
    setState(() {
      _selectedCurrencies = newSelectionList;
      _baseCurrencyCode = newBaseCurrency;
      _hasChanges = true;
    });
    
    try {
      // Step 1: Set the base currency first if needed
      if (userPrefs.baseCurrencyCode != newBaseCurrency) {
        print('Updating base currency to $newBaseCurrency');
        await userPrefs.setBaseCurrency(newBaseCurrency);
        currencyProvider.setBaseCurrency(newBaseCurrency);
      }
      
      // Step 2: Update the selected currencies in user preferences
      print('Updating selected currencies to: ${newSelectionList.join(", ")}');
      await userPrefs.setInitialCurrencies(
        baseCurrency: newBaseCurrency,
        selectedCurrencies: newSelectionList,
      );
      
      // Step 3: Force the currency provider to reload the selected currencies
      print('Reloading selected currencies in provider');
      await currencyProvider.selectCurrencies(newSelectionList);
      
      // Step 4: Force storage synchronization by reloading preferences
      print('Forcing preference reload to ensure persistence');
      await userPrefs.reloadPreferences();
      
      print('Currency selection changes successfully synchronized and saved');
    } catch (e) {
      print('Error updating currency selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update selection: $e')),
      );
    } finally {
      // Hide saving indicator if the widget is still mounted
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
  
  // Method to set a currency as the base currency
  void _setBaseCurrency(String currencyCode) async {
    print('Setting base currency: $currencyCode');
    
    // Show saving indicator
    setState(() {
      _isSaving = true;
    });
    
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
    
    // Copy the selection list to avoid modification issues
    List<String> updatedSelections = List.from(_selectedCurrencies);
    
    // Make sure the currency is in the selected list
    if (!updatedSelections.contains(currencyCode)) {
      updatedSelections.add(currencyCode);
      print('Added new base currency to selections: $currencyCode');
    }
    
    // Update state
    setState(() {
      _selectedCurrencies = updatedSelections;
      _baseCurrencyCode = currencyCode;
      _hasChanges = true;
    });
    
    try {
      // First update the base currency specifically
      await userPrefs.setBaseCurrency(currencyCode);
      print('Base currency updated in UserPreferences: $currencyCode');
      
      // Then update the full selection
      await userPrefs.setInitialCurrencies(
        baseCurrency: currencyCode, 
        selectedCurrencies: updatedSelections
      );
      
      // Update the currency provider
      currencyProvider.setBaseCurrency(currencyCode);
      
      // Reload all selected currencies with updated order
      await currencyProvider.selectCurrencies(updatedSelections);
      print('Successfully updated base currency: $currencyCode and selections: ${updatedSelections.join(", ")}');
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$currencyCode set as base currency'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error setting base currency: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set base currency: $e')),
        );
      }
    } finally {
      // Hide saving indicator if the widget is still mounted
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
      print('Saving changes: Base=${_baseCurrencyCode}, Selected=${_selectedCurrencies.join(", ")}');
      
      // Save base currency first if it changed
      if (_baseCurrencyCode != userPrefs.baseCurrencyCode) {
        await userPrefs.setBaseCurrency(_baseCurrencyCode);
      }
      
      // Save selected currencies
      await userPrefs.setInitialCurrencies(
        baseCurrency: _baseCurrencyCode,
        selectedCurrencies: _selectedCurrencies,
      );
      
      // Flag changes as saved
      setState(() {
        _hasChanges = false;
      });
      
      // Mark setup as complete if in initial setup mode
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
          // Just pop back to the previous screen
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Error saving currency changes: $e');
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
        
        // Auto-save if there are unsaved changes
        if (_hasChanges) {
          // Ensure we have at least one currency selected
          if (_selectedCurrencies.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select at least one currency')),
            );
            return false;
          }
          
          // If no base currency is set but we have currencies, use the first one as base
          if (_baseCurrencyCode.isEmpty && _selectedCurrencies.isNotEmpty) {
            _baseCurrencyCode = _selectedCurrencies.first;
          }
          
          try {
            final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
            final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
            
            setState(() {
              _isSaving = true;
            });
            
            // Save selected currencies and base currency
            print('Auto-saving changes on back button press: Base=${_baseCurrencyCode}, Selected=${_selectedCurrencies.join(", ")}');
            
            // Step 1: Set the base currency first if needed
            if (userPrefs.baseCurrencyCode != _baseCurrencyCode) {
              print('Updating base currency to $_baseCurrencyCode');
              await userPrefs.setBaseCurrency(_baseCurrencyCode);
              currencyProvider.setBaseCurrency(_baseCurrencyCode);
            }
            
            // Step 2: Update the selected currencies in user preferences
            await userPrefs.setInitialCurrencies(
              baseCurrency: _baseCurrencyCode,
              selectedCurrencies: _selectedCurrencies,
            );
            
            // Step 3: Force the currency provider to reload the selected currencies
            await currencyProvider.selectCurrencies(_selectedCurrencies);
            
            // Step 4: Force storage synchronization by reloading preferences
            await userPrefs.reloadPreferences();
            
            setState(() {
              _isSaving = false;
            });
            
            print('Changes successfully saved through Android back button');
          } catch (e) {
            print('Error auto-saving changes: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to save changes: $e')),
              );
            }
          }
        }
        
        // Confirm back navigation is allowed
        final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
        
        // If in initial setup but setup is complete, go to home screen instead
        if (!widget.isInitialSetup || userPrefs.hasCompletedInitialSetup) {
          return true; // Allow regular back navigation
        } else {
          // This should rarely happen - but just in case, navigate to home screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
          return false; // Don't perform default back action since we're handling navigation
        }
      },
      child: Scaffold(
      appBar: AppBar(
          title: Text(widget.isInitialSetup ? 'Select Currencies' : 'Currencies'),
          leading: widget.isInitialSetup ? null : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // Force save changes if any exist before navigating back
              if (_hasChanges) {
                // Ensure at least one currency is selected
                if (_selectedCurrencies.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select at least one currency')),
                  );
                  return;
                }
                
                // If no base currency is set but we have currencies, use the first one as base
                if (_baseCurrencyCode.isEmpty && _selectedCurrencies.isNotEmpty) {
                  _baseCurrencyCode = _selectedCurrencies.first;
                }
                
                try {
                  final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
                  final currencyProvider = Provider.of<CurrencyProvider>(context, listen: false);
                  
                  setState(() {
                    _isSaving = true;
                  });
                  
                  print('Saving changes via back button: Base=${_baseCurrencyCode}, Selected=${_selectedCurrencies.join(", ")}');
                  
                  // Step 1: Set the base currency first if needed
                  if (userPrefs.baseCurrencyCode != _baseCurrencyCode) {
                    print('Updating base currency to $_baseCurrencyCode');
                    await userPrefs.setBaseCurrency(_baseCurrencyCode);
                    currencyProvider.setBaseCurrency(_baseCurrencyCode);
                  }
                  
                  // Step 2: Update the selected currencies in user preferences
                  print('Updating selected currencies via back button');
                  await userPrefs.setInitialCurrencies(
                    baseCurrency: _baseCurrencyCode,
                    selectedCurrencies: _selectedCurrencies,
                  );
                  
                  // Step 3: Force the currency provider to reload the selected currencies
                  print('Reloading selected currencies in provider');
                  await currencyProvider.selectCurrencies(_selectedCurrencies);
                  
                  // Step 4: Force storage synchronization by reloading preferences
                  print('Forcing preference reload to ensure persistence');
                  await userPrefs.reloadPreferences();
                  
                  setState(() {
                    _isSaving = false;
                  });
                  
                  print('Changes successfully saved through back button');
                } catch (e) {
                  print('Error saving changes via back button: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save changes: $e')),
                  );
                  return;
                }
              }
              
              // If in initial setup mode and user manually added a back button,
              // navigate to HomeScreen to prevent going back to setup
              if (userPrefs.hasCompletedInitialSetup) {
                Navigator.of(context).pop();
              } else {
                // If we somehow get here during initial setup but with the back button,
                // go to HomeScreen and clear navigation stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              }
            },
          ),
          actions: [
            // Add a saving indicator in the app bar
            if (_isSaving)
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
                key: PageStorageKey('currency_list'), // Add key to preserve scroll position
                itemCount: selectedCurrencies.length + unselectedCurrencies.length,
                        itemBuilder: (context, index) {
                  // Create a copy of the selected currencies list to avoid modifying the original during build
                  List<dynamic> displaySelectedCurrencies = List.from(selectedCurrencies);
                  
                  // Move base currency to top if it exists
                  final baseIndex = displaySelectedCurrencies.indexWhere((c) => c.code == _baseCurrencyCode);
                  if (baseIndex != -1) {
                    // Reorder the list to put base currency first
                    final baseCurrency = displaySelectedCurrencies.removeAt(baseIndex);
                    displaySelectedCurrencies.insert(0, baseCurrency);
                  }

                  // Show selected currencies first (with base currency at top)
                  if (index < displaySelectedCurrencies.length) {
                    return _buildCurrencyTile(displaySelectedCurrencies[index], true);
                  }

                  // Then show unselected currencies
                  final unselectedIndex = index - displaySelectedCurrencies.length;
                  if (unselectedIndex < unselectedCurrencies.length) {
                    return _buildCurrencyTile(unselectedCurrencies[unselectedIndex], false);
                  }
                  
                  // Safety check - return empty container if index is out of bounds
                  return Container(key: ValueKey('empty_$index'));
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: widget.isInitialSetup
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton(
                    onPressed: _selectedCurrencies.isEmpty 
                        ? null 
                        : () {
                            if (_baseCurrencyCode.isEmpty && _selectedCurrencies.isNotEmpty) {
                              // If no base currency is set during initial setup, use the first one
                              setState(() {
                                _baseCurrencyCode = _selectedCurrencies.first;
                              });
                            }
                            _saveChangesAndContinue();
                          },
                    child: const Text('Continue'),
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
              key: ValueKey('checkbox_${currency.code}'),
              value: isSelected,
              onChanged: (bool? value) {
                print('Checkbox clicked for ${currency.code} with value: $value');
                print('Current selection state before toggle: $isSelected');
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