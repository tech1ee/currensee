import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/currency.dart';
import '../models/exchange_rates.dart';

class ApiService {
  final String baseUrl = AppConstants.apiBaseUrl;
  final String apiKey = AppConstants.apiKey;

  // Fetch all available currencies
  Future<List<Currency>> fetchAvailableCurrencies() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/currencies.json?app_id=$apiKey'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        List<Currency> currencies = [];

        data.forEach((code, name) {
          currencies.add(Currency(
            code: code,
            name: name.toString(),
            symbol: '',  // API doesn't provide symbols in this endpoint
            flagUrl: 'https://flagsapi.com/${code.substring(0, 2)}/flat/64.png',
          ));
        });

        return currencies;
      } else {
        throw Exception('Failed to load currencies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch currencies: $e');
    }
  }

  // Fetch latest exchange rates
  Future<ExchangeRates> fetchExchangeRates(String baseCurrency) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/latest.json?app_id=$apiKey&base=$baseCurrency'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return ExchangeRates.fromJson(data);
      } else {
        throw Exception('Failed to load exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch exchange rates: $e');
    }
  }
} 