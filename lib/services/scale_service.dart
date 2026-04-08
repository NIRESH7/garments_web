import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:usb_serial/transaction.dart';
import 'package:usb_serial/usb_serial.dart';

import '../core/storage/storage_service.dart';

class ScaleDevice {
  final int? vendorId;
  final int? productId;
  final String? productName;
  final String? manufacturerName;
  final String? serial;

  const ScaleDevice({
    required this.vendorId,
    required this.productId,
    required this.productName,
    required this.manufacturerName,
    required this.serial,
  });

  String get key =>
      '${vendorId ?? 0}:${productId ?? 0}:${serial?.trim().isEmpty ?? true ? "-" : serial}';

  String get label {
    final vid =
        vendorId?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '0000';
    final pid =
        productId?.toRadixString(16).toUpperCase().padLeft(4, '0') ?? '0000';
    final name = (productName?.trim().isNotEmpty ?? false)
        ? productName!.trim()
        : 'USB Serial Device';
    final maker = (manufacturerName?.trim().isNotEmpty ?? false)
        ? manufacturerName!.trim()
        : 'Unknown';
    return '$name ($maker) [$vid:$pid]';
  }
}

class ScaleBluetoothDevice {
  final String address;
  final String? name;

  const ScaleBluetoothDevice({required this.address, required this.name});

  String get label {
    final n = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : 'Bluetooth Device';
    return '$n ($address)';
  }
}

class ScaleSettings {
  final bool enabled;
  final String connectionType; // usb | bluetooth
  final String? selectedDeviceKey;
  final String? selectedBluetoothAddress;
  final int baudRate;
  final int dataBits;
  final int stopBits;
  final int parity;
  final String requestCommand;
  final int stableReadsRequired;
  final double stableTolerance;
  final int readTimeoutMs;

  const ScaleSettings({
    required this.enabled,
    required this.connectionType,
    required this.selectedDeviceKey,
    required this.selectedBluetoothAddress,
    required this.baudRate,
    required this.dataBits,
    required this.stopBits,
    required this.parity,
    required this.requestCommand,
    required this.stableReadsRequired,
    required this.stableTolerance,
    required this.readTimeoutMs,
  });

  const ScaleSettings.defaults()
    : enabled = false,
      connectionType = 'usb',
      selectedDeviceKey = null,
      selectedBluetoothAddress = null,
      baudRate = 9600,
      dataBits = UsbPort.DATABITS_8,
      stopBits = UsbPort.STOPBITS_1,
      parity = UsbPort.PARITY_NONE,
      requestCommand = '',
      stableReadsRequired = 2,
      stableTolerance = 0.02,
      readTimeoutMs = 3000;

  ScaleSettings copyWith({
    bool? enabled,
    String? connectionType,
    String? selectedDeviceKey,
    String? selectedBluetoothAddress,
    int? baudRate,
    int? dataBits,
    int? stopBits,
    int? parity,
    String? requestCommand,
    int? stableReadsRequired,
    double? stableTolerance,
    int? readTimeoutMs,
  }) {
    return ScaleSettings(
      enabled: enabled ?? this.enabled,
      connectionType: connectionType ?? this.connectionType,
      selectedDeviceKey: selectedDeviceKey ?? this.selectedDeviceKey,
      selectedBluetoothAddress:
          selectedBluetoothAddress ?? this.selectedBluetoothAddress,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      stopBits: stopBits ?? this.stopBits,
      parity: parity ?? this.parity,
      requestCommand: requestCommand ?? this.requestCommand,
      stableReadsRequired: stableReadsRequired ?? this.stableReadsRequired,
      stableTolerance: stableTolerance ?? this.stableTolerance,
      readTimeoutMs: readTimeoutMs ?? this.readTimeoutMs,
    );
  }
}

class ScaleService {
  ScaleService._();
  static final ScaleService instance = ScaleService._();

  static const _keyEnabled = 'scale_enabled';
  static const _keyConnectionType = 'scale_connection_type';
  static const _keyDevice = 'scale_device_key';
  static const _keyBluetoothAddress = 'scale_bluetooth_address';
  static const _keyBaudRate = 'scale_baud_rate';
  static const _keyDataBits = 'scale_data_bits';
  static const _keyStopBits = 'scale_stop_bits';
  static const _keyParity = 'scale_parity';
  static const _keyRequestCommand = 'scale_request_command';
  static const _keyStableReads = 'scale_stable_reads';
  static const _keyStableTolerance = 'scale_stable_tolerance';
  static const _keyReadTimeout = 'scale_read_timeout_ms';

  final StorageService _storage = StorageService();
  BluetoothConnection? _btConnection;
  String? _btAddress;
  Stream<Uint8List>? _btInputStream;
  Completer<double>? _ongoingCapture;

  Future<void> closeBluetoothConnection() async {
    if (_btConnection != null) {
      await _btConnection!.finish();
      _btConnection = null;
      _btAddress = null;
      _btInputStream = null;
    }
  }

  Future<ScaleSettings> loadSettings() async {
    final enabled = await _storage.readValue(_keyEnabled) == '1';
    final connectionType = await _storage.readValue(_keyConnectionType);
    final selectedDeviceKey = await _storage.readValue(_keyDevice);
    final selectedBluetoothAddress = await _storage.readValue(
      _keyBluetoothAddress,
    );
    final baudRate = int.tryParse(await _storage.readValue(_keyBaudRate) ?? '');
    final dataBits = int.tryParse(await _storage.readValue(_keyDataBits) ?? '');
    final stopBits = int.tryParse(await _storage.readValue(_keyStopBits) ?? '');
    final parity = int.tryParse(await _storage.readValue(_keyParity) ?? '');
    final requestCommand = await _storage.readValue(_keyRequestCommand) ?? '';
    final stableReads = int.tryParse(
      await _storage.readValue(_keyStableReads) ?? '',
    );
    final stableTolerance = double.tryParse(
      await _storage.readValue(_keyStableTolerance) ?? '',
    );
    final readTimeout = int.tryParse(
      await _storage.readValue(_keyReadTimeout) ?? '',
    );

    return ScaleSettings(
      enabled: enabled,
      connectionType: connectionType == 'bluetooth' ? 'bluetooth' : 'usb',
      selectedDeviceKey: selectedDeviceKey,
      selectedBluetoothAddress: selectedBluetoothAddress,
      baudRate: baudRate ?? 9600,
      dataBits: dataBits ?? UsbPort.DATABITS_8,
      stopBits: stopBits ?? UsbPort.STOPBITS_1,
      parity: parity ?? UsbPort.PARITY_NONE,
      requestCommand: requestCommand,
      stableReadsRequired: stableReads ?? 2,
      stableTolerance: stableTolerance ?? 0.02,
      readTimeoutMs: readTimeout ?? 3000,
    );
  }

  Future<void> saveSettings(ScaleSettings settings) async {
    await _storage.writeValue(_keyEnabled, settings.enabled ? '1' : '0');
    await _storage.writeValue(_keyConnectionType, settings.connectionType);
    await _storage.writeValue(_keyDevice, settings.selectedDeviceKey ?? '');
    await _storage.writeValue(
      _keyBluetoothAddress,
      settings.selectedBluetoothAddress ?? '',
    );
    await _storage.writeValue(_keyBaudRate, settings.baudRate.toString());
    await _storage.writeValue(_keyDataBits, settings.dataBits.toString());
    await _storage.writeValue(_keyStopBits, settings.stopBits.toString());
    await _storage.writeValue(_keyParity, settings.parity.toString());
    await _storage.writeValue(_keyRequestCommand, settings.requestCommand);
    await _storage.writeValue(
      _keyStableReads,
      settings.stableReadsRequired.toString(),
    );
    await _storage.writeValue(
      _keyStableTolerance,
      settings.stableTolerance.toString(),
    );
    await _storage.writeValue(
      _keyReadTimeout,
      settings.readTimeoutMs.toString(),
    );
  }

  Future<void> updateSettings({bool? enabled}) async {
    final current = await loadSettings();
    final updated = current.copyWith(enabled: enabled);
    await saveSettings(updated);
  }

  Future<List<ScaleDevice>> listDevices() async {
    final devices = await UsbSerial.listDevices();
    return devices
        .map(
          (d) => ScaleDevice(
            vendorId: d.vid,
            productId: d.pid,
            productName: d.productName,
            manufacturerName: d.manufacturerName,
            serial: d.serial,
          ),
        )
        .toList();
  }

  Future<List<ScaleBluetoothDevice>> listBluetoothDevices() async {
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    return devices
        .where((d) => d.address.isNotEmpty)
        .map((d) => ScaleBluetoothDevice(address: d.address, name: d.name))
        .toList();
  }

  Stream<BluetoothDiscoveryResult> discoverDevices() {
    return FlutterBluetoothSerial.instance.startDiscovery();
  }

  Future<bool> bondDevice(String address) async {
    try {
      final bonded =
          await FlutterBluetoothSerial.instance.bondDeviceAtAddress(address);
      return bonded ?? false;
    } catch (e) {
      print('Bonding failed: $e');
      return false;
    }
  }

  Future<double> captureWeight({ScaleSettings? settings}) async {
    final config = settings ?? await loadSettings();

    // Prevent multiple concurrent capture attempts which cause stream errors
    if (_ongoingCapture != null && !_ongoingCapture!.isCompleted) {
      return _ongoingCapture!.future;
    }

    _ongoingCapture = Completer<double>();

    try {
      double result;
      if (!config.enabled) {
        if (kIsWeb) {
          result = 5.0 + Random().nextDouble() * 2.0;
        } else {
          throw Exception(
            'Scale machine is disabled. Enable it in Scale Machine menu.',
          );
        }
      } else if (kIsWeb) {
        // Mock weight for web development
        await Future.delayed(const Duration(milliseconds: 500));
        result = 10.0 + Random().nextDouble() * 5.0;
      } else if (config.connectionType == 'bluetooth') {
        result = await _captureBluetoothWeight(config);
      } else {
        result = await _captureUsbWeight(config);
      }

      if (!_ongoingCapture!.isCompleted) {
        _ongoingCapture!.complete(result);
      }
      return result;
    } catch (e) {
      if (!_ongoingCapture!.isCompleted) {
        _ongoingCapture!.completeError(e);
      }
      rethrow;
    }
  }

  Future<double> _captureUsbWeight(ScaleSettings config) async {
    final usbDevice = await _resolveDevice(config);
    if (usbDevice == null) {
      throw Exception(
        'Scale machine not found. Reconnect the cable and select device in Scale Machine menu.',
      );
    }
    final port = await usbDevice.create();
    if (port == null) {
      throw Exception('Cannot open scale machine USB port.');
    }

    Transaction<String>? transaction;
    StreamSubscription<String>? subscription;
    Timer? timeoutTimer;

    try {
      final opened = await port.open();
      if (!opened) {
        throw Exception('Unable to open selected USB scale port.');
      }

      await port.setPortParameters(
        config.baudRate,
        config.dataBits,
        config.stopBits,
        config.parity,
      );
      await port.setFlowControl(UsbPort.FLOW_CONTROL_OFF);
      await port.setDTR(true);
      await port.setRTS(true);

      transaction = Transaction.stringTerminated(
        port.inputStream!,
        Uint8List.fromList([13, 10]), // CRLF
      );

      if (config.requestCommand.trim().isNotEmpty) {
        await port.write(
          Uint8List.fromList(_decodeEscapes(config.requestCommand)),
        );
      }

      final completer = Completer<double>();
      double? previous;
      var stableHits = 0;

      subscription = transaction.stream.listen((line) {
        final parsed = _extractWeight(line);
        if (parsed == null) return;

        if (previous == null) {
          previous = parsed;
          stableHits = 1;
        } else if ((parsed - previous!).abs() <= config.stableTolerance) {
          previous = parsed;
          stableHits += 1;
        } else {
          previous = parsed;
          stableHits = 1;
        }

        if (stableHits >= config.stableReadsRequired &&
            !completer.isCompleted) {
          completer.complete(parsed);
        }
      });

      timeoutTimer = Timer(Duration(milliseconds: config.readTimeoutMs), () {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Timed out waiting for weight from machine.'),
          );
        }
      });

      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      await subscription?.cancel();
      transaction?.dispose();
      await port.close();
    }
  }

  Future<double> _captureBluetoothWeight(ScaleSettings config) async {
    final address = config.selectedBluetoothAddress;
    if (address == null || address.isEmpty) {
      throw Exception(
        'Bluetooth device not selected. Select a paired device in Scale Machine menu.',
      );
    }

    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!isEnabled) {
      throw Exception('Bluetooth is off. Turn on Bluetooth and try again.');
    }

    // Reuse existing connection if valid
    if (_btConnection != null &&
        _btAddress == address &&
        _btConnection!.isConnected) {
      return _readWeightFromConnection(_btConnection!, config);
    }

    // Connect and cache
    try {
      await closeBluetoothConnection(); // Ensure clean slate
      final connection = await BluetoothConnection.toAddress(address);
      _btConnection = connection;
      _btAddress = address;
      _btInputStream = connection.input?.asBroadcastStream();

      return _readWeightFromConnection(connection, config);
    } catch (e) {
      await closeBluetoothConnection();
      rethrow;
    }
  }

  Future<double> _readWeightFromConnection(
    BluetoothConnection connection,
    ScaleSettings config,
  ) async {
    StreamSubscription<Uint8List>? subscription;
    Timer? timeoutTimer;

    try {
      if (config.requestCommand.trim().isNotEmpty) {
        connection.output.add(
          Uint8List.fromList(_decodeEscapes(config.requestCommand)),
        );
        await connection.output.allSent;
      }

      final completer = Completer<double>();
      final lineBuffer = <int>[];
      double? previous;
      var stableHits = 0;

      final inputStream = _btInputStream ?? connection.input;
      subscription = inputStream?.listen(
        (data) {
          for (final b in data) {
            if (b == 10 || b == 13) {
              if (lineBuffer.isEmpty) continue;
              final line = String.fromCharCodes(lineBuffer);
              lineBuffer.clear();
              final parsed = _extractWeight(line);
              if (parsed == null) continue;

              if (previous == null) {
                previous = parsed;
                stableHits = 1;
              } else if ((parsed - previous!).abs() <= config.stableTolerance) {
                previous = parsed;
                stableHits += 1;
              } else {
                previous = parsed;
                stableHits = 1;
              }

              if (stableHits >= config.stableReadsRequired &&
                  !completer.isCompleted) {
                completer.complete(parsed);
                return;
              }
            } else {
              lineBuffer.add(b);
            }
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Bluetooth connection closed before weight was read.'),
            );
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Bluetooth read error: $e'));
          }
        },
        cancelOnError: true,
      );

      timeoutTimer = Timer(Duration(milliseconds: config.readTimeoutMs), () {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Timed out waiting for weight from Bluetooth machine.'),
          );
        }
      });

      return await completer.future;
    } finally {
      timeoutTimer?.cancel();
      await subscription?.cancel();
      // NOTE: We do NOT dispose the connection here anymore. 
      // It is managed by ScaleService state.
    }
  }

  Future<UsbDevice?> _resolveDevice(ScaleSettings config) async {
    final devices = await UsbSerial.listDevices();
    if (devices.isEmpty) return null;
    if (config.selectedDeviceKey == null || config.selectedDeviceKey!.isEmpty) {
      return devices.first;
    }

    for (final d in devices) {
      final key =
          '${d.vid ?? 0}:${d.pid ?? 0}:${(d.serial?.trim().isNotEmpty ?? false) ? d.serial : "-"}';
      if (key == config.selectedDeviceKey) {
        return d;
      }
    }
    return null;
  }

  double? _extractWeight(String rawLine) {
    final cleaned = rawLine.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;

    final match = RegExp(r'[-+]?\d+(\.\d+)?').firstMatch(cleaned);
    if (match == null) return null;

    return double.tryParse(match.group(0)!);
  }

  List<int> _decodeEscapes(String input) {
    final out = <int>[];
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (ch == r'\' && i + 1 < input.length) {
        final next = input[i + 1];
        if (next == 'r') {
          out.add(13);
          i++;
          continue;
        }
        if (next == 'n') {
          out.add(10);
          i++;
          continue;
        }
        if (next == 't') {
          out.add(9);
          i++;
          continue;
        }
        if (next == r'\') {
          out.add(92);
          i++;
          continue;
        }
      }
      out.add(ch.codeUnitAt(0));
    }
    return out;
  }
}
