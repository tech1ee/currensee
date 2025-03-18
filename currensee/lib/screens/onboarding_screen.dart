import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/currency.dart';
import '../providers/user_preferences_provider.dart';
import '../services/api_service.dart';
import '../widgets/currency_flag_placeholder.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final ApiService _apiService = ApiService();
  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  int _currentPage = 0;
  
  // Selected currencies
  String _selectedBaseCurrency = 'USD';
  final List<String> _selectedCurrencies = ['USD', 'EUR', 'GBP'];
  
  // All available currencies
  List<Currency> _allCurrencies = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCurrencies();
    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  Future<void> _loadCurrencies() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      _allCurrencies = await _apiService.fetchAvailableCurrencies();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading currencies: $e')),
        );
      }
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }
  
  void _nextPage() {
    if (_currentPage < 1) {
      // Clear search and request focus when moving to next page
      setState(() {
        _searchController.clear();
        _searchQuery = '';
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        _searchFocusNode.requestFocus();
      });
    } else {
      _completeOnboarding();
    }
  }
  
  void _previousPage() {
    // Clear search and request focus when moving to previous page
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _searchFocusNode.requestFocus();
    });
  }
  
  Future<void> _completeOnboarding() async {
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Save user currency preferences
    await userPrefs.setInitialCurrencies(
      baseCurrency: _selectedBaseCurrency,
      selectedCurrencies: _selectedCurrencies,
    );
    
    // Mark onboarding as complete
    await userPrefs.completeOnboarding();
    
    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
  
  void _toggleCurrency(Currency currency) {
    setState(() {
      final String code = currency.code;
      
      if (_selectedCurrencies.contains(code)) {
        // Don't allow removing base currency
        if (code == _selectedBaseCurrency) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot remove base currency')),
          );
          return;
        }
        
        // Don't allow removing all currencies
        if (_selectedCurrencies.length <= 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must select at least one currency')),
          );
          return;
        }
        
        _selectedCurrencies.remove(code);
      } else {
        // Limit to 5 currencies for free users
        if (_selectedCurrencies.length >= 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Free users can select up to 5 currencies')),
          );
          return;
        }
        
        _selectedCurrencies.add(code);
      }
    });
  }
  
  void _setBaseCurrency(Currency currency) {
    setState(() {
      _selectedBaseCurrency = currency.code;
      
      // Ensure base currency is in selected currencies
      if (!_selectedCurrencies.contains(currency.code)) {
        _selectedCurrencies.add(currency.code);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        _buildBaseCurrencyPage(),
                        _buildSelectCurrenciesPage(),
                      ],
                    ),
                  ),
                  _buildBottomControls(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildBaseCurrencyPage() {
    // Filter currencies based on search query
    final filteredCurrencies = _searchQuery.isEmpty
        ? _allCurrencies
        : _allCurrencies.where((currency) =>
            currency.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            currency.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Select your base currency',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This will be the currency used for all conversions',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Search field
          Container(
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
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: filteredCurrencies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final currency = filteredCurrencies[index];
                final isSelected = currency.code == _selectedBaseCurrency;
                
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: SizedBox(
                      width: 44,
                      height: 44,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          currency.flagUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return CurrencyFlagPlaceholder(
                              size: 44,
                              currencyCode: currency.code,
                            );
                          },
                          errorBuilder: (_, __, ___) => CurrencyFlagPlaceholder(
                            size: 44,
                            currencyCode: currency.code,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      currency.code,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => _setBaseCurrency(currency),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectCurrenciesPage() {
    // Filter currencies based on search query
    final filteredCurrencies = _searchQuery.isEmpty
        ? _allCurrencies
        : _allCurrencies.where((currency) =>
            currency.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            currency.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Select currencies to track',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose up to 5 currencies to track (free tier)',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          // Search field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
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
          const SizedBox(height: 16),
          // Selected count
          Text(
            'Selected: ${_selectedCurrencies.length}/5',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filteredCurrencies.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final currency = filteredCurrencies[index];
                final isSelected = _selectedCurrencies.contains(currency.code);
                
                return Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: SizedBox(
                      width: 44,
                      height: 44,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          currency.flagUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return CurrencyFlagPlaceholder(
                              size: 44,
                              currencyCode: currency.code,
                            );
                          },
                          errorBuilder: (_, __, ___) => CurrencyFlagPlaceholder(
                            size: 44,
                            currencyCode: currency.code,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      currency.code,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => _toggleCurrency(currency),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentPage > 0
              ? TextButton(
                  onPressed: _previousPage,
                  child: const Text('Back'),
                )
              : const SizedBox(width: 80),
          Text(
            '${_currentPage + 1}/2',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(_currentPage < 1 ? 'Next' : 'Finish'),
          ),
        ],
      ),
    );
  }
} 