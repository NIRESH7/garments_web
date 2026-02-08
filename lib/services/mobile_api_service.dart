import '../core/network/dio_client.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/storage_service.dart';

class MobileApiService {
  final DioClient _client = DioClient();
  final StorageService _storage = StorageService();

  // --- Auth ---
  Future<bool> login(String email, String password) async {
    try {
      final response = await _client.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      if (response.statusCode == 200) {
        final token = response.data['token'];
        await _storage.saveToken(token);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- Home ---
  Future<Map<String, dynamic>> getHomeDashboard() async {
    try {
      final response = await _client.get(ApiConstants.home);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // --- Inventory ---
  Future<bool> saveInward(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.inward, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveOutward(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.outward, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- Reports ---
  Future<List<dynamic>> getLotAgingReport() async {
    try {
      final response = await _client.get(ApiConstants.agingReport);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getOverviewReport() async {
    try {
      final response = await _client.get(ApiConstants.overviewReport);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getInwardOutwardReport() async {
    try {
      final response = await _client.get(ApiConstants.inwardOutwardReport);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getMonthlyReport() async {
    try {
      final response = await _client.get(ApiConstants.monthlyReport);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  // --- Production ---
  Future<List<dynamic>> getAssignments() async {
    try {
      final response = await _client.get(ApiConstants.assignments);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> createAssignment(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.assignments, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- Master ---
  Future<List<dynamic>> getParties() async {
    try {
      final response = await _client.get(ApiConstants.parties);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> createParty(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.parties, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _client.get(ApiConstants.categories);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> createCategory(String name) async {
    try {
      final response = await _client.post(
        ApiConstants.categories,
        data: {'name': name},
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.categories}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addCategoryValue(String categoryId, String value) async {
    try {
      final response = await _client.post(
        '${ApiConstants.categories}/$categoryId/values',
        data: {'value': value},
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCategoryValue(String categoryId, String value) async {
    try {
      final response = await _client.delete(
        '${ApiConstants.categories}/$categoryId/values/$value',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getItemGroups() async {
    try {
      final response = await _client.get(ApiConstants.itemGroups);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> createItemGroup(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.itemGroups, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getLots() async {
    try {
      final response = await _client.get(ApiConstants.lots);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> createLot(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.lots, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- Transaction Helpers ---
  Future<String?> generateDcNumber() async {
    try {
      final response = await _client.get('${ApiConstants.outward}/generate-dc');
      return response.data['dc_number'];
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getLotsFifo({required String dia}) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/fifo',
        queryParameters: {'dia': dia},
      );
      return List<String>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBalancedSets(
    String lotNo,
    String dia,
  ) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/balanced-sets',
        queryParameters: {'lotNo': lotNo, 'dia': dia},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPartyDetails(String name) async {
    try {
      final parties = await getParties();
      return parties.firstWhere((p) => p['name'] == name, orElse: () => null);
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getColoursByLot(String lotName) async {
    try {
      final groups = await getItemGroups();
      final group = groups.firstWhere(
        (g) => g['groupName'] == lotName,
        orElse: () => null,
      );
      if (group != null) {
        return List<String>.from(group['colours'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
