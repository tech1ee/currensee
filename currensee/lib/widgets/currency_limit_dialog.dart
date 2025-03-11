import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class CurrencyLimitDialog extends StatelessWidget {
  const CurrencyLimitDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Currency Limit Reached'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have reached the free limit of ${AppConstants.maxCurrenciesFreeTier} currencies.',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          const Text(
            'Please remove a currency before adding a new one or upgrade to premium for unlimited currencies.',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('OK'),
        ),
        ElevatedButton(
          onPressed: () {
            // In a future version, this would navigate to upgrade screen
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Premium upgrade coming in a future version!'),
              ),
            );
          },
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}

// Show the dialog
void showCurrencyLimitDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const CurrencyLimitDialog(),
  );
} 