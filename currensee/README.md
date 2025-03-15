# CurrenSee

A modern currency tracking application with real-time exchange rates.

![CurrenSee App](assets/images/app_preview.png)

## Features

- **Real-time Currency Conversion**: Track and convert between multiple currencies with up-to-date exchange rates
- **Customizable Base Currency**: Set any currency as your base for conversions
- **Offline Support**: Continue using the app with the most recent rates when offline
- **Dark & Light Themes**: Choose between dark and light modes for comfortable viewing
- **Premium Subscription**: Unlock unlimited daily refreshes and remove ads
- **User-Friendly Interface**: Intuitive design for easy currency management

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

4. Run the app
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

## Future Enhancements

- Historical rate charts
- Currency alerts and notifications
- Offline currency calculator
- Additional themes and customization options

## Privacy Policy

This app collects minimal user data required for functionality. See our [Privacy Policy](https://example.com/privacy) for more details.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Exchange rate data provided by [Exchange Rate API]
- Flag images from [Country Flags API]
- Icons from [Material Design Icons]
