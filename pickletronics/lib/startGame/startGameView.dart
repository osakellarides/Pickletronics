import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class StartGameView extends StatefulWidget {
  const StartGameView({super.key});

  @override
  _StartGameViewState createState() => _StartGameViewState();
}

class _StartGameViewState extends State<StartGameView> {
  final FlutterBluePlus _flutterBlue = FlutterBluePlus();
  List<BluetoothDevice> _devicesList = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeScan();
  }

  Future<void> _initializeScan() async {
    await _requestPermissions();
    _checkBluetoothState();
  }

  Future<void> _requestPermissions() async {
    // Request Bluetooth and location permissions
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  void _checkBluetoothState() {
    // Listen to Bluetooth state and start scanning if Bluetooth is ON
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on && !isScanning) {
        _startScanning();
      } else if (state != BluetoothAdapterState.on) {
        print("Bluetooth is OFF or not supported.");
      }
    });
  }

  Future<void> _startScanning() async {
    if (isScanning) return; // Prevent duplicate scans
    setState(() {
      isScanning = true;
      _devicesList.clear();
    });

    print("Starting scan...");
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 60));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _devicesList = results.map((result) => result.device).toList();
      });
      for (ScanResult result in results) {
        print('Device found: ${result.device.remoteId}: "${result.device.name}"');
      }
    }, onError: (e) {
      print("Error during scan: $e");
      setState(() {
        isScanning = false;
      });
    });

    // Wait for scan completion
    FlutterBluePlus.isScanning.where((scanning) => scanning == false).first.then((_) {
      print("Scan finished.");
      setState(() {
        isScanning = false;
      });
      _scanSubscription?.cancel();
    });
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: isScanning ? null : _startScanning,
            child: Text(isScanning ? 'Scanning...' : 'Scan for Devices'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _devicesList.length,
              itemBuilder: (context, index) {
                final device = _devicesList[index];
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                  subtitle: Text(device.remoteId.toString()),
                  onTap: () {
                    print('Tapped on ${device.name}');
                    // TODO: Connect to Device
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
