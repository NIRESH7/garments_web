import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
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
  MediaType _inferMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.mp3')) return MediaType('audio', 'mpeg');
    if (lower.endsWith('.wav')) return MediaType('audio', 'wav');
    if (lower.endsWith('.aac')) return MediaType('audio', 'aac');
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) {
      return MediaType('audio', 'mp4');
    }
    if (lower.endsWith('.webm')) return MediaType('audio', 'webm');
    if (lower.endsWith('.caf')) return MediaType('audio', 'caf');
    return MediaType('application', 'octet-stream');
  }

  bool _isMediaField(String key) {
    final lower = key.toLowerCase();
    return lower.contains('image') ||
        lower.contains('signature') ||
        lower.contains('photo') ||
        lower.contains('audio');
  }

  bool _looksLikeLocalFilePath(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (v.startsWith('http://') || v.startsWith('https://')) return false;
    if (v.startsWith('uploads/') || v.startsWith('/uploads/')) return false;
    if (v.startsWith('file://')) return true;
    if (v.startsWith('/data/') ||
        v.startsWith('/storage/') ||
        v.startsWith('/private/') ||
        v.startsWith('/var/mobile/') ||
        v.startsWith('/Users/') ||
        v.contains('Android/data/') ||
        v.contains('/Caches/') ||
        v.contains('/cache/') ||
        v.contains('/tmp/')) {
      return true;
    }
    return false;
  }

  Future<String?> uploadImage(dynamic file) async {
    try {
      XFile xFile;
      if (file is XFile) {
        xFile = file;
      } else if (file is String) {
        xFile = XFile(file);
      } else {
        return null;
      }

      final fileName = xFile.path.split('/').last;
      final bytes = await xFile.readAsBytes();

      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: _inferMediaType(fileName),
        ),
      });
      final response = await _client.post(ApiConstants.upload, data: formData);
      return response.data; // Returns /uploads/filename...
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadFile(String path) async {
    return uploadImage(path);
  }

  Future<String?> uploadAudio(String path) async {
    return uploadImage(path);
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
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue; // Never send local device path to backend.
          }
          formData.fields.add(MapEntry(entry.key, value));
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
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue; // Never send local device path to backend.
          }
          formData.fields.add(MapEntry(entry.key, value));
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

  Future<Map<String, dynamic>> importInwardExcel(
    XFile file,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: file.name,
        ),
      });

      final response = await _client.post(
        ApiConstants.inwardImport,
        data: formData,
      );

      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {};
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception(e.message ?? 'Import failed');
    } catch (e) {
      throw Exception('Import failed: $e');
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

  Future<bool> deleteInward(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.inward}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateInward(String id, Map<String, dynamic> data) async {
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
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue; // Never send local device path to backend.
          }
          formData.fields.add(MapEntry(entry.key, value));
        }
      }

      final response = await _client.put(
        '${ApiConstants.inward}/$id',
        data: formData,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Failed to update inward: $e');
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

  Future<bool> deleteOutward(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.outward}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateOutward(String id, Map<String, dynamic> data) async {
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
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue; // Never send local device path to backend.
          }
          formData.fields.add(MapEntry(entry.key, value));
        }
      }

      final response = await _client.put(
        '${ApiConstants.outward}/$id',
        data: formData,
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Failed to update outward: $e');
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

  Future<List<dynamic>> getInventoryDrillDown({
    required String type,
    String? lotName,
    String? lotNo,
    String? dia,
    String? setNo,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.inventoryDrillDown,
        queryParameters: {
          'type': type,
          if (lotName != null) 'lotName': lotName,
          if (lotNo != null) 'lotNo': lotNo,
          if (dia != null) 'dia': dia,
          if (setNo != null) 'setNo': setNo,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
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

  Future<List<dynamic>> getRackPalletStockReport({
    String? rackName,
    String? palletNo,
    String? lotName,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.rackPalletStockReport,
        queryParameters: {
          if (rackName != null) 'rackName': rackName,
          if (palletNo != null) 'palletNo': palletNo,
          if (lotName != null) 'lotName': lotName,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  // --- Production ---
  Future<List<dynamic>> getAssignments({DateTime? date}) async {
    try {
      Map<String, dynamic> query = {};
      if (date != null) {
        query['date'] = date.toIso8601String().split('T')[0];
      }
      final response = await _client.get(
        ApiConstants.assignments,
        queryParameters: query,
      );
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

  Future<bool> deleteAssignment(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.assignments}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAssignment(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        '${ApiConstants.assignments}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Cutting Master ---
  Future<List<dynamic>> getCuttingMasters() async {
    try {
      final response = await _client.get(ApiConstants.cuttingMaster);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCuttingMasterById(String id) async {
    try {
      final response = await _client.get('${ApiConstants.cuttingMaster}/$id');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> createCuttingMaster(
      Map<String, dynamic> data) async {
    try {
      final formData = FormData();
      for (var entry in data.entries) {
        if (entry.value is XFile) {
          final file = entry.value as XFile;
          final bytes = await file.readAsBytes();
          final String fName = file.name ?? '';
          final String fileName = fName.isNotEmpty
              ? fName
              : (file.path ?? '').split('/').last;
          formData.files.add(MapEntry(
            entry.key,
            MultipartFile.fromBytes(
              bytes,
              filename: fileName,
              contentType: _inferMediaType(fileName),
            ),
          ));
        } else if (entry.value is List || entry.value is Map) {
          formData.fields
              .add(MapEntry(entry.key, jsonEncode(entry.value)));
        } else if (entry.value != null) {
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue;
          }
          formData.fields.add(MapEntry(entry.key, value));
        }
      }
      final response = await _client.post(
        ApiConstants.cuttingMaster,
        data: formData,
      );
      if (response.statusCode == 201) return response.data;
      return null;
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Failed to create cutting master: $e');
    }
  }

  Future<Map<String, dynamic>?> updateCuttingMaster(
      String id, Map<String, dynamic> data) async {
    try {
      final formData = FormData();
      for (var entry in data.entries) {
        if (entry.value is XFile) {
          final file = entry.value as XFile;
          final bytes = await file.readAsBytes();
          final fileName = file.name.isNotEmpty
              ? file.name
              : file.path.split('/').last;
          formData.files.add(MapEntry(
            entry.key,
            MultipartFile.fromBytes(
              bytes,
              filename: fileName,
              contentType: _inferMediaType(fileName),
            ),
          ));
        } else if (entry.value is List || entry.value is Map) {
          formData.fields
              .add(MapEntry(entry.key, jsonEncode(entry.value)));
        } else if (entry.value != null) {
          final value = entry.value.toString();
          if (_isMediaField(entry.key) && _looksLikeLocalFilePath(value)) {
            continue;
          }
          formData.fields.add(MapEntry(entry.key, value));
        }
      }
      final response = await _client.put(
        '${ApiConstants.cuttingMaster}/$id',
        data: formData,
      );
      if (response.statusCode == 200) return response.data;
      return null;
    } on DioException catch (e) {
      final errorMsg = e.response?.data != null && e.response?.data is Map
          ? (e.response?.data['message'] ?? e.message)
          : e.message;
      throw Exception(errorMsg);
    } catch (e) {
      throw Exception('Failed to update cutting master: $e');
    }
  }

  Future<bool> deleteCuttingMaster(String id) async {
    try {
      final response =
          await _client.delete('${ApiConstants.cuttingMaster}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Accessories Master ---
  Future<List<dynamic>> getAccessoriesMasters() async {
    try {
      final response = await _client.get(ApiConstants.accessoriesMaster);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getAccessoriesMasterById(String id) async {
    try {
      final response = await _client.get('${ApiConstants.accessoriesMaster}/$id');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createAccessoriesMaster(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        ApiConstants.accessoriesMaster,
        data: data,
      );
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateAccessoriesMaster(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        '${ApiConstants.accessoriesMaster}/$id',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAccessoriesMaster(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.accessoriesMaster}/$id');
      return response.statusCode == 200;
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
      if (response.data is List) {
        return response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        return response.data['data'];
      }
      return [];
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
    String? knittingDia,
    String? cuttingDia,
    String? sizeType,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConstants.categories}/$categoryId/values',
        data: {
          'name': name,
          'photo': photo,
          'gsm': gsm,
          'knittingDia': knittingDia,
          'cuttingDia': cuttingDia,
          'sizeType': sizeType,
        },
      );
      return response.statusCode == 201;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to add value';
    } catch (e) {
      throw e.toString();
    }
  }

  Future<bool> updateCategoryValue(
    String categoryId,
    String oldValueName,
    String newName, {
    String? photo,
    String? gsm,
    String? knittingDia,
    String? cuttingDia,
    String? sizeType,
  }) async {
    try {
      final response = await _client.put(
        '${ApiConstants.categories}/$categoryId/values/$oldValueName',
        data: {
          'name': newName,
          'photo': photo,
          'gsm': gsm,
          'knittingDia': knittingDia,
          'cuttingDia': cuttingDia,
          'sizeType': sizeType,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to update value';
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
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getDistinctLots() async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/distinct-lots',
      );
      return response.data ?? [];
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
      return response.statusCode == 201 || response.statusCode == 200;
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

  Future<List<String>> getLotsFifo({required String dia, String? lotName}) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/fifo',
        queryParameters: {
          'dia': dia,
          if (lotName != null) 'lotName': lotName,
        },
      );
      return List<String>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBalancedSets(
    String lotNo,
    String dia, {
    String? excludeId,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/balanced-sets',
        queryParameters: {
          'lotNo': lotNo,
          'dia': dia,
          if (excludeId != null) 'excludeId': excludeId,
          '_t': DateTime.now().millisecondsSinceEpoch, // Force fresh fetch
        },
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getLotDetails(String lotName, String lotNo) async {
    try {
      final response = await _client.get(
        '${ApiConstants.inward}/lot-details',
        queryParameters: {'lotName': lotName, 'lotNo': lotNo},
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> checkFifoViolation(
    String currentLotNo,
    String dia,
    String setNo,
  ) async {
    try {
      final response = await _client.get(
        '${ApiConstants.outward}/check-fifo',
        queryParameters: {
          'currentLotNo': currentLotNo,
          'dia': dia,
          'setNo': setNo,
        },
      );
      return response.data;
    } catch (e) {
      return null;
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
      final response = await _client.get(
        '${ApiConstants.itemGroups}/by-name',
        queryParameters: {'name': name},
      );
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- AI Chat ---
  Future<Map<String, dynamic>> chatWithAI(
    String message, {
    String language = 'en',
  }) async {
    try {
      final response = await _client.post(
        ApiConstants.aiChat,
        data: {'message': message, 'language': language},
      );
      return response.data;
    } catch (e) {
      return {
        'text': 'Sorry, I am having trouble connecting to my brain right now.',
      };
    }
  }

  Future<String?> transcribeAudioFile(String path, {String? language}) async {
    try {
      final fileName = path.split('/').last;
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          path,
          filename: fileName,
          contentType: _inferMediaType(fileName),
        ),
        if (language != null && language.isNotEmpty) 'language': language,
      });
      final response = await _client.post(
        ApiConstants.aiTranscribe,
        data: formData,
      );
      final text = response.data is Map ? response.data['text'] : null;
      if (text == null) {
        print('Transcribe response missing text: ${response.data}');
      }
      if (text == null) return null;
      final parsed = text.toString().trim();
      if (parsed.isEmpty) {
        print('Transcribe returned empty text');
      }
      return parsed.isEmpty ? null : parsed;
    } on DioException catch (e) {
      print(
        'Transcribe failed: status=${e.response?.statusCode}, data=${e.response?.data}, message=${e.message}',
      );
      return null;
    } catch (e) {
      print('Transcribe exception: $e');
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

  // --- Generic Generic API Helpers ---
  Future<dynamic> get(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _client.get(url, queryParameters: queryParameters);
    return response.data;
  }

  Future<dynamic> post(String url, dynamic data) async {
    final response = await _client.post(url, data: data);
    return response.data;
  }

  Future<dynamic> put(String url, dynamic data) async {
    final response = await _client.put(url, data: data);
    return response.data;
  }

  Future<dynamic> delete(String url) async {
    final response = await _client.delete(url);
    return response.data;
  }

  Future<bool> saveCuttingOrder(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
        ApiConstants.cuttingOrders,
        data: data,
      );
      return response.statusCode == 201;
    } catch (e) {
      print('Save Cutting Order Error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getCuttingOrders() async {
    try {
      final response = await _client.get(ApiConstants.cuttingOrders);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCuttingOrderById(String id) async {
    try {
      final response = await _client.get('${ApiConstants.cuttingOrders}/$id');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateCuttingOrder(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put(
        '${ApiConstants.cuttingOrders}/$id',
        data: data,
      );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (e) {
      print('Update Cutting Order Error: $e');
      return false;
    }
  }

  Future<bool> deleteCuttingOrder(String id) async {
    try {
      final response = await _client.delete(
        '${ApiConstants.cuttingOrders}/$id',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Delete Cutting Order Error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getFifoAllocation(
    String itemName,
    String size,
    double dozen,
    String dia,
    double dozenWeight, {
    String? lotName,
    List<String>? excludedSets,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.fifoAllocation,
        queryParameters: {
          if (lotName != null) 'lotName': lotName,
          'itemName': itemName,
          'size': size,
          'dozen': dozen,
          'dia': dia,
          'dozenWeight': dozenWeight,
          if (excludedSets != null && excludedSets.isNotEmpty)
            'excludedSets': excludedSets.join(','),
        },
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> saveLotAllocation(
    String planId,
    List<Map<String, dynamic>> lotAllocations, {
    String? day,
    String? date,
    String? itemName,
    String? size,
    double? dozen,
    double? neededWeight,
    bool postOutward = false,
  }) async {
    try {
      final response = await _client.post(
        '${ApiConstants.allocateLots}/$planId/allocate',
        data: {
          'lotAllocations': lotAllocations,
          if (day != null) 'day': day,
          if (date != null) 'date': date,
          if (itemName != null) 'itemName': itemName,
          if (size != null) 'size': size,
          if (dozen != null) 'dozen': dozen,
          if (neededWeight != null) 'neededWeight': neededWeight,
          'postOutward': postOutward,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getAllocationReport(
    String planId, {
    String? day,
    String? date,
  }) async {
    try {
      final response = await _client.get(
        '${ApiConstants.allocateLots}/$planId/allocation-report',
        queryParameters: {
          if (day != null) 'day': day,
          if (date != null) 'date': date,
        },
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteLotAllocation(String planId, String allocationId) async {
    try {
      final response = await _client.delete(
        '${ApiConstants.allocateLots}/$planId/allocation/$allocationId',
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateLotAllocation(
    String planId,
    String allocationId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.put(
        '${ApiConstants.allocateLots}/$planId/allocation/$allocationId',
        data: data,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getPreviousPlanningEntries(
    String planName, {
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.previousPlanningEntries,
        queryParameters: {
          'planName': planName,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getCuttingPlanReport({
    String? startDate,
    String? endDate,
    String? itemName,
    String? size,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.cuttingPlanReport,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (itemName != null) 'itemName': itemName,
          if (size != null) 'size': size,
        },
      );
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getAllAllocationsByDate(String date) async {
    try {
      final response = await _client.get(
        ApiConstants.allAllocationsByDate,
        queryParameters: {'date': date},
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getTasks() async {
    try {
      final response = await _client.get(ApiConstants.tasks);
      return response.data;
    } catch (e) {
      return [];
    }
  }

  Future<dynamic> createTask(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.tasks, data: data);
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<dynamic> addTaskReply(
    String taskId,
    Map<String, dynamic> data, {
    String? voicePath,
  }) async {
    try {
      if (voicePath != null) {
        final voiceUrl = await uploadAudio(voicePath);
        if (voiceUrl != null) {
          data['voiceReplyUrl'] = voiceUrl;
        }
      }
      final response = await _client.post(
        '${ApiConstants.tasks}/$taskId/reply',
        data: data,
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      final response = await _client.put(
        '${ApiConstants.tasks}/$taskId/status',
        data: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTask(String taskId) async {
    try {
      final response = await _client.delete('${ApiConstants.tasks}/$taskId');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─── NEW MODULE API METHODS ─────────────────────────────────────────────────

  // Cutting Entry (Page 1)
  Future<bool> createCuttingEntry(Map<String, dynamic> data) async {
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
      final response =
          await _client.post(ApiConstants.cuttingEntry, data: formData);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getCuttingEntries({
    String? startDate,
    String? endDate,
    String? itemName,
    String? size,
    String? cutNo,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.cuttingEntry,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (itemName != null) 'itemName': itemName,
          if (size != null) 'size': size,
          if (cutNo != null) 'cutNo': cutNo,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCuttingEntryById(String id) async {
    try {
      final response = await _client.get('${ApiConstants.cuttingEntry}/$id');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateCuttingEntry(String id, Map<String, dynamic> data) async {
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
      final response = await _client.put(
        '${ApiConstants.cuttingEntry}/$id',
        data: formData,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCuttingEntry(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.cuttingEntry}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Cutting Entry Page 2
  Future<bool> saveCuttingEntryPage2(String entryId, Map<String, dynamic> data) async {
    try {
      final response = await _client.post(
          '${ApiConstants.cuttingEntry}/$entryId/page2',
          data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getCuttingEntryPage2(String entryId) async {
    try {
      final response = await _client
          .get('${ApiConstants.cuttingEntry}/$entryId/page2');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // Cut Stock Report
  Future<List<dynamic>> getCutStockReport({
    String? startDate,
    String? endDate,
    String? itemName,
    String? size,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.cuttingEntryReportCutStock,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (itemName != null) 'itemName': itemName,
          if (size != null) 'size': size,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  // Cutting Entry Report
  Future<List<dynamic>> getCuttingEntryReport({
    String? startDate,
    String? endDate,
    String? cutNo,
    String? itemName,
    String? size,
    String? colour,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.cuttingEntryReportList,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (cutNo != null) 'cutNo': cutNo,
          if (itemName != null) 'itemName': itemName,
          if (size != null) 'size': size,
          if (colour != null) 'colour': colour,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  // Stitching Delivery
  Future<bool> createStitchingDelivery(Map<String, dynamic> data) async {
    try {
      final response =
          await _client.post(ApiConstants.stitchingDelivery, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getStitchingDeliveries({
    String? startDate,
    String? endDate,
    String? itemName,
    String? cutNo,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.stitchingDelivery,
        queryParameters: {
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
          if (itemName != null) 'itemName': itemName,
          if (cutNo != null) 'cutNo': cutNo,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStitchingDeliveryById(String id) async {
    try {
      final response =
          await _client.get('${ApiConstants.stitchingDelivery}/$id');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateStitchingDelivery(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put('${ApiConstants.stitchingDelivery}/$id',
          data: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Cutting Daily Plan
  Future<bool> createCuttingDailyPlan(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.cuttingDailyPlan, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getCuttingDailyPlans({String? date}) async {
    try {
      final response = await _client.get(
        ApiConstants.cuttingDailyPlan,
        queryParameters: {if (date != null) 'date': date},
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> updateCuttingDailyPlan(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client
          .put('${ApiConstants.cuttingDailyPlan}/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Stitching GRN
  Future<bool> createStitchingGrn(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(ApiConstants.stitchingGrn, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getStitchingGrns({
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.stitchingGrn,
        queryParameters: {
          if (type != null) 'type': type,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  // Iron & Packing DC
  Future<bool> createIronPackingDc(Map<String, dynamic> data) async {
    try {
      final response =
          await _client.post(ApiConstants.ironPackingDc, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getIronPackingDcs({
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _client.get(
        ApiConstants.ironPackingDc,
        queryParameters: {
          if (type != null) 'type': type,
          if (startDate != null) 'startDate': startDate,
          if (endDate != null) 'endDate': endDate,
        },
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  // Accessories Item Assignment
  Future<bool> saveAccessoriesItemAssign(Map<String, dynamic> data) async {
    try {
      final response =
          await _client.post(ApiConstants.accessoriesItemAssign, data: data);
      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getAccessoriesItemAssigns({String? itemName}) async {
    try {
      final response = await _client.get(
        ApiConstants.accessoriesItemAssign,
        queryParameters: {if (itemName != null) 'itemName': itemName},
      );
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  // --- Stock Limits ---
  Future<bool> deleteStockLimit(String id) async {
    try {
      final response = await _client.delete('${ApiConstants.stockLimits}/$id');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateStockLimit(String id, Map<String, dynamic> data) async {
    try {
      final response = await _client.put('${ApiConstants.stockLimits}/$id', data: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- Dashboard Dependencies ---
  Future<List<dynamic>> fetchCuttingPlanningDraftList() async {
    return getCuttingOrders();
  }

  Future<List<dynamic>> fetchItemAssignments() async {
    try {
      final response = await _client.get(ApiConstants.assignments);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchFabricInventory() async {
    try {
      final response = await _client.get(ApiConstants.inward);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getLotMasters() async {
    try {
      final response = await _client.get(ApiConstants.lots);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getItemGroupMasters() async {
    try {
      final response = await _client.get(ApiConstants.itemGroups);
      return response.data ?? [];
    } catch (e) {
      return [];
    }
  }
}

