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
    if (from == to) return amount;
    
    // First convert to the base currency
    double amountInBase;
    if (from == base) {
      amountInBase = amount;
    } else {
      amountInBase = amount / rates[from]!;
    }
    
    // Then convert from base to target currency
    if (to == base) {
      return amountInBase;
    } else {
      return amountInBase * rates[to]!;
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