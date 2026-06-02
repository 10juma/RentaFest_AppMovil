import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _token;

  static Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static bool get hasToken => _token != null;

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
      // Identifica la plataforma para que el backend pueda ajustar restricciones.
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
    };
  }

  static Future<http.Response> post(String url, Map<String, dynamic> body) async {
    return await http.post(
      Uri.parse(url),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> get(String url) async {
    return await http.get(
      Uri.parse(url),
      headers: _getHeaders(),
    );
  }

  static Future<http.Response> put(String url, Map<String, dynamic> body) async {
    return await http.put(
      Uri.parse(url),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String url) async {
    return await http.delete(
      Uri.parse(url),
      headers: _getHeaders(),
    );
  }
}
