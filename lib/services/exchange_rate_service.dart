





import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ExchangeRateService {
  static final ExchangeRateService _instance = ExchangeRateService._internal();
  factory ExchangeRateService() => _instance;
  ExchangeRateService._internal();

  static const String _cacheKey = 'asuhkita_exchange_rates';
  static const String _cacheTimestampKey = 'asuhkita_exchange_rates_ts';
  static const Duration _cacheDuration = Duration(hours: 6);


  static const Map<String, double> _staticRates = {
    'IDR': 1.0,
    'USD': 15850.0,
    'SGD': 11800.0,
    'EUR': 17200.0,
    'SAR': 4220.0,
  };


  Map<String, double> _currentRates = Map.from(_staticRates);
  bool _isUsingRealtime = false;

  Map<String, double> get rates => Map.from(_currentRates);
  bool get isUsingRealtime => _isUsingRealtime;





  Future<Map<String, double>> fetchRates() async {

    final cached = await _loadFromCache();
    if (cached != null) {
      _currentRates = cached;
      _isUsingRealtime = true;
      return _currentRates;
    }


    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 2500),
        receiveTimeout: const Duration(milliseconds: 2500),
      ));


      final response = await dio.get('https://open.er-api.com/v6/latest/IDR');

      if (response.statusCode == 200 && response.data != null) {
        final ratesFromApi = response.data['rates'] as Map<String, dynamic>;


        final fetched = <String, double>{'IDR': 1.0};
        for (final currency in ['USD', 'SGD', 'EUR', 'SAR']) {
          final rateAgainstIDR = ratesFromApi[currency];
          if (rateAgainstIDR != null && rateAgainstIDR > 0) {
            fetched[currency] = 1.0 / (rateAgainstIDR as num).toDouble();
          } else {
            fetched[currency] = _staticRates[currency]!;
          }
        }

        _currentRates = fetched;
        _isUsingRealtime = true;
        await _saveToCache(fetched);
        return _currentRates;
      }
    } catch (e) {

      _isUsingRealtime = false;
    }


    _currentRates = Map.from(_staticRates);
    _isUsingRealtime = false;
    return _currentRates;
  }




  double convertToIdr(double amount, String currency) {
    final rate = _currentRates[currency] ?? _staticRates[currency] ?? 1.0;
    return amount * rate;
  }




  Future<void> _saveToCache(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(rates));
    await prefs.setInt(
        _cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<Map<String, double>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_cacheTimestampKey);
      if (ts == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheDuration.inMilliseconds) return null;

      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }


  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }
}
