import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/currency.dart';
import '../models/exchange_rates.dart';

class ApiService {
  final String baseUrl = AppConstants.apiBaseUrl;
  final String fallbackUrl = AppConstants.apiFallbackUrl;
  final bool _useMockData = AppConstants.useMockData;

  // Fetch all available currencies
  Future<List<Currency>> fetchAvailableCurrencies() async {
    if (_useMockData) {
      return _getMockCurrencies();
    }
    
    try {
      print('🌐 API: Fetching available currencies from ${baseUrl}currencies.json');
      // First try the primary URL
      final response = await http.get(
        Uri.parse('${baseUrl}currencies.json'),
      ).timeout(const Duration(seconds: 10));

      print('🌐 API: Primary URL response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final currencies = _parseCurrenciesResponse(response.body);
        print('✅ API: Successfully parsed ${currencies.length} currencies from primary URL');
        return currencies;
      } 
      
      // If primary URL fails, try the fallback
      print('⚠️ API: Primary URL failed, trying fallback ${fallbackUrl}currencies.json');
      final fallbackResponse = await http.get(
        Uri.parse('${fallbackUrl}currencies.json'),
      ).timeout(const Duration(seconds: 10));
      
      print('🌐 API: Fallback URL response status: ${fallbackResponse.statusCode}');
      
      if (fallbackResponse.statusCode == 200) {
        final currencies = _parseCurrenciesResponse(fallbackResponse.body);
        print('✅ API: Successfully parsed ${currencies.length} currencies from fallback URL');
        return currencies;
      }
      
      throw Exception('Failed to load currencies: ${response.statusCode}');
    } catch (e) {
      print('❌ Error fetching currencies: $e');
      throw Exception('Failed to fetch currencies: $e');
    }
  }

  // Helper method to parse currencies response
  List<Currency> _parseCurrenciesResponse(String responseBody) {
    try {
      final Map<String, dynamic> data = json.decode(responseBody);
      print('🔄 API: Parsing currencies response with ${data.length} entries');
      List<Currency> currencies = [];

      // Special case currency mappings for flags
      final Map<String, String> specialFlagMappings = {
        'EUR': 'eu', // European Union
        'GBP': 'gb', // United Kingdom
        'USD': 'us', // United States
        'AUD': 'au', // Australia
        'CAD': 'ca', // Canada
        'NZD': 'nz', // New Zealand
        'CHF': 'ch', // Switzerland
        'JPY': 'jp', // Japan
        'KZT': 'kz', // Kazakhstan
        'UAH': 'ua', // Ukraine
        'RUB': 'ru', // Russia
        'AED': 'ae', // United Arab Emirates
        'AKT': 'crypto', // Akash token (crypto)
        'BTC': 'crypto', // Bitcoin (crypto)
        'ETH': 'crypto', // Ethereum (crypto)
        'USDT': 'crypto', // Tether (crypto)
        'XRP': 'crypto', // Ripple (crypto)
        'DOGE': 'crypto', // Dogecoin (crypto)
        'TRX': 'crypto', // TRON (crypto)
        'ADA': 'crypto', // Cardano (crypto)
        'SOL': 'crypto', // Solana (crypto)
        'DOT': 'crypto', // Polkadot (crypto)
        'AVAX': 'crypto', // Avalanche (crypto)
        'MATIC': 'crypto', // Polygon (crypto)
        'LINK': 'crypto', // Chainlink (crypto)
        'UNI': 'crypto', // Uniswap (crypto)
        'ATOM': 'crypto', // Cosmos (crypto)
        'LTC': 'crypto', // Litecoin (crypto)
        'WAVES': 'crypto', // Waves (crypto)
        'WEMIX': 'crypto', // Wemix (crypto)
        'WOO': 'crypto', // WOO Network (crypto)
      };

      data.forEach((code, name) {
        String flagUrl = '';
        String upperCode = code.toUpperCase();
        
        // Handle special cases first
        if (specialFlagMappings.containsKey(upperCode)) {
          final flagCode = specialFlagMappings[upperCode]!;
          
          if (flagCode == 'crypto') {
            // Use cryptocurrency icon from CoinGecko
            flagUrl = 'https://static.coingecko.com/s/thumbnail-${code.toLowerCase()}-64.png';
            
            // Additionally set a generic crypto fallback URL for the error handler
            // This never gets used directly - it's for tracking that this is a crypto
            // and will be handled by the error builder in the UI
            if (upperCode.startsWith('X') || 
                ['TRX', 'BTC', 'ETH', 'USDT', 'XRP', 'DOGE', 'ADA', 'SOL'].contains(upperCode)) {
                // This is almost certainly a cryptocurrency
                flagUrl = 'crypto://$upperCode';
            }
          } else {
            // Use country flag from flagcdn.com
            flagUrl = 'https://flagcdn.com/w160/$flagCode.png';
          }
        }
        // Default case - try to derive flag from first 2 letters of currency code
        else if (code.length >= 2) {
          // Skip known non-country codes to avoid 404 errors
          if (!['AK', 'XD', 'XC', 'ZR', 'XX'].contains(code.substring(0, 2).toUpperCase())) {
            String flagCode = code.substring(0, 2).toLowerCase();
            flagUrl = 'https://flagcdn.com/w160/$flagCode.png';
          }
        }
        
        currencies.add(Currency(
          code: upperCode,
          name: name.toString(),
          symbol: _getCurrencySymbol(upperCode),
          flagUrl: flagUrl,
        ));
      });

      return currencies;
    } catch (e) {
      print('❌ Error parsing currencies: $e');
      throw Exception('Failed to parse currencies: $e');
    }
  }

  // Get currency symbol based on code
  String _getCurrencySymbol(String code) {
    final Map<String, String> symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'CNY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'CHF': 'Fr',
      'HKD': 'HK\$',
      'SGD': 'S\$',
      'INR': '₹',
      'BRL': 'R\$',
      'RUB': '₽',
      'KRW': '₩',
      'TRY': '₺',
      'ZAR': 'R',
      'MXN': 'Mex\$',
      'AED': 'د.إ',
      'BTC': '₿',
      'ETH': 'Ξ',
      // Add more symbols as needed
    };
    
    return symbols[code] ?? '';
  }

  // Fetch latest exchange rates
  Future<ExchangeRates> fetchExchangeRates(String baseCurrency) async {
    print('🌐 API: Fetching exchange rates for base currency: $baseCurrency');
    
    if (_useMockData) {
      print('🔄 Using mock data (useMockData=true)');
      return _getMockExchangeRates(baseCurrency);
    }
    
    try {
      // Normalize the base currency code
      final normalizedBase = baseCurrency.toLowerCase();
      print('🔄 Normalized base currency: $normalizedBase');
      
      // First try the primary URL
      final primaryUrl = '${baseUrl}currencies/$normalizedBase.json';
      print('🔄 Trying primary URL: $primaryUrl');
      
      final response = await http.get(
        Uri.parse(primaryUrl),
      ).timeout(const Duration(seconds: 15)); // Increased timeout

      if (response.statusCode == 200) {
        print('✅ Primary URL success (status: ${response.statusCode})');
        try {
          final result = _parseRatesResponse(response.body, baseCurrency);
          print('✅ Parsed rates successfully: ${result.rates.length} currencies');
          return result;
        } catch (parseError) {
          print('⚠️ Error parsing primary response: $parseError');
          print('⚠️ Response body: ${response.body.substring(0, math.min(100, response.body.length))}...');
          // Continue to fallback URL
        }
      } else {
        print('⚠️ Primary URL failed with status: ${response.statusCode}');
      }
      
      // If primary URL fails, try the fallback
      final fallbackUrl = '${this.fallbackUrl}currencies/$normalizedBase.json';
      print('🔄 Trying fallback URL: $fallbackUrl');
      
      final fallbackResponse = await http.get(
        Uri.parse(fallbackUrl),
      ).timeout(const Duration(seconds: 15)); // Increased timeout
      
      if (fallbackResponse.statusCode == 200) {
        print('✅ Fallback URL success (status: ${fallbackResponse.statusCode})');
        try {
          final result = _parseRatesResponse(fallbackResponse.body, baseCurrency);
          print('✅ Parsed fallback rates successfully: ${result.rates.length} currencies');
          return result;
        } catch (parseError) {
          print('⚠️ Error parsing fallback response: $parseError');
          print('⚠️ Response body: ${fallbackResponse.body.substring(0, math.min(100, fallbackResponse.body.length))}...');
          throw Exception('Failed to parse exchange rates from both sources');
        }
      } else {
        print('⚠️ Fallback URL failed with status: ${fallbackResponse.statusCode}');
      }
      
      print('❌ Both primary and fallback URLs failed, returning to mock data as last resort');
      // If both URLs fail, use mock data as a last resort
      return _getMockExchangeRates(baseCurrency);
    } catch (e) {
      print('❌ Error fetching exchange rates: $e');
      // Fallback to mock data in case of network or other errors
      print('🔄 Falling back to mock data due to error');
      return _getMockExchangeRates(baseCurrency);
    }
  }

  // Helper method to parse rates response
  ExchangeRates _parseRatesResponse(String responseBody, String baseCurrency) {
    final Map<String, dynamic> data = json.decode(responseBody);
    
    // The API returns a structure like {"usd": {"eur": 0.93, "gbp": 0.79, ...}}
    // We need to extract the inner rates object
    final baseKey = baseCurrency.toLowerCase();
    final Map<String, dynamic> ratesData = data[baseKey] ?? {};
    
    // Convert to our expected format
    final Map<String, double> rates = {};
    ratesData.forEach((code, value) {
      if (code != baseKey) {  // Skip the base currency itself
        // Convert to double, handle potential non-numeric values
        double rate;
        if (value is double) {
          rate = value;
        } else if (value is int) {
          rate = value.toDouble();
        } else if (value is String) {
          rate = double.tryParse(value) ?? 0.0;
        } else {
          rate = 0.0;
        }
        rates[code.toUpperCase()] = rate;
      }
    });
    
    // Check if there's a timestamp in the response
    DateTime timestamp = DateTime.now();
    
    // Try to get the last-modified header from API response if available
    // This is a more accurate representation of when the rates were published
    if (data['time_last_update_unix'] != null) {
      try {
        // API provides timestamp in seconds, convert to milliseconds
        final unixTimestamp = data['time_last_update_unix'];
        if (unixTimestamp is int) {
          timestamp = DateTime.fromMillisecondsSinceEpoch(unixTimestamp * 1000);
          print('✅ Using API-provided timestamp: $timestamp');
        }
      } catch (e) {
        print('⚠️ Error parsing API timestamp: $e');
        // Keep default DateTime.now() timestamp
      }
    }
    
    return ExchangeRates(
      base: baseCurrency.toUpperCase(),
      timestamp: timestamp,
      rates: rates,
    );
  }
  
  // Generate mock currencies for testing
  List<Currency> _getMockCurrencies() {
    // Common currencies
    final mockCurrencies = [
      Currency(code: 'USD', name: 'United States Dollar', symbol: '\$', flagUrl: 'https://flagcdn.com/w160/us.png'),
      Currency(code: 'EUR', name: 'Euro', symbol: '€', flagUrl: 'https://flagcdn.com/w160/eu.png'),
      Currency(code: 'GBP', name: 'British Pound', symbol: '£', flagUrl: 'https://flagcdn.com/w160/gb.png'),
      Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flagUrl: 'https://flagcdn.com/w160/jp.png'),
      Currency(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flagUrl: 'https://flagcdn.com/w160/au.png'),
      Currency(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flagUrl: 'https://flagcdn.com/w160/ca.png'),
      Currency(code: 'CHF', name: 'Swiss Franc', symbol: 'Fr', flagUrl: 'https://flagcdn.com/w160/ch.png'),
      Currency(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flagUrl: 'https://flagcdn.com/w160/cn.png'),
      Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', flagUrl: 'https://flagcdn.com/w160/in.png'),
      Currency(code: 'AED', name: 'United Arab Emirates Dirham', symbol: 'د.إ', flagUrl: 'https://flagcdn.com/w160/ae.png'),
      Currency(code: 'ALL', name: 'Albanian Lek', symbol: 'L', flagUrl: 'https://flagcdn.com/w160/al.png'),
      Currency(code: 'AMD', name: 'Armenian Dram', symbol: '֏', flagUrl: 'https://flagcdn.com/w160/am.png'),
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
} 