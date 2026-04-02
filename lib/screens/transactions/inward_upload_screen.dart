import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';
import '../../widgets/app_drawer.dart';

class InwardUploadScreen extends StatefulWidget {
  const InwardUploadScreen({super.key});

  @override
  State<InwardUploadScreen> createState() => _InwardUploadScreenState();
}

class _InwardUploadScreenState extends State<InwardUploadScreen> {
  final MobileApiService _api = MobileApiService();
  XFile? _selectedFile;
  String? _selectedFileName;
  bool _isUploading = false;
  Map<String, dynamic>? _result;
  Future<void> _pickFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls'],
        withData: true, // Required for web to get bytes
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;
      setState(() {
        if (kIsWeb) {
          _selectedFile = XFile.fromData(
            file.bytes!,
            name: file.name,
          );
        } else {
          _selectedFile = XFile(file.path!);
        }
        _selectedFileName = file.name;
        _result = null;
      });
    } catch (e) {
      _showMessage('Failed to pick file: $e', isError: true);
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null) {
      _showMessage('Please select an Excel file first.', isError: true);
      return;
    }

    setState(() => _isUploading = true);
    try {
      final result = await _api.importInwardExcel(_selectedFile!);
      if (!mounted) return;
      setState(() => _result = result);

      final imported = result['imported'] ?? 0;
      final failed = result['failed'] ?? 0;
      final skipped = result['skipped'] ?? 0;
      _showMessage(
        'Upload finished: Imported $imported, Failed $failed, Skipped $skipped',
      );
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildResultSection() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final totalSheets = result['totalSheets'] ?? 0;
    final imported = result['imported'] ?? 0;
    final failed = result['failed'] ?? 0;
    final skipped = result['skipped'] ?? 0;
    final rows = (result['results'] as List?) ?? const [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Result',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Sheets: $totalSheets'),
            Text('Imported: $imported'),
            Text('Failed: $failed'),
            Text('Skipped: $skipped'),
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final item = rows[i] as Map<String, dynamic>;
                    final status = (item['status'] ?? '').toString();
                    final color = status == 'imported'
                        ? Colors.green
                        : status == 'failed'
                        ? Colors.red
                        : Colors.orange;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['sheet']?.toString() ?? 'Sheet'),
                      subtitle: Text(
                        item['message']?.toString() ??
                            item['error']?.toString() ??
                            '${item['lotNo'] ?? ''} ${item['lotName'] ?? ''}'
                                .trim(),
                      ),
                      trailing: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'Inward Upload',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload LOT inward Excel file',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This uses the same backend flow as manual inward save.',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        _selectedFileName == null
                            ? 'No file selected'
                            : 'Selected: $_selectedFileName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploading ? null : _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Select File'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _upload,
                            icon: _isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.upload_file),
                            label: Text(
                              _isUploading ? 'Uploading...' : 'Upload',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildResultSection(),
          ],
        ),
      ),
    );
  }
}
