import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../providers/currency_provider.dart';
import '../services/storage_service.dart';
import '../services/purchase_service.dart';
import '../widgets/settings_section.dart';
import 'dart:async';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    final currencyProvider = Provider.of<CurrencyProvider>(context);
    final storageService = Provider.of<StorageService>(context);
    final bool isPremium = userPrefs.isPremium;
    
    // Prepare sections
    final List<Widget> sections = [];
    
    // Add theme settings section
    sections.add(
      SettingSection(
        title: 'Appearance',
        children: [
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeName(userPrefs.themeMode)),
            leading: const Icon(Icons.palette),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('System'),
                      leading: userPrefs.themeMode == ThemeMode.system
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox(width: 24),
                      onTap: () {
                        userPrefs.setThemeMode(ThemeMode.system);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Light'),
                      leading: userPrefs.themeMode == ThemeMode.light
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox(width: 24),
                      onTap: () {
                        userPrefs.setThemeMode(ThemeMode.light);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      title: const Text('Dark'),
                      leading: userPrefs.themeMode == ThemeMode.dark
                          ? const Icon(Icons.check, color: Colors.green)
                          : const SizedBox(width: 24),
                      onTap: () {
                        userPrefs.setThemeMode(ThemeMode.dark);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
    
    // Subscription section (shows different content based on premium status)
    sections.add(
      SettingSection(
        title: 'Subscription',
        children: isPremium
            ? [
                // For Premium users
                ListTile(
                  title: const Text('Premium Status'),
                  subtitle: const Text('Premium features are active'),
                  leading: const Icon(Icons.star, color: Colors.amber),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.amber.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ]
            : [
                // For Free users
                ListTile(
                  title: const Text('Upgrade to Premium'),
                  subtitle: const Text('Remove ads, add unlimited currencies'),
                  leading: const Icon(Icons.star, color: Colors.amber),
                  onTap: () {
                    _purchasePremium(context);
                  },
                ),
                ListTile(
                  title: const Text('Restore Purchases'),
                  subtitle: const Text('Restore your premium subscription'),
                  leading: const Icon(Icons.restore),
                  onTap: () async {
                    final success = await _restorePurchases(context);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchases restored successfully')),
                      );
                    }
                  },
                ),
              ],
      ),
    );
    
    // Add about section
    sections.add(
      SettingSection(
        title: 'About',
        children: [
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info),
          ),
        ],
      ),
    );
    
    // Debug section always available in debug builds
    if (kDebugMode) {
      sections.add(
        SettingSection(
          title: 'Debug Options',
          children: [
            ListTile(
              title: const Text('Reset Premium Status (TESTING ONLY)'),
              subtitle: Text('Current status: ${isPremium ? "PREMIUM" : "FREE"}'),
              trailing: Switch(
                value: isPremium,
                onChanged: (value) async {
                  await userPrefs.setPremiumStatus(value);
                  
                  // Also reset last refresh timestamp for free users
                  if (!value) {
                    // For free users, set last refresh to yesterday to allow one refresh today
                    final yesterday = DateTime.now().subtract(const Duration(days: 1));
                    await userPrefs.setLastRatesRefresh(yesterday);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Set to FREE user with refresh available')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Set to PREMIUM user')),
                    );
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Reset Last Refresh'),
              subtitle: Text('Last refresh: ${currencyProvider.userPreferences?.lastRatesRefresh?.toString() ?? 'None'}'),
              trailing: const Icon(Icons.bug_report),
              onTap: () async {
                // Reset lastRatesRefresh to null to test premium dialog
                final userPrefs = currencyProvider.userPreferences;
                if (userPrefs != null) {
                  final updatedPrefs = userPrefs.copyWith(
                    lastRatesRefresh: null,
                  );
                  await storageService.saveUserPreferences(updatedPrefs);
                  
                  // Show confirmation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('DEBUG: Last refresh date reset')),
                  );
                  
                  // Force app to restart to reload preferences
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          ...sections,
        ],
      ),
    );
  }
  
  String _getThemeModeName(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  // Method to restore purchases
  Future<bool> _restorePurchases(BuildContext context) async {
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Use a completer to track when the restore is done
    final completer = Completer<bool>();
    
    // Show loading indicator with a cleaner approach
    final BuildContext outerContext = context;
    
    // Show the dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Start the restore process
        _processRestore(purchaseService, userPrefs).then((success) {
          // Complete the operation
          completer.complete(success);
          
          // Close the dialog if it's still showing
          if (dialogContext != null) {
            try {
              Navigator.of(dialogContext).pop();
              print('💰 Restore dialog closed via completer');
            } catch (e) {
              print('💰 Error closing restore dialog: $e');
            }
          }
        }).catchError((error) {
          // Handle errors
          print('💰 Restore error: $error');
          completer.completeError(error);
          
          // Always close the dialog
          if (dialogContext != null) {
            try {
              Navigator.of(dialogContext).pop();
              print('💰 Restore dialog closed after error');
            } catch (e) {
              print('💰 Error closing restore dialog after error: $e');
            }
          }
        });
        
        // Return the actual dialog widget
        return WillPopScope(
          // Prevent users from dismissing with back button
          onWillPop: () async => false,
          child: const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring purchases...'),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // Wait for the restore result
    try {
      final success = await completer.future;
      
      // Show success/failure message if needed
      if (outerContext.mounted) {
        if (success) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            const SnackBar(content: Text('Purchases restored successfully!')),
          );
        } else {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            SnackBar(content: Text('Restore failed: ${purchaseService.error ?? "Unknown error"}')),
          );
        }
      }
      
      return success;
    } catch (e) {
      // Show error message (dialog should already be closed)
      if (outerContext.mounted) {
        ScaffoldMessenger.of(outerContext).showSnackBar(
          SnackBar(content: Text('Error restoring purchases: $e')),
        );
      }
      return false;
    }
  }
  
  // Separate method to process the restore
  Future<bool> _processRestore(PurchaseService purchaseService, UserPreferencesProvider userPrefs) async {
    try {
      print('💰 Starting restore process');
      // Process restore
      final success = await purchaseService.restorePurchases();
      print('💰 Restore result: $success');
      
      // Update user preferences if successful
      if (success) {
        await userPrefs.setPremiumStatus(true);
      }
      
      return success;
    } catch (e) {
      print('💰 Error during restore process: $e');
      // Re-throw to be handled by the caller
      rethrow;
    }
  }

  // Method to purchase premium
  Future<void> _purchasePremium(BuildContext context) async {
    final purchaseService = Provider.of<PurchaseService>(context, listen: false);
    final userPrefs = Provider.of<UserPreferencesProvider>(context, listen: false);
    
    // Use a completer to track when the purchase is done
    final completer = Completer<bool>();
    
    // Show loading indicator with a cleaner approach
    final BuildContext outerContext = context;
    
    // Show the dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Start the purchase process
        _processPurchase(purchaseService, userPrefs).then((success) {
          // Complete the operation
          completer.complete(success);
          
          // Close the dialog if it's still showing
          if (dialogContext != null) {
            try {
              Navigator.of(dialogContext).pop();
              print('💰 Payment dialog closed via completer');
            } catch (e) {
              print('💰 Error closing payment dialog: $e');
            }
          }
        }).catchError((error) {
          // Handle errors
          print('💰 Purchase error: $error');
          completer.completeError(error);
          
          // Always close the dialog
          if (dialogContext != null) {
            try {
              Navigator.of(dialogContext).pop();
              print('💰 Payment dialog closed after error');
            } catch (e) {
              print('💰 Error closing payment dialog after error: $e');
            }
          }
        });
        
        // Return the actual dialog widget
        return WillPopScope(
          // Prevent users from dismissing with back button
          onWillPop: () async => false,
          child: const Dialog(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing payment...'),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // Wait for the purchase result
    try {
      final success = await completer.future;
      
      // The dialog should already be closed by this point
      
      // Show success/failure message
      if (outerContext.mounted) {
        if (success) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            const SnackBar(content: Text('Premium upgrade successful! Enjoy unlimited refreshes.')),
          );
          
          // Force rebuild to show updated UI
          if (context.mounted) {
            Navigator.of(context).pop(); // Return to home screen to see changes
          }
        } else {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            SnackBar(content: Text('Purchase failed: ${purchaseService.error ?? "Unknown error"}')),
          );
        }
      }
    } catch (e) {
      // Show error message (dialog should already be closed)
      if (outerContext.mounted) {
        ScaffoldMessenger.of(outerContext).showSnackBar(
          SnackBar(content: Text('Error during purchase: $e')),
        );
      }
    }
  }
  
  // Separate method to process the purchase
  Future<bool> _processPurchase(PurchaseService purchaseService, UserPreferencesProvider userPrefs) async {
    try {
      print('💰 Starting premium purchase process from settings');
      // Process purchase
      final success = await purchaseService.purchasePremium();
      print('💰 Purchase result: $success');
      
      // Update user preferences if successful
      if (success) {
        await userPrefs.setPremiumStatus(true);
      }
      
      return success;
    } catch (e) {
      print('💰 Error during purchase process: $e');
      // Re-throw to be handled by the caller
      rethrow;
    }
  }
} 