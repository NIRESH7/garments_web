import 'dart:io';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../core/constants/api_constants.dart';
import '../core/storage/storage_service.dart';

import 'dart:convert';
import 'package:image_picker/image_picker.dart';

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
        final role = response.data['role'] ?? 'lot_inward'; // Default fallback
        await _storage.saveToken(token);
        await _storage.saveRole(role);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- Home ---
  Future<Map<String, dynamic>> getHomeDashboard({
    String? startDate,
    String? endDate,
    String? lotName,
    String? dia,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.home,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (lotName != null) 'lotName': lotName,
          if (dia != null) 'dia': dia,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // --- Inventory ---
  Future<String?> uploadImage(File file) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await _client.post(ApiConstants.upload, data: formData);
      return response.data; // Returns /uploads/filename...
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadFile(String path) async {
    return uploadImage(File(path));
  }

  Future<bool> saveInward(Map<String, dynamic> data) async {
    try {
      final formData = FormData();

      for (var entry in data.entries) {
        if (entry.value is XFile) {
          final file = entry.value as XFile;
          // Read bytes to support both Web and Mobile consistently
          final bytes = await file.readAsBytes();

          formData.files.add(
            MapEntry(
              entry.key,
              MultipartFile.fromBytes(bytes, filename: file.name),
            ),
          );
        } else if (entry.value is List || entry.value is Map) {
          // Complex types must be JSON stringified for FormData text fields
          formData.fields.add(MapEntry(entry.key, jsonEncode(entry.value)));
        } else if (entry.value != null) {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }

      final response = await _client.post(ApiConstants.inward, data: formData);
      return response.statusCode == 201;
    } catch (e) {
      print('Save Inward Error: $e');
      return false;
    }
  }

  Future<bool> saveOutward(Map<String, dynamic> data) async {
    try {
      final formData = FormData();

      for (var entry in data.entries) {
        if (entry.value is XFile) {
          final file = entry.value as XFile;
          final bytes = await file.readAsBytes();
          formData.files.add(
            MapEntry(
              entry.key,
              MultipartFile.fromBytes(bytes, filename: file.name),
            ),
          );
        } else if (entry.value is List || entry.value is Map) {
          formData.fields.add(MapEntry(entry.key, jsonEncode(entry.value)));
        } else if (entry.value != null) {
          formData.fields.add(MapEntry(entry.key, entry.value.toString()));
        }
      }

      final response = await _client.post(ApiConstants.outward, data: formData);
      return response.statusCode == 201;
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Failed to save outward: $e');
    }
  }

  Future<List<dynamic>> getInwards({
    String? startDate,
    String? endDate,
    String? fromParty,
    String? lotName,
    String? lotNo,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.inward,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (fromParty != null) 'fromParty': fromParty,
          if (lotName != null) 'lotName': lotName,
          if (lotNo != null) 'lotNo': lotNo,
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
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.agingReport,
        queryParameters: {
          if (lotNo != null) 'lotNo': lotNo,
          if (lotName != null) 'lotName': lotName,
          if (colour != null) 'colour': colour,
          if (dia != null) 'dia': dia,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
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

  Future<Map<String, dynamic>?> getFifoRecommendation(
    String lotName,
    String dia,
  ) async {
    try {
      final response = await _client.get(
        ApiConstants.fifoRecommendation,
        queryParameters: {'lotName': lotName, 'dia': dia},
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateComplaintSolution(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.put(
        '${ApiConstants.inward}/$id/complaint-solution',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      throw e;
    }
  }

  Future<List<dynamic>> getQualityAuditReport({
    String? lotNo,
    bool? isCleared,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (lotNo != null) params['lotNo'] = lotNo;
      if (isCleared != null) params['isCleared'] = isCleared.toString();

      final response = await _client.get(
        ApiConstants.qualityAuditReport,
        queryParameters: params,
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getClientFormatReport({String? fromParty}) async {
    try {
      final response = await _client.get(
        ApiConstants.clientReport,
        queryParameters: {if (fromParty != null) 'fromParty': fromParty},
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getGodownStockReport({
    String? lotName,
    String? dia,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.godownStockReport,
        queryParameters: {
          if (lotName != null) 'lotName': lotName,
          if (dia != null) 'dia': dia,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getShadeCardReport() async {
    try {
      final response = await _client.get(ApiConstants.shadeCardReport);
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

  Future<bool> updateParty(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        '${ApiConstants.parties}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to update Party';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteParty(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.parties}/$id');
      return response.statusCode == 200;
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

  Future<bool> addCategoryValue(
    String categoryId,
    String name, {
    String? photo,
    String? gsm,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConstants.categories}/$categoryId/values',
        data: {'name': name, 'photo': photo, 'gsm': gsm},
      );
      return response.statusCode == 201;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to add value';
    } catch (e) {
      throw e.toString();
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

  Future<bool> updateItemGroup(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        '${ApiConstants.itemGroups}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to update Item Group';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> deleteItemGroup(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.itemGroups}/$id');
      return response.statusCode == 200;
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

  Future<List<dynamic>> getStockLimits() async {
    try {
      final response = await _client.get(ApiConstants.stockLimits);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveStockLimit(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.stockLimits, data: data);
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

  Future<List<String>> getColoursByLot(String lotNo) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/colours',
        queryParameters: {'lotNo': lotNo},
      );
      return List<String>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getItemGroupByName(String name) async {
    try {
      final groups = await getItemGroups();
      return groups.firstWhere(
        (g) => g['groupName'] == name,
        orElse: () => null,
      );
    } catch (e) {
      return null;
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

  // --- Notifications ---
  Future<List<dynamic>> getNotifications() async {
    try {
      final response = await _client.get(ApiConstants.notifications);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<bool> markNotificationAsRead(String id) async {
    try {
      final response = await _client.put('${ApiConstants.notifications}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    try {
      // Assuming a bulk delete or mark all as read endpoint
      final response = await _client.put('${ApiConstants.notifications}/clear');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
