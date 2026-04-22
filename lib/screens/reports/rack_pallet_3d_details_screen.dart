import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// Conditional import for web only
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

import '../../services/mobile_api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/storage_service.dart';

class RackPallet3DDetailsScreen extends StatefulWidget {
  const RackPallet3DDetailsScreen({super.key});

  @override
  State<RackPallet3DDetailsScreen> createState() => _RackPallet3DDetailsScreenState();
}

class _RackPallet3DDetailsScreenState extends State<RackPallet3DDetailsScreen> {
  final String _viewID = 'warehouse-3d-view';
  dynamic _iframeElement; // Use dynamic to avoid compile error on mobile
  String _selectedRack = 'SELECT A RACK';
  String _selectedSlot = '---';
  List<String> _allRacks = [];
  List<String> _allPallets = [];
  bool _isLoadingMasters = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebIframe();
    }
    _loadInitialData();
  }

  void _initWebIframe() {
    _iframeElement = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewID,
      (int viewId) => _iframeElement,
    );

    // Listen for messages from the 3D component
    html.window.onMessage.listen((event) {
      if (event.data is Map && event.data['type'] == 'slot_selected') {
        if (mounted) {
          setState(() {
            _selectedRack = event.data['rackId']?.toString() ?? 'N/A';
            _selectedSlot = event.data['slotId']?.toString() ?? 'N/A';
          });
        }
      }
    });
  }

  Future<void> _loadInitialData() async {
    _token = await StorageService().getToken();
    await _loadMasters();
    
    if (kIsWeb && _iframeElement != null) {
      final String baseAppUrl = html.window.location.href.split('#').first;
      final String iframeUrl = '${baseAppUrl}3d/index.html?server=${Uri.encodeComponent(ApiConstants.serverUrl)}&token=${Uri.encodeComponent(_token ?? "")}';
      (_iframeElement as html.IFrameElement).src = iframeUrl;
    }
  }

  Future<void> _loadMasters() async {
    try {
      final api = MobileApiService();
      final data = await api.getCategories();
      
      final rackCat = data.firstWhere((c) => 
        ['rack name', 'rack', 'racks'].contains(c['name']?.toString().toLowerCase()), orElse: () => null);
      final palletCat = data.firstWhere((c) => 
        ['pallet no', 'pallet', 'pallets'].contains(c['name']?.toString().toLowerCase()), orElse: () => null);

      setState(() {
        if (rackCat != null) _allRacks = (rackCat['values'] as List).map((v) => v['name'].toString()).toList();
        if (palletCat != null) _allPallets = (palletCat['values'] as List).map((v) => v['name'].toString()).toList();
        _isLoadingMasters = false;
      });
    } catch (e) {
      setState(() => _isLoadingMasters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark warehouse theme
      appBar: AppBar(
        title: Text(
          '3D RACK & PALLET MANAGEMENT',
          style: GoogleFonts.orbitron(
            fontWeight: FontWeight.w800, 
            fontSize: 16, 
            color: Colors.cyanAccent,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.cyanAccent),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildStatusBadge('SYSTEM ONLINE', Colors.greenAccent),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // 3D View (Main area)
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: kIsWeb 
                ? const HtmlElementView(viewType: 'warehouse-3d-view')
                : Center(
                    child: Text(
                      '3D View is only available on Web',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  ),
            ),
          ),
          
          // Details Panel (Flutter side)
          Container(
            width: 380,
            margin: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: SingleChildScrollView(child: _buildDetailsPanel()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Fix for unbounded height inside scroll
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.box, color: Colors.cyanAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                'SLOT DETAILS',
                style: GoogleFonts.orbitron(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Divider(height: 48, color: Color(0xFF334155)),
          
          _buildDropdownInfo('RACK ID', _selectedRack, _allRacks, (val) {
            setState(() => _selectedRack = val!);
            if (kIsWeb && _iframeElement != null) {
              (_iframeElement as html.IFrameElement).contentWindow?.postMessage({
                'type': 'move_to_slot',
                'rackId': val,
              }, '*');
            }
          }),
          const SizedBox(height: 12),
          _buildDropdownInfo('PALLET ID', _selectedSlot, _allPallets, (val) => setState(() => _selectedSlot = val!)),
          const SizedBox(height: 12),
          _buildInfoRow('LEVEL', 'AUTO', LucideIcons.barChart3),
          
          const SizedBox(height: 32),
          
          Text(
            'INVENTORY STATUS',
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: FontWeight.w800, 
              color: Colors.cyanAccent,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                _buildStat('COLOR', 'SAPPHIRE BLUE', Colors.blueAccent),
                const SizedBox(height: 12),
                _buildStat('WEIGHT', '542.50 KG', Colors.cyanAccent),
                const SizedBox(height: 12),
                _buildStat('LAST UPDATED', '14 MIN AGO', Colors.white54),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          _buildActionBtn('UPDATE STOCK', LucideIcons.edit3, Colors.cyanAccent),
          const SizedBox(height: 12),
          _buildActionBtn('OUTWARD DELIVERY', LucideIcons.truck, Colors.orangeAccent),
          const SizedBox(height: 12),
          _buildActionBtn('CLEAR SLOT', LucideIcons.trash2, Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildDropdownInfo(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    bool hasVal = options.contains(value);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: DropdownButton<String>(
            value: hasVal ? value : null,
            hint: Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF1E293B),
            items: options.map((s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white38),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white38)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.1),
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
}
