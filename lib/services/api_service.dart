import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart'; // You might want to create this or hardcode for now

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for Web/iOS Simulator
  // Since user is running on Chrome (Web), localhost is fine.
  static const String baseUrl = 'http://127.0.0.1:8000'; 

  // --- Master Data ---
  Future<Map<String, List<String>>> getMasterData() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/master-data'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'lots': List<String>.from(data['lots']),
          'parties': List<String>.from(data['parties']),
          'dias': List<String>.from(data['dias']),
          'colours': List<String>.from(data['colours']),
          'racks': List<String>.from(data['racks']),
          'pallets': List<String>.from(data['pallets']),
        };
      } else {
        throw Exception('Failed to load master data');
      }
    } catch (e) {
      print('Error fetching master data: $e');
      return {};
    }
  }

  // --- Inward ---
  Future<bool> saveInward(Map<String, dynamic> inwardData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inward'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(inwardData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving inward: $e');
      return false;
    }
  }

  // --- Outward ---
  Future<bool> saveOutward(Map<String, dynamic> outwardData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/outward'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(outwardData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving outward: $e');
      return false;
    }
  }
}
