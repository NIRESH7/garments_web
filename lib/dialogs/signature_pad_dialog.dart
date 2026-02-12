import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({super.key});

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.isNotEmpty) {
      final Uint8List? data = await _controller.toPngBytes();
      if (data != null) {
        // Use XFile.fromData to support both Web and Mobile without path_provider
        final xFile = XFile.fromData(
          data,
          mimeType: 'image/png',
          name: 'signature_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        
        if (mounted) {
          Navigator.pop(context, xFile);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate precise width: 90% of screen or max 600px
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = (screenWidth * 0.9).clamp(0.0, 600.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0EA5E9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "E-Signature",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(
              height: 300,
              width: dialogWidth,
              color: Colors.white,
              // Signature widget now receives strict finite width
              child: Signature(
                controller: _controller,
                backgroundColor: Colors.white,
                width: dialogWidth,
                height: 300,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _controller.clear(),
                    icon: const Icon(Icons.clear, color: Colors.red),
                    label: const Text("Clear", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text("Save Signature"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22C55E),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
