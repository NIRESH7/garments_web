import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';

class PartyMasterScreen extends StatefulWidget {
  const PartyMasterScreen({super.key});

  @override
  State<PartyMasterScreen> createState() => _PartyMasterScreenState();
}

class _PartyMasterScreenState extends State<PartyMasterScreen> {
  final _db = DatabaseService();
  final _nameController = TextEditingController();

  Future<void> _save() async {
    if (_nameController.text.isEmpty) return;
    final db = await _db.database;
    await db.insert('dropdowns', {
      'id': const Uuid().v4(),
      'category': 'party_name',
      'value': _nameController.text,
    });
    _nameController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Party saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Party Master')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Party Name'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _save, child: const Text('Save Party')),
          ],
        ),
      ),
    );
  }
}
