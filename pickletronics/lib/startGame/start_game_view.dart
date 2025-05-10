import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';
import 'package:pickletronics/viewSessions/SessionsTab.dart';
import 'package:pickletronics/viewSessions/session_parser.dart';

final Logger _logger = Logger();
String new_final_string = '';
bool isLoading = false;
int _totalSessions = 0;

Future<void> _requestPermissions() async {
  await Permission.bluetoothScan.request();
  await Permission.bluetoothConnect.request();
  await Permission.location.request();
  await Permission.storage.request(); // Request storage permission
}

class StartGameView extends StatefulWidget {
  const StartGameView({super.key});

  @override
  StartGameViewState createState() => StartGameViewState();
}

class StartGameViewState extends State<StartGameView> {
  final List<BluetoothDevice> _devicesList = [];
  late StreamSubscription<List<ScanResult>> _scanSubscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadTotalSessions(); // Load session count on startup

    _scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult r = results.last;
        if (r.device.platformName == "BLE-Server") {
          if (!_devicesList.contains(r.device)) {
            setState(() {
              _devicesList.clear(); 
              _devicesList.add(r.device);
            });
          }
        }
      }
    }, onError: (e) => _logger.i('Error while scanning: $e'));
  }

  @override
  void dispose() {
    _scanSubscription.cancel(); // Clean up the subscription when disposing
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Background Image
        Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),

        Column(
          children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                color: const Color.fromARGB(205, 255, 255, 255),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Welcome Back!",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "After recording a session on your pickleball swing tracker, press the scan button below to scan for and connect to your device. After connecting, all recorded data will automatically be uploaded to the 'Sessions' tab.",
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text("How to Use Attachment"),
                                content: const Text("1. Turn device on using the switch. This will cause the LED to blink. \n2. Click the button once to enter a play session. The LED will now display the battery status. \n3. Record hits! The LED will blink when a hit has been detected. \n4. Press the button once more to end your play session. \n5. Click the button twice to connect to bluetooth. The LED will blink blue to indicate you are advertising."),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text("OK"),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text("How to Use Attachment"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

            // Button and Bluetooth Devices List
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: isScanning ? null : _startScanning,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 250, 250, 251),
                      foregroundColor: const Color.fromARGB(255, 4, 4, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      isScanning ? 'Scanning...' : 'Scan for Nearby Devices',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _devicesList.isNotEmpty
                        ? ListView.builder(
                            itemCount: _devicesList.length,
                            itemBuilder: (context, index) {
                              final device = _devicesList[index];
                              return Card(
                                color: const Color.fromARGB(188, 26, 53, 121).withOpacity(0.8), // Purple background
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                                child: ListTile(
                                  title: Text(
                                    device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    'ID: ${device.remoteId}',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: const Icon(Icons.bluetooth, color: Colors.white),
                                  onTap: () {
                                    _showDeviceModal(device);
                                  },
                                ),
                              );
                            },
                          )
                        : const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.0),
                          child: Text(
                            'No devices found.',
                            style: TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _loadTotalSessions() async {
  List<Session> sessions = await SessionParser().loadSessions();
  setState(() {
    _totalSessions = sessions.length;
  });
}

  Future<void> _startScanning() async {
    await _requestPermissions();
    setState(() {
      isScanning = true;
      _devicesList.clear(); // Clear previous results
    });

    await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;

    // Scan for ble devices with specific name/services
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // Wait for scanning to stop
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    setState(() {
      isScanning = false;
    });

    _logger.i("Scanning complete.");
  }

void _showDeviceModal(BluetoothDevice device) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the modal
                await _connectAndReadCharacteristics(device);
              },
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _connectAndReadCharacteristics(BluetoothDevice device) async {
  try {
    setState(() => isLoading = true);
    _showLoadingDialog('Connecting to ${device.platformName}...');

    _logger.i('Connecting to device: ${device.platformName} (${device.remoteId})');

    await device.connect().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Connection timed out. Please try again.');
      },
    );
    
    _logger.i('Successfully connected to ${device.platformName}');

    // Update the loading dialog message
    Navigator.pop(context); // Close previous dialog
    _showLoadingDialog('Reading data from ${device.platformName}...');

    List<BluetoothService> services = await device.discoverServices();
    if (services.isEmpty) {
      Navigator.pop(context); // Close the loading dialog
      _showFailureModal("Failed to retrieve data from ${device.platformName}");
      return;
    }

    List<String> receivedData = [];
    bool sessionCreated = false;

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().contains('fef4')) {
          while (true) {
            try {
              List<int> value = await characteristic.read();
              String stringValue = utf8.decode(value);
              receivedData.add(stringValue);

              await _appendToLogFile(stringValue);
              print('Received: $stringValue');

              if (stringValue.contains('Dumped all sessions.')) {
                await Future.delayed(Duration(milliseconds: 100));
                List<Session> parsedSessions = await SessionParser().parseFile();
                print("Parsed sessions: ${parsedSessions.map((s) => s.toJson()).toList()}");

                sessionCreated = true;
                break;
              }
            } catch (e) {
              print('Error reading characteristic: $e');
              Navigator.pop(context); // Close the loading dialog
              _showFailureModal("Error reading data from ${device.platformName}");
              return;
            }
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
      }
    }

    Navigator.pop(context); // Close the loading dialog

    if (sessionCreated) {
      _showSuccessModal("Session data successfully received from ${device.platformName}.");
    } else {
      _showFailureModal("No valid session data found from ${device.platformName}.");
    }

  } catch (e) {
    Navigator.pop(context); // Close the loading dialog
    _logger.e('Failed to connect: $e');
    _showFailureModal("Failed to connect to ${device.platformName}");
  } finally {
    setState(() => isLoading = false);
  }
}

void _showFailureModal(String message) {
  showDialog(
    context: context,
    barrierDismissible: false, // Requires user to tap "OK"
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

void _showSuccessModal(String message) {
  showDialog(
    context: context,
    barrierDismissible: false, // Requires user to tap "OK"
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}

Future<void> _appendToLogFile(String data) async {
  try {
    final file = File('/storage/emulated/0/Download/bluetooth_log.txt');

    if (await file.exists()) {
      String existingContent = await file.readAsString();
      if (existingContent.contains('Dumped all sessions.')) {
        print('Previous session detected. Clearing log file.');
        await file.writeAsString(''); // Clear the file
      }
    }

    // Append data and ensure it is written before moving on
    await file.writeAsString('$data\n', mode: FileMode.append);
    print('Appended to file: $data');
    
    // Delay to allow filesystem sync before parsing
    await Future.delayed(Duration(milliseconds: 100));

  } catch (e) {
    print('Error writing to file: $e');
  }
}

void _showLoadingDialog(String message) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevents user from dismissing it manually
    builder: (BuildContext context) {
      return AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      );
    },
  );
}

void _showCharacteristicsDialog(BluetoothDevice device, List<String> characteristics, String temp) {

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(device.platformName.isNotEmpty ? device.platformName : 'Unknown Device'),
        content: characteristics.isNotEmpty
        ? SingleChildScrollView( // Ensures the content can scroll if it's long
            child: Text(
              characteristics.join("\n"), // Joins characteristics into a single string
              textAlign: TextAlign.left,  // Align text properly
            ),
          )
        : const Text('No data found'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
}
