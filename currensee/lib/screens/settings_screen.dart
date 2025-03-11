import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userPrefs = Provider.of<UserPreferencesProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          
          // Theme Settings
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'APPEARANCE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          
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
          
          const Divider(),
          
          // About Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ABOUT',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          
          ListTile(
            title: const Text('App Version'),
            subtitle: const Text('1.0.0'),
            leading: const Icon(Icons.info),
          ),
          
          if (!userPrefs.isPremium) ...[
            const Divider(),
            
            // Premium Upgrade
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'PREMIUM',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            
            ListTile(
              title: const Text('Upgrade to Premium'),
              subtitle: const Text('Remove ads, add unlimited currencies'),
              leading: const Icon(Icons.star, color: Colors.amber),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Premium upgrade coming in a future version!'),
                  ),
                );
              },
            ),
          ],
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
} 