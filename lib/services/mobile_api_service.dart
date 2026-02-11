import '../core/network/dio_client.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/storage_service.dart';
import 'package:dio/dio.dart';

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
  Future<String?> uploadFile(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      final response = await _client.post('/upload', data: formData);
      return response
          .data; // Returns the server path (e.g., /uploads/image-123.jpg)
    } catch (e) {
      return null;
    }
  }

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

  Future<List<dynamic>> getInwards({
    String? startDate,
    String? endDate,
    String? fromParty,
    String? lotName,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.inward,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (fromParty != null) 'fromParty': fromParty,
          if (lotName != null) 'lotName': lotName,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getOutwards({
    String? startDate,
    String? endDate,
    String? lotName,
    String? lotNo,
    String? dia,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.outward,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (lotName != null) 'lotName': lotName,
          if (lotNo != null) 'lotNo': lotNo,
          if (dia != null) 'dia': dia,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  // --- Reports ---
  Future<List<dynamic>> getLotAgingReport({
    String? lotNo,
    String? lotName,
    String? colour,
    String? dia,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.agingReport,
        queryParameters: {
          if (lotNo != null) 'lotNo': lotNo,
          if (lotName != null) 'lotName': lotName,
          if (colour != null) 'colour': colour,
          if (dia != null) 'dia': dia,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getOverviewReport({
    String? startDate,
    String? endDate,
    String? lotNo,
    String? lotName,
    String? status,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.overviewReport,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (lotNo != null) 'lotNo': lotNo,
          if (lotName != null) 'lotName': lotName,
          if (status != null && status != 'All') 'status': status,
        },
      );
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

  Future<List<dynamic>> getMonthlyReport({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.monthlyReport,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
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
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to create Party';
    } catch (e) {
      throw e.toString();
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
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to create Item Group';
    } catch (e) {
      throw e.toString();
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

  Future<String?> generateInwardNumber() async {
    try {
      final response = await _client.get('${ApiConstants.inward}/generate-no');
      return response.data['inwardNo'];
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

  // --- AI Color Prediction ---
  Future<Map<String, dynamic>?> predictColor({
    required String fabricType,
    required double fabricGSM,
    required String dyeType,
    required double dyePercentage,
    required List<String> dyeNames,
    required double saltPercentage,
    required double sodaAshPercentage,
    required double aceticAcidPercentage,
    List<String> otherChemicals = const [],
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.colorPredict,
        data: {
          'fabricType': fabricType,
          'fabricGSM': fabricGSM,
          'dyeType': dyeType,
          'dyePercentage': dyePercentage,
          'dyeNames': dyeNames,
          'saltPercentage': saltPercentage,
          'sodaAshPercentage': sodaAshPercentage,
          'aceticAcidPercentage': aceticAcidPercentage,
          'otherChemicals': otherChemicals,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- AI Image Color Detection ---
  Future<Map<String, dynamic>?> detectColorFromImage(
    String imageBase64, {
    List<String> existingColors = const [],
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.colorPredictFromImage,
        data: {'imageBase64': imageBase64, 'existingColors': existingColors},
      );
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
      print('Color detect: status=${response.statusCode}');
      return null;
    } catch (e) {
      print('Color detect error: $e');
      return null;
    }
  }
}
