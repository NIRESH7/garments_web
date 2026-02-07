import 'dart:convert';
import 'package:http/http.dart' as http;
// import '../core/constants/api_constants.dart'; // Removed broken import

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

  // --- Colours by Lot ---
  Future<List<String>> getColoursByLot(String lotName) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/items/colours?lot_name=$lotName'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['colours']);
      }
      return [];
    } catch (e) {
      print('Error fetching colours mainly: $e');
      return [];
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

  // --- Items (New) ---
  Future<bool> saveItems(List<Map<String, dynamic>> items) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/items'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(items),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving items: $e');
      return false;
    }
  }

  // --- Allocation (New) ---
  Future<bool> saveAllocation(List<Map<String, dynamic>> allocations) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/inward/allocation'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(allocations),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving allocation: $e');
      return false;
    }
  }

  // --- DC Generator ---
  Future<String?> generateDcNumber() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/generate-dc-number'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['dc_number'];
      }
      return null;
    } catch (e) {
      print('Error generating DC number: $e');
      return null;
    }
  }

  // --- FIFO Lots ---
  Future<List<String>> getLotsFifo({String? dia}) async {
    try {
      final url = dia != null ? '$baseUrl/api/lots/fifo?dia=$dia' : '$baseUrl/api/lots/fifo';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['lots']);
      }
      return [];
    } catch (e) {
      print('Error fetching FIFO lots: $e');
      return [];
    }
  }

  // --- Party Details ---
  Future<Map<String, dynamic>?> getPartyDetails(String name) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/parties/$name'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching party details: $e');
      return null;
    }
  }

  Future<bool> saveParty(Map<String, dynamic> partyData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parties'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(partyData),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error saving party: $e');
      return false;
    }
  }

  // --- Balanced Sets ---
  Future<List<Map<String, dynamic>>> getBalancedSets(String lotNumber, String dia) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/lots/$lotNumber/dias/$dia/sets/balance'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['sets']);
      }
      return [];
    } catch (e) {
      print('Error fetching balanced sets: $e');
      return [];
    }
  }

  // --- DC Print PDF ---
  Future<List<int>?> generateDcPrint(Map<String, dynamic> dcData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate-dc-print'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(dcData),
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print('Error generating DC print: $e');
      return null;
    }
  }
}
