class Currency {
  final String code;
  final String name;
  final String symbol;
  double value;
  final String flagUrl;
  bool hasValidRate;

  Currency({
    required this.code,
    required this.name,
    required this.symbol,
    this.value = 1.0,
    required this.flagUrl,
    this.hasValidRate = true,
  });

  Currency copyWith({
    String? code,
    String? name,
    String? symbol,
    double? value,
    String? flagUrl,
    bool? hasValidRate,
  }) {
    return Currency(
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      value: value ?? this.value,
      flagUrl: flagUrl ?? this.flagUrl,
      hasValidRate: hasValidRate ?? this.hasValidRate,
    );
  }

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'],
      name: json['name'],
      symbol: json['symbol'] ?? '',
      value: json['value']?.toDouble() ?? 1.0,
      flagUrl: json['flagUrl'] ?? '',
      hasValidRate: json['hasValidRate'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'symbol': symbol,
      'value': value,
      'flagUrl': flagUrl,
      'hasValidRate': hasValidRate,
    };
  }

  @override
  String toString() {
    return 'Currency(code: $code, name: $name, symbol: $symbol, value: $value, flagUrl: $flagUrl, hasValidRate: $hasValidRate)';
  }
} 