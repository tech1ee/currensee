class ExchangeRates {
  final String base;
  final DateTime timestamp;
  final Map<String, double> rates;

  ExchangeRates({
    required this.base,
    required this.timestamp,
    required this.rates,
  });

  // Method to convert amount from one currency to another
  double convert(double amount, String from, String to) {
    print('\n\n💱💱💱 CONVERSION: $amount $from to $to (base=$base) 💱💱💱');
    
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
      double fromRateToBase = from == base ? 1.0 : (rates[from] ?? 0.0);
      double toRateToBase = to == base ? 1.0 : (rates[to] ?? 0.0);
      
      print('📊 Using rates:');
      print('   $from → $base: $fromRateToBase ${from == base ? "(base currency)" : ""}');
      print('   $to → $base: $toRateToBase ${to == base ? "(base currency)" : ""}');
      
      // Check if we have valid rates
      if (fromRateToBase <= 0) {
        print('⚠️ WARNING: Invalid rate for $from, using fallback');
        return amount;
      }
      if (toRateToBase <= 0) {
        print('⚠️ WARNING: Invalid rate for $to, using fallback');
        return amount;
      }
      
      // Step 2: Calculate conversion
      double result;
      
      if (from == base) {
        // Direct multiplication for base->other conversion
        result = amount * toRateToBase;
        print('📝 Base to other conversion: $amount $from × $toRateToBase = $result $to');
      } 
      else if (to == base) {
        // Division for other->base conversion
        result = amount / fromRateToBase;
        print('📝 Other to base conversion: $amount $from ÷ $fromRateToBase = $result $to');
      } 
      else {
        // Cross conversion: first to base, then to target
        double amountInBase = amount / fromRateToBase;
        print('   Intermediate step: $amount $from → $amountInBase $base');
        result = amountInBase * toRateToBase;
        print('📝 Cross conversion: $amount $from → $amountInBase $base → $result $to');
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
    
    if (json['rates'] != null) {
      json['rates'].forEach((key, value) {
        ratesMap[key] = value.toDouble();
      });
    }
    
    return ExchangeRates(
      base: json['base'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] * 1000),
      rates: ratesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base': base,
      'timestamp': timestamp.millisecondsSinceEpoch ~/ 1000,
      'rates': rates,
    };
  }
} 