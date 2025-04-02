# CurrenSee

A modern currency tracking application with real-time exchange rates.

![CurrenSee App](assets/images/app_preview.png)

## Features

- **Real-time Currency Conversion**: Track and convert between multiple currencies with up-to-date exchange rates
- **Customizable Base Currency**: Set any currency as your base for conversions
- **Rate Limiting with Caching**: Free users can refresh rates once per day with proper timestamp tracking
- **Offline Support**: Continue using the app with the most recent rates when offline
- **Dark & Light Themes**: Choose between dark and light modes for comfortable viewing
- **Premium Subscription**: Unlock unlimited daily refreshes and remove ads
- **User-Friendly Interface**: Intuitive design for easy currency management
- **Accurate Timestamp Display**: Clear indication of when rates were last refreshed from the API

## Screenshots

<table>
  <tr>
    <td><img src="assets/images/screenshot_1.png" width="200"/></td>
    <td><img src="assets/images/screenshot_2.png" width="200"/></td>
    <td><img src="assets/images/screenshot_3.png" width="200"/></td>
  </tr>
</table>

## Getting Started

### Prerequisites

- Flutter SDK (^3.7.0)
- Dart SDK (^3.2.0)
- Android Studio / Xcode for emulators
- Internet connection for initial setup and real-time rates

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/currensee.git
   ```

2. Navigate to the project directory
   ```bash
   cd currensee
   ```

3. Install dependencies
   ```bash
   flutter pub get
   ```

4. Set up environment variables
   ```bash
   cp .env.example .env
   ```
   Then edit the `.env` file with your actual API keys and Ad Unit IDs.

5. Run the app
   ```bash
   flutter run
   ```

## Project Structure

- `/lib`
  - `/constants` - App theme and other constant values
  - `/models` - Data models for currencies and rates
  - `/providers` - State management for the app
  - `/screens` - Main app screens
  - `/services` - API and platform services
  - `/utils` - Utility functions
  - `/widgets` - Reusable UI components

## Dependencies

- `provider` - For state management
- `http` - For API calls to fetch exchange rates
- `shared_preferences` - For local storage of user preferences
- `google_mobile_ads` - For displaying advertisements
- `intl` - For number and date formatting

## Premium Features

The app offers a premium subscription that includes:
- Unlimited exchange rate refreshes
- Ad-free experience
- Priority support

## Free vs Premium

### Free Version
- Limited to one exchange rate refresh per day
- Last refresh timestamp is accurately preserved between app launches
- Cached rates are used when refresh limit is reached
- Shows ads

### Premium Version
- Unlimited exchange rate refreshes
- No waiting period between refreshes
- Ad-free experience

## Recent Improvements

- **Fixed Timestamp Display**: Free users now see the accurate last refresh time instead of the current time when the app launches
- **Optimized Rate Refreshing**: Reduced unnecessary API calls for free users who have already refreshed that day
- **Enhanced Caching**: Preserved original timestamps when loading cached exchange rates
- **Improved UI Clarity**: Better visual indication of when rates were last updated from the API

## Future Enhancements

- Historical rate charts
- Currency alerts and notifications
- Offline currency calculator
- Enhanced flag display for all currencies
- Additional themes and customization options
- Widgets for home screen quick access
- Improved performance on low-end devices

## Privacy Policy

This app collects minimal user data required for functionality. See our [Privacy Policy](https://example.com/privacy) for more details.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Exchange rate data provided by [Exchange Rate API]
- Flag images from [Country Flags API]
- Icons from [Material Design Icons]

## Setup Instructions

### Firebase Configuration

This project uses Firebase for Crashlytics and Analytics. Before running the app, you need to set up your own Firebase project:

1. Create a new Firebase project at [firebase.google.com](https://firebase.google.com)
2. Add Android, iOS, and web apps to your Firebase project
3. Download the configuration files:
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS/macOS
4. Place these files in their respective directories:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
   - macOS: `macos/Runner/GoogleService-Info.plist`
5. Run `flutterfire configure` to generate your own `firebase_options.dart` file

Note: The Firebase configuration files (`google-services.json` and `GoogleService-Info.plist`) as well as API keys should never be committed to version control. These files have been added to the `.gitignore` file.

### Development Environment

1. Clone the repository
2. Make sure to follow the Firebase Configuration steps above
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## Security Notes

- The Firebase configuration files and API keys are now managed through environment variables (.env)
- Never commit the `.env` file to version control (it's already added to `.gitignore`)
- For development, use `.env.example` as a template to create your own `.env` file
- For CI/CD and production deployments, inject environment variables through your build pipeline
- Use test API keys for AdMob during development and testing
- Make sure Firebase security rules are properly configured
- All API keys are loaded at runtime from environment variables, making the app more secure
