class ExchangeRates {
  final String base;
  final DateTime timestamp;
  final Map<String, double> rates;

  ExchangeRates({
    required this.base,
    required this.timestamp,
    required this.rates,
  });

  // Get the USD rate for a specific currency
  double getUsdRate(String currencyCode) {
    // Normalize currency code
    final code = currencyCode.toUpperCase();
    
    // If the currency is USD, rate is 1.0
    if (code == 'USD') return 1.0;
    
    // If our base is USD, return the direct rate
    if (base == 'USD') {
      return rates[code] ?? 1.0;
    }
    
    // If we have a different base currency, we need to convert
    // First get the rate from our base currency to USD
    final baseToUsdRate = rates['USD'] ?? (1.0 / (rates[base] ?? 1.0));
    
    // If the requested currency is our base currency
    if (code == base) {
      return baseToUsdRate;
    }
    
    // For any other currency, convert through the base currency
    final currencyToBaseRate = rates[code] ?? 1.0;
    return currencyToBaseRate * baseToUsdRate;
  }

  // Method to convert amount from one currency to another
  double convert(double amount, String from, String to) {
    print('\n\n💱💱💱 CONVERSION: $amount $from to $to (base=$base) 💱💱💱');
    
    // Normalize currency codes to uppercase for consistency
    from = from.toUpperCase();
    to = to.toUpperCase();
    final baseUpper = base.toUpperCase();
    
    // Handle special cases
    if (from == to) {
      print('⏩ Same currency conversion, returning original amount');
      return amount;
    }
    if (amount == 0) {
      print('⏩ Zero amount, returning zero');
      return 0;
    }
    
    try {
      // Step 1: Determine rates relative to the base currency
      double fromRateToBase;
      double toRateToBase;
      
      // Handle the from currency rate
      if (from == baseUpper) {
        fromRateToBase = 1.0;
      } else {
        fromRateToBase = rates[from] ?? 0.0;
        if (fromRateToBase <= 0) {
          print('⚠️ WARNING: Invalid rate for $from (${rates[from]}), using fallback 1.0');
          fromRateToBase = 1.0;
        }
      }
      
      // Handle the to currency rate
      if (to == baseUpper) {
        toRateToBase = 1.0;
      } else {
        toRateToBase = rates[to] ?? 0.0;
        if (toRateToBase <= 0) {
          print('⚠️ WARNING: Invalid rate for $to (${rates[to]}), using fallback 1.0');
          toRateToBase = 1.0;
        }
      }
      
      print('📊 Using rates:');
      print('   $from → $baseUpper: $fromRateToBase ${from == baseUpper ? "(base currency)" : ""}');
      print('   $to → $baseUpper: $toRateToBase ${to == baseUpper ? "(base currency)" : ""}');
      
      // Step 2: Calculate conversion
      double result;
      
      if (from == baseUpper) {
        // Direct multiplication for base->other conversion
        result = amount * toRateToBase;
        print('📝 Base to other conversion: $amount $from × $toRateToBase = $result $to');
      } 
      else if (to == baseUpper) {
        // Division for other->base conversion
        result = amount / fromRateToBase;
        print('📝 Other to base conversion: $amount $from ÷ $fromRateToBase = $result $to');
      } 
      else {
        // Cross conversion: first to base, then to target
        double amountInBase = amount / fromRateToBase;
        print('   Intermediate step: $amount $from → $amountInBase $baseUpper');
        result = amountInBase * toRateToBase;
        print('📝 Cross conversion: $amount $from → $amountInBase $baseUpper → $result $to');
      }
      
      // Format to avoid floating-point precision issues - use consistent precision for all currencies
      double finalResult = double.parse(result.toStringAsFixed(8));
      print('✅ Final result after rounding: $finalResult $to');
      print('💱💱💱 CONVERSION COMPLETE 💱💱💱\n\n');
      return finalResult;
    } 
    catch (e) {
      print('❌ ERROR during conversion: $e');
      // Fall back to original amount in case of error
      return amount;
    }
  }

  factory ExchangeRates.fromJson(Map<String, dynamic> json) {
    Map<String, double> ratesMap = {};
    
    // Handle both possible response formats
    if (json['rates'] != null) {
      // Standard format with 'rates' key
      json['rates'].forEach((key, value) {
        ratesMap[key.toString().toUpperCase()] = value.toDouble();
      });
    } else if (json.containsKey(json['base']?.toString().toLowerCase())) {
      // Format from fawazahmed0/exchange-api where the base currency is a key
      final baseKey = json['base']?.toString().toLowerCase() ?? '';
      final ratesData = json[baseKey];
      if (ratesData is Map) {
        ratesData.forEach((key, value) {
          if (key.toString().toLowerCase() != baseKey) {
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
            ratesMap[key.toString().toUpperCase()] = rate;
          }
        });
      }
    }
    
    // Parse timestamp from the stored value
    DateTime time;
    if (json['timestamp'] != null) {
      try {
        if (json['timestamp'] is int) {
          // Handle milliseconds vs seconds timestamp format
          final timestamp = json['timestamp'] as int;
          // If timestamp is in seconds (API format), convert to milliseconds
          // If already in milliseconds (our storage format), use directly
          final isInSeconds = timestamp < 10000000000; // Basic check if in seconds vs milliseconds
          time = DateTime.fromMillisecondsSinceEpoch(
            isInSeconds ? timestamp * 1000 : timestamp
          );
        } else if (json['timestamp'] is String) {
          // Try to parse string timestamp
          time = DateTime.parse(json['timestamp']);
        } else {
          // Fallback - but log the issue
          print('⚠️ Unknown timestamp format: ${json['timestamp']}');
          time = DateTime.now();
        }
      } catch (e) {
        print('⚠️ Error parsing timestamp: $e');
        time = DateTime.now();
      }
    } else {
      print('⚠️ No timestamp found in exchange rates data');
      time = DateTime.now();
    }
    
    return ExchangeRates(
      base: (json['base'] ?? 'USD').toString().toUpperCase(),
      timestamp: time,
      rates: ratesMap,
    );
  }

  Map<String, dynamic> toJson() {
    // Save the rates and timestamp in a consistent format
    // that can be correctly parsed by fromJson
    return {
      'base': base,
      'timestamp': timestamp.millisecondsSinceEpoch, // Store as milliseconds for better precision
      'rates': rates,
    };
  }
} 