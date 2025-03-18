import 'package:flutter/material.dart';

class CurrencyFlagPlaceholder extends StatelessWidget {
  final double size;
  final String currencyCode;

  const CurrencyFlagPlaceholder({
    Key? key,
    this.size = 24,
    required this.currencyCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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