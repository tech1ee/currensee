import 'package:flutter/material.dart';

class CurrencyFlagPlaceholder extends StatelessWidget {
  final double size;
  final String currencyCode;

  const CurrencyFlagPlaceholder({
    Key? key,
    this.size = 24,
    required this.currencyCode,
  }) : super(key: key);

  bool get _isCrypto {
    // Common cryptocurrency codes
    final cryptoCodes = [
      'BTC', 'ETH', 'USDT', 'XRP', 'DOGE', 'ADA', 'SOL', 'DOT', 'AVAX', 
      'MATIC', 'LINK', 'UNI', 'ATOM', 'LTC', 'TRX', 'WAVES', 'WEMIX', 'WOO'
    ];
    
    // Check if it's likely a cryptocurrency
    return cryptoCodes.contains(currencyCode) || 
           currencyCode.startsWith('X') ||
           (currencyCode.length >= 3 && !_isLikelyCountry);
  }
  
  bool get _isLikelyCountry {
    if (currencyCode.length < 2) return false;
    
    // Common currency prefixes for countries
    final countryPrefixes = ['AU', 'CA', 'EU', 'GB', 'JP', 'US', 'NZ', 'CH', 'RU', 'UA', 'AE'];
    return countryPrefixes.contains(currencyCode.substring(0, 2));
  }

  @override
  Widget build(BuildContext context) {
    if (_isCrypto) {
      // Cryptocurrency placeholder
      return Container(
        width: size,
        height: size * 0.75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.375), // Make it circular
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF9A825).withOpacity(0.6), // Bitcoin-ish gold color
              const Color(0xFFFF9800).withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: Text(
            // Display first letter of currency code
            currencyCode.isNotEmpty ? currencyCode[0] : '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.42,
            ),
          ),
        ),
      );
    } else {
      // Regular currency placeholder
      return Container(
        width: size,
        height: size * 0.75, // Maintain 4:3 aspect ratio like most flags
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            // Display first 2 letters of currency code
            currencyCode.length >= 2 ? currencyCode.substring(0, 2) : currencyCode,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.4,
            ),
          ),
        ),
      );
    }
  }
} 