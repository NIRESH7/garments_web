import 'dart:async';
import 'package:uuid/uuid.dart';

// MOCK DATABASE SERVICE FOR WEB/DEMO
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static final MockDatabase _mockDb = MockDatabase();

  Future<MockDatabase> get database async {
    return _mockDb;
  }
}

class MockDatabase {
  // In-memory storage: Table Name -> List of Rows
  final Map<String, List<Map<String, dynamic>>> _data = {
    'categories': [
      {'id': '1', 'name': 'Lot Name'},
      {'id': '2', 'name': 'Dia'},
      {'id': '3', 'name': 'Colour'},
      {'id': '4', 'name': 'Size'},
      {'id': '5', 'name': 'Set'},
      {'id': '6', 'name': 'Process'},
      {'id': '7', 'name': 'Efficiency'},
      {'id': '8', 'name': 'Item Name'},
      {'id': '9', 'name': 'GSM'},
    ],
    'dropdowns': [],
    'parties': [],
    'items': [],
    'lots': [],
  };

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (!_data.containsKey(table)) {
      _data[table] = [];
    }
    
    List<Map<String, dynamic>> result = List.from(_data[table]!);

    // Simple WHERE filtering
    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      if (where.contains('category = ?')) {
        final category = whereArgs[0] as String;
        result = result.where((row) => row['category'] == category).toList();
      } else if (where.contains('name = ?')) {
        final name = whereArgs[0] as String;
        result = result.where((row) => row['name'] == name).toList();
      } else if (where.contains('id = ?')) {
         final id = whereArgs[0] as String;
         result = result.where((row) => row['id'] == id).toList();
      }
    }

    // Simple OrderBy (basic string sorting on 'value')
    if (orderBy != null && orderBy.contains('value')) {
       result.sort((a, b) => (a['value'] as String).compareTo(b['value'] as String));
    }

    return result;
  }

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    dynamic conflictAlgorithm,
  }) async {
    if (!_data.containsKey(table)) {
      _data[table] = [];
    }
    _data[table]!.add(Map.from(values));
    return 1;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
     if (!_data.containsKey(table)) return 0;
     
     int initialLength = _data[table]!.length;
     
     if (where != null && whereArgs != null) {
       if (where.contains('id = ?')) {
         final id = whereArgs[0];
         _data[table]!.removeWhere((row) => row['id'] == id);
       }
     }
     
     return initialLength - _data[table]!.length;
  }
  
  // Mock rawQuery to prevent crashes in reports/dashboard
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    // Simple mock for COUNT(*) queries
    if (sql.contains('COUNT(*)')) {
      // Extract table name roughly
      for (var table in _data.keys) {
        if (sql.contains(table)) {
           return [{'count': _data[table]!.length}];
        }
      }
      return [{'count': 0}];
    }
    
    // Default empty return for other complex queries to unblock UI
    return [];
  }

  // No-op execute
  Future<void> execute(String sql) async {}
}

