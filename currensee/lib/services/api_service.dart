import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/currency.dart';
import '../models/exchange_rates.dart';

class ApiService {
  final String baseUrl = AppConstants.apiBaseUrl;
  final String apiKey = AppConstants.apiKey;
  final bool _useMockData = AppConstants.apiKey == 'YOUR_API_KEY'; // Check if we need to use mock data

  // Fetch all available currencies
  Future<List<Currency>> fetchAvailableCurrencies() async {
    if (_useMockData) {
      return _getMockCurrencies();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/currencies.json?app_id=$apiKey'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        List<Currency> currencies = [];

        data.forEach((code, name) {
          currencies.add(Currency(
            code: code,
            name: name.toString(),
            symbol: '',  // API doesn't provide symbols in this endpoint
            flagUrl: 'https://flagsapi.com/${code.substring(0, 2)}/flat/64.png',
          ));
        });

        return currencies;
      } else {
        throw Exception('Failed to load currencies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch currencies: $e');
    }
  }

  // Fetch latest exchange rates
  Future<ExchangeRates> fetchExchangeRates(String baseCurrency) async {
    if (_useMockData) {
      return _getMockExchangeRates(baseCurrency);
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/latest.json?app_id=$apiKey&base=$baseCurrency'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ExchangeRates.fromJson(data);
      } else {
        throw Exception('Failed to load exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch exchange rates: $e');
    }
  }
  
  // Generate mock currencies for testing
  List<Currency> _getMockCurrencies() {
    // Common currencies
    final mockCurrencies = [
      Currency(code: 'USD', name: 'United States Dollar', symbol: '\$', flagUrl: 'https://flagsapi.com/US/flat/64.png'),
      Currency(code: 'EUR', name: 'Euro', symbol: '€', flagUrl: 'https://flagsapi.com/EU/flat/64.png'),
      Currency(code: 'GBP', name: 'British Pound', symbol: '£', flagUrl: 'https://flagsapi.com/GB/flat/64.png'),
      Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flagUrl: 'https://flagsapi.com/JP/flat/64.png'),
      Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flagUrl: 'https://flagsapi.com/AU/flat/64.png'),
      Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flagUrl: 'https://flagsapi.com/CA/flat/64.png'),
      Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flagUrl: 'https://flagsapi.com/CH/flat/64.png'),
      Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flagUrl: 'https://flagsapi.com/CN/flat/64.png'),
      Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', flagUrl: 'https://flagsapi.com/IN/flat/64.png'),
      Currency(code: 'AED', name: 'United Arab Emirates Dirham', symbol: 'د.إ', flagUrl: 'https://flagsapi.com/AE/flat/64.png'),
      Currency(code: 'ALL', name: 'Albanian Lek', symbol: 'L', flagUrl: 'https://flagsapi.com/AL/flat/64.png'),
      Currency(code: 'AMD', name: 'Armenian Dram', symbol: '֏', flagUrl: 'https://flagsapi.com/AM/flat/64.png'),
    ];
    
    return mockCurrencies;
  }
  
  // Generate mock exchange rates for testing
  ExchangeRates _getMockExchangeRates(String baseCurrency) {
    // Define standard exchange rates relative to USD
    final Map<String, double> usdBasedRates = {
      'USD': 1.0,
      'EUR': 0.93,
      'GBP': 0.79,
      'JPY': 150.2,
      'AUD': 1.53,
      'CAD': 1.36,
      'CHF': 0.89,
      'CNY': 7.24,
      'INR': 83.4,
      'BTC': 0.000016,  // 1 USD = 0.000016 BTC (or 1 BTC = 62,500 USD)
    };
    
    // Add more mock currencies to ensure we have enough for testing
    if (!usdBasedRates.containsKey('SGD')) {
      usdBasedRates['SGD'] = 1.35; // Singapore Dollar
    }
    if (!usdBasedRates.containsKey('HKD')) {
      usdBasedRates['HKD'] = 7.82; // Hong Kong Dollar
    }
    
    print('🔄 Generated mock exchange rates with base: $baseCurrency');
    
    // If the requested base is USD, simply return rates as is
    if (baseCurrency == 'USD') {
      final rates = Map<String, double>.from(usdBasedRates);
      rates.remove('USD'); // Base currency isn't included in rates
      print('   Using USD as base currency with rates: $rates');
      return ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: rates,
      );
    }
    
    // For non-USD base currencies, we need to convert all rates
    // to be relative to the new base currency
    
    // First, check if we have a rate for the requested base currency
    if (!usdBasedRates.containsKey(baseCurrency)) {
      print('   ⚠️ No rate found for $baseCurrency, defaulting to USD');
      // If we don't have the rate, fall back to USD
      final rates = Map<String, double>.from(usdBasedRates);
      rates.remove('USD');
      return ExchangeRates(
        base: 'USD',
        timestamp: DateTime.now(),
        rates: rates,
      );
    }
    
    // Convert all USD-based rates to be relative to the new base currency
    double baseToUsdRate = usdBasedRates[baseCurrency]!;
    final newRates = <String, double>{};
    
    print('   Converting rates: 1 $baseCurrency = $baseToUsdRate USD');
    
    usdBasedRates.forEach((currency, rateToUsd) {
      if (currency != baseCurrency) {
        // Calculate the new rate relative to the base currency
        double newRate = rateToUsd / baseToUsdRate;
        newRates[currency] = newRate;
        print('   $currency: $newRate');
      }
    });
    
    return ExchangeRates(
      base: baseCurrency,
      timestamp: DateTime.now(),
      rates: newRates,
    );
  }
  
  // Helper to get base currency rate for mock data
  double _getBaseCurrencyRate(String currency) {
    // This method is no longer used with the new implementation
    return 1.0;
  }
} 