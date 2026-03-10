import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/scale_service.dart';

class ScaleSettingsScreen extends StatefulWidget {
  const ScaleSettingsScreen({super.key});

  @override
  State<ScaleSettingsScreen> createState() => _ScaleSettingsScreenState();
}

class _ScaleSettingsScreenState extends State<ScaleSettingsScreen> {
  final ScaleService _scaleService = ScaleService.instance;

  bool _loading = true;
  bool _testing = false;
  bool _saving = false;

  List<ScaleDevice> _usbDevices = [];
  List<ScaleBluetoothDevice> _bluetoothDevices = [];
  ScaleSettings _settings = const ScaleSettings.defaults();
  String? _selectedUsbDeviceKey;
  String? _selectedBluetoothAddress;

  final TextEditingController _baudController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  final TextEditingController _timeoutController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baudController.dispose();
    _requestController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _ensureBluetoothPermissions();
      final settings = await _scaleService.loadSettings();
      final usbDevices = await _scaleService.listDevices();
      final bluetoothDevices = await _scaleService.listBluetoothDevices();
      _settings = settings;
      _usbDevices = usbDevices;
      _bluetoothDevices = bluetoothDevices;
      _selectedUsbDeviceKey = settings.selectedDeviceKey;
      _selectedBluetoothAddress = settings.selectedBluetoothAddress;
      _baudController.text = settings.baudRate.toString();
      _requestController.text = settings.requestCommand;
      _timeoutController.text = settings.readTimeoutMs.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ensureBluetoothPermissions() async {
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.locationWhenInUse.request();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final baud = int.tryParse(_baudController.text.trim()) ?? 9600;
      final timeout = int.tryParse(_timeoutController.text.trim()) ?? 3000;
      final updated = _settings.copyWith(
        selectedDeviceKey: _selectedUsbDeviceKey,
        selectedBluetoothAddress: _selectedBluetoothAddress,
        baudRate: baud,
        requestCommand: _requestController.text,
        readTimeoutMs: timeout,
      );
      await _scaleService.saveSettings(updated);
      _settings = updated;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scale machine settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testRead() async {
    setState(() => _testing = true);
    try {
      if (_settings.connectionType == 'bluetooth') {
        await _ensureBluetoothPermissions();
      }
      final testSettings = _settings.copyWith(
        selectedDeviceKey: _selectedUsbDeviceKey,
        selectedBluetoothAddress: _selectedBluetoothAddress,
        baudRate: int.tryParse(_baudController.text.trim()) ?? 9600,
        requestCommand: _requestController.text,
        readTimeoutMs: int.tryParse(_timeoutController.text.trim()) ?? 3000,
      );
      final weight = await _scaleService.captureWeight(settings: testSettings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Machine read success: ${weight.toStringAsFixed(2)} Kg',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Machine read failed: $e')));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scale Machine')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    value: _settings.enabled,
                    title: const Text('Enable automatic machine weight'),
                    subtitle: const Text(
                      'When enabled, Lot Inward can auto-fill Rec. Wt from the scale',
                    ),
                    onChanged: (v) {
                      setState(
                        () => _settings = _settings.copyWith(enabled: v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _settings.connectionType,
                    items: const [
                      DropdownMenuItem(value: 'usb', child: Text('USB OTG')),
                      DropdownMenuItem(
                        value: 'bluetooth',
                        child: Text('Bluetooth'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(
                        () => _settings = _settings.copyWith(connectionType: v),
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: 'Connection Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_settings.connectionType == 'usb')
                    DropdownButtonFormField<String>(
                      value: (_selectedUsbDeviceKey?.isNotEmpty ?? false)
                          ? _selectedUsbDeviceKey
                          : null,
                      items: _usbDevices
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.key,
                              child: Text(
                                d.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedUsbDeviceKey = v),
                      decoration: const InputDecoration(
                        labelText: 'USB Scale Device',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_settings.connectionType == 'bluetooth')
                    DropdownButtonFormField<String>(
                      value: (_selectedBluetoothAddress?.isNotEmpty ?? false)
                          ? _selectedBluetoothAddress
                          : null,
                      items: _bluetoothDevices
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.address,
                              child: Text(
                                d.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedBluetoothAddress = v),
                      decoration: const InputDecoration(
                        labelText: 'Paired Bluetooth Device',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (_settings.connectionType == 'bluetooth')
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Pair the weighing machine in Android Bluetooth settings first.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                  if (_settings.connectionType == 'usb')
                    const SizedBox(height: 12),
                  TextFormField(
                    controller: _baudController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Baud Rate',
                      hintText: '9600',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _requestController,
                    decoration: const InputDecoration(
                      labelText: 'Request Command (optional)',
                      hintText: 'Example: W\\r\\n',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Read Timeout (ms)',
                      hintText: '5000',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Default serial format used: 8 data bits, parity none, stop bit 1.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _testRead,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.monitor_weight_outlined),
                          label: const Text('Test Read'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Machine Connection Notes',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '1. Use USB OTG cable from indicator to Android tablet.',
                          ),
                          Text(
                            '2. Refresh this page after plugging the cable.',
                          ),
                          Text(
                            '3. Try 9600 baud first. If no data, test 2400/4800/19200.',
                          ),
                          Text(
                            '4. If indicator needs polling command, set Request Command.',
                          ),
                          Text(
                            '5. For Bluetooth: pair device in Android settings, then select it here.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_settings.connectionType == 'usb' && _usbDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No USB serial devices detected.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_settings.connectionType == 'bluetooth' &&
                      _bluetoothDevices.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No paired Bluetooth devices found.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
