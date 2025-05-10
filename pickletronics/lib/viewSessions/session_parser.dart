import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:pickletronics/utils/sweet_spot.dart';

final Logger _parserLogger = Logger();

// Impact class to store individual impact data
class Impact {
  List<double> impactArray;
  double impactStrength;
  double impactRotation;
  double maxRotation;
  bool isSweetSpot;

  Impact({
    required this.impactArray,
    required this.impactStrength,
    required this.impactRotation,
    required this.maxRotation,
    this.isSweetSpot = false, // Default to false if not provided
  });

  Map<String, dynamic> toJson() => {
    "impactArray": impactArray,
    "impactStrength": impactStrength,
    "impactRotation": impactRotation,
    "maxRotation": maxRotation,
    "isSweetSpot": isSweetSpot,
  };

  factory Impact.fromJson(Map<String, dynamic> json) => Impact(
    impactArray: List<double>.from(json["impactArray"]?.map((x) => (x as num).toDouble()) ?? []),
    impactStrength: (json["impactStrength"] as num?)?.toDouble() ?? 0.0,
    impactRotation: (json["impactRotation"] as num?)?.toDouble() ?? 0.0,
    maxRotation: (json["maxRotation"] as num?)?.toDouble() ?? 0.0,
    isSweetSpot: json["isSweetSpot"] as bool? ?? false, // Default to false if null in JSON
  );
}

/// Session class now holds a list of impacts
class Session {
  int sessionNumber;
  List<Impact> impacts;
  DateTime? timestamp;

  Session({
    required this.sessionNumber,
    required this.timestamp,
    required this.impacts,
  });

  Map<String, dynamic> toJson() => {
    "sessionNumber": sessionNumber,
    "timestamp": timestamp?.toIso8601String(),
    "impacts": impacts.map((e) => e.toJson()).toList(),
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    sessionNumber: json["sessionNumber"] ?? 0,
    timestamp: json["timestamp"] != null ? DateTime.parse(json["timestamp"]) : null,
    impacts: (json["impacts"] as List? ?? [])
        .map((e) => Impact.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// SessionParser class to parse and save session data
class SessionParser {
  final String logFilePath = '/storage/emulated/0/Download/bluetooth_log.txt';
  final String sessionCounterPath = '/storage/emulated/0/Download/session_counter.json';
  final String sessionJsonPath = '/storage/emulated/0/Download/sessions.json';

  Future<int> getLastSessionNumber() async {
    try {
      final file = File(sessionCounterPath);
      if (await file.exists()) {
        String content = await file.readAsString();
        return int.tryParse(content) ?? 0;
      }
    } catch(e) {
      _parserLogger.e("Error getting last session number: $e");
    }
    return 0;
  }

  Future<void> saveLastSessionNumber(int lastSession) async {
    try {
      final file = File(sessionCounterPath);
      await file.writeAsString(lastSession.toString());
    } catch(e) {
      _parserLogger.e("Error saving last session number: $e");
    }
  }

  Future<void> deleteSession(int index) async {
    try {
      final file = File(sessionJsonPath);
      if (!await file.exists()) return;

      String jsonString = await file.readAsString();
      if (jsonString.isEmpty) return;
      List<dynamic> jsonData = jsonDecode(jsonString);
      List<Session> sessions = jsonData.map((e) => Session.fromJson(e)).toList();

      if (index < 0 || index >= sessions.length) return;

      sessions.removeAt(index);

      await file.writeAsString(jsonEncode(sessions.map((s) => s.toJson()).toList()));
      _parserLogger.i("Deleted session at index $index. Remaining sessions: ${sessions.length}");
    } catch (e) {
      _parserLogger.e("Error deleting session at index $index: $e");
    }
  }

  // parseFile
  Future<List<Session>> parseFile() async {
    final file = File(logFilePath);
    if (!await file.exists()) {
      _parserLogger.w("Log file does not exist: $logFilePath");
      return [];
    }

    String fileContent = await file.readAsString();
    _parserLogger.d("Raw file content length: ${fileContent.length}");

    // initialize ML Model
    final SweetSpotDetector sweetSpotDetector = SweetSpotDetector();
    List<Session> parsedSessions = [];
    int lastSessionNumber = await getLastSessionNumber();

    try {
      await sweetSpotDetector.loadModel();

      if (sweetSpotDetector.isModelLoaded) {
        _parserLogger.i("SweetSpotDetector model loaded successfully for parsing. Using center trimming for 300-sample arrays.");
        // Pass the loaded detector to the parse method
        parsedSessions = await parse(fileContent, lastSessionNumber, sweetSpotDetector);
        _parserLogger.i("Parsed sessions count: ${parsedSessions.length}");
      } else {
        _parserLogger.e("SweetSpotDetector model failed to load. Skipping predictions.");
        return [];
      }

      if (parsedSessions.isNotEmpty) {
        lastSessionNumber += parsedSessions.length;
        await saveLastSessionNumber(lastSessionNumber);
        await saveSessions(parsedSessions);
      }

    } catch (e) {
      _parserLogger.e("Error during parsing or model loading: $e");
    } finally {
      sweetSpotDetector.dispose();
      _parserLogger.i("SweetSpotDetector disposed.");
    }

    return parsedSessions;
  }

  // Utility function to clean decimal values
  double cleanDecimalValue(String value) {
    // Handle the case with multiple decimal points like "34.534.5"
    String trimmed = value.trim();
    int firstDecimal = trimmed.indexOf('.');
    if (firstDecimal >= 0) {
      // Check if there's a second decimal point
      int secondDecimal = trimmed.indexOf('.', firstDecimal + 1);
      if (secondDecimal >= 0) {
        // Found multiple decimal points, fix by removing second decimal and everything after
        _parserLogger.w("Found malformed decimal value: $value - fixing by truncating at second decimal");
        String fixed = trimmed.substring(0, secondDecimal);
        return double.tryParse(fixed) ?? 0.0;
      }
    }
    return double.tryParse(trimmed) ?? 0.0;
  }

  // parse method
  Future<List<Session>> parse(String fileContent, int startingSessionNumber, SweetSpotDetector? detector) async {
    _parserLogger.i("Parsing log content...");
    List<Session> sessions = [];
    Session? currentSession;
    List<Impact> currentImpacts = [];
    int sessionNumber = startingSessionNumber;

    fileContent = fileContent.replaceAll('\r\n', ' ').replaceAll('\n', ' ').trim();

    RegExp sessionStartRegex = RegExp(r'(\d+)\s+New Impact Data', multiLine: false);
    RegExp impactRegex = RegExp(
        r"Impact Array:\s*\[(.*?)]\s*Impact Strength:\s*([\d.]+)\s*Impact Rotation:\s*([\d.]+)\s*Max Rotation:\s*([\d.]+)");
    RegExp endOfSessionRegex = RegExp(r"End of file reached\.");
    RegExp allSessionsDumpedRegex = RegExp(r"Dumped all sessions\.");

    int currentIndex = 0;
    while (currentIndex < fileContent.length) {
      Match? sessionMatch = sessionStartRegex.firstMatch(fileContent.substring(currentIndex));
      if (sessionMatch != null) {
        _parserLogger.d("Found Session Start at index $currentIndex. Local session: ${sessionMatch.group(1)}, Global session: $sessionNumber");
        if (currentSession != null && currentImpacts.isNotEmpty) {
          currentSession.impacts.addAll(currentImpacts);
          sessions.add(currentSession);
          sessionNumber++;
          _parserLogger.d("Saved previous session ${currentSession.sessionNumber}. Starting new global session $sessionNumber.");
        }
        currentSession = Session(
          sessionNumber: sessionNumber,
          timestamp: DateTime.now(),
          impacts: [],
        );
        currentImpacts = [];
        currentIndex += sessionMatch.end;
        continue;
      }

      Match? impactMatch = impactRegex.firstMatch(fileContent.substring(currentIndex));
      if (impactMatch != null && currentSession != null) {
        _parserLogger.d("Found Impact Data at index $currentIndex for session ${currentSession.sessionNumber}");

        String impactArrayStr = impactMatch.group(1) ?? "";
        // Only clean decimal values in the impact array
        List<double> impactArray = impactArrayStr.isNotEmpty
            ? impactArrayStr.split(',').map((e) => cleanDecimalValue(e)).toList()
            : [];

        double impactStrength = double.tryParse(impactMatch.group(2) ?? "0.0") ?? 0.0;
        double impactRotation = double.tryParse(impactMatch.group(3) ?? "0.0") ?? 0.0;
        double maxRotation = double.tryParse(impactMatch.group(4) ?? "0.0") ?? 0.0;

        // Create with default isSweetSpot = false
        Impact currentImpact = Impact(
          impactArray: impactArray,
          impactStrength: impactStrength,
          impactRotation: impactRotation,
          maxRotation: maxRotation,
        );

        if (detector != null && detector.isModelLoaded && currentImpact.impactArray.isNotEmpty) {
          try {
            // Log the original array length before processing
            _parserLogger.d("Original impact array length: ${currentImpact.impactArray.length}");

            // Get prediction and set directly (no null handling needed)
            bool prediction = await detector.predictSweetSpot(currentImpact.impactArray);
            currentImpact.isSweetSpot = prediction;

            _parserLogger.d("Prediction for impact: SweetSpot=${currentImpact.isSweetSpot}, "
                "Original Length=${currentImpact.impactArray.length}");
          } catch (e) {
            _parserLogger.e("Error during sweet spot prediction for an impact: $e");
            // isSweetSpot already defaults to false, so no need to set again
          }
        } else if (detector == null || !detector.isModelLoaded){
          _parserLogger.w("Sweet spot detector not available, skipping prediction for impact.");
          // isSweetSpot remains as default false
        } else if (currentImpact.impactArray.isEmpty) {
          _parserLogger.w("Impact array is empty, skipping prediction.");
          // isSweetSpot remains as default false
        }

        currentImpacts.add(currentImpact);
        currentIndex += impactMatch.end;
        continue;
      }

      Match? endMatch = endOfSessionRegex.firstMatch(fileContent.substring(currentIndex));
      if (endMatch != null) {
        _parserLogger.d("Found 'End of file reached.' at index $currentIndex.");
        if (currentSession != null) {
          currentSession.impacts.addAll(currentImpacts);
          sessions.add(currentSession);
          _parserLogger.i("Saved final session ${currentSession.sessionNumber} found before 'End of file'.");
          sessionNumber++;
        }
        currentSession = null;
        currentImpacts = [];
        currentIndex += endMatch.end;
        continue;
      }

      Match? dumpedMatch = allSessionsDumpedRegex.firstMatch(fileContent.substring(currentIndex));
      if (dumpedMatch != null) {
        _parserLogger.i("Found 'Dumped all sessions.' at index $currentIndex. Stopping parse.");
        if (currentSession != null && currentImpacts.isNotEmpty) {
          currentSession.impacts.addAll(currentImpacts);
          sessions.add(currentSession);
          _parserLogger.i("Saved final session ${currentSession.sessionNumber} found before 'Dumped all'.");
        }
        break;
      }
      currentIndex++;
    }

    if (currentSession != null && currentImpacts.isNotEmpty) {
      currentSession.impacts.addAll(currentImpacts);
      sessions.add(currentSession);
      _parserLogger.i("Saved final session ${currentSession.sessionNumber} at end of parsing loop.");
    }

    _parserLogger.i("Parsing complete. Total sessions generated: ${sessions.length}");
    return sessions;
  }

  Future<void> saveSessions(List<Session> newSessions) async {
    if (newSessions.isEmpty) {
      _parserLogger.i("No new sessions to save.");
      return;
    }
    try {
      // Use hardcoded path
      final file = File(sessionJsonPath);
      List<Session> existingSessions = [];

      if (await file.exists()) {
        String jsonString = await file.readAsString();
        if (jsonString.isNotEmpty) {
          try {
            List<dynamic> jsonData = jsonDecode(jsonString);
            existingSessions = jsonData.map((e) => Session.fromJson(e)).toList();
          } catch (e) {
            _parserLogger.e("Error decoding existing sessions JSON: $e. Overwriting file.");
          }
        }
      }

      existingSessions.addAll(newSessions);
      await file.writeAsString(jsonEncode(existingSessions.map((s) => s.toJson()).toList()));

      _parserLogger.i("Saved ${newSessions.length} new sessions. Total sessions now: ${existingSessions.length}");
    } catch(e) {
      _parserLogger.e("Error saving sessions: $e");
    }
  }

  Future<List<Session>> loadSessions() async {
    try {
      final file = File(sessionJsonPath);
      if (!await file.exists()) {
        _parserLogger.i("Session file not found, returning empty list.");
        return [];
      }

      String jsonString = await file.readAsString();
      if (jsonString.isEmpty) {
        _parserLogger.i("Session file is empty, returning empty list.");
        return [];
      }
      try {
        List<dynamic> jsonData = jsonDecode(jsonString);
        List<Session> sessions = jsonData.map((e) => Session.fromJson(e)).toList();
        _parserLogger.i("Loaded ${sessions.length} sessions from file.");
        return sessions;
      } catch (e) {
        _parserLogger.e("Error decoding sessions JSON on load: $e");
        return [];
      }
    } catch (e) {
      _parserLogger.e("Error loading sessions: $e");
      return [];
    }
  }
}