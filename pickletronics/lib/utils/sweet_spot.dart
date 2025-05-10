import 'dart:math';
import 'package:logger/logger.dart';
import '../viewSessions/session_parser.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Detects sweet spot hits using a TFLite model.
/// Manages model loading, preprocessing, inference, and resource disposal.
class SweetSpotDetector {
  static SweetSpotDetector? _instance;
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  List<int>? _inputShape;

  // Logger instance for this class
  static final _logger = Logger(
    printer: PrettyPrinter(methodCount: 1,
        errorMethodCount: 5,
        lineLength: 80,
        colors: true,
        printEmojis: true),
  );

  // Private constructor
  SweetSpotDetector._internal();

  /// Provides access to the singleton instance.
  factory SweetSpotDetector() {
    _instance ??= SweetSpotDetector._internal();
    return _instance!;
  }

  /// Returns true if the TFLite model is successfully loaded.
  bool get isModelLoaded => _isModelLoaded;

  /// Loads the TFLite model from the specified asset path.
  Future<void> loadModel({String modelAsset = 'assets/sweet_spot_detector.tflite'}) async {
    if (_isModelLoaded) {
      _logger.d('Model is already loaded.');
      return;
    }
    if (_interpreter != null) {
      _logger.d('Model loading might already be in progress.');
      return;
    }

    _logger.i('Loading TFLite model from $modelAsset...');
    try {
      final interpreterOptions = InterpreterOptions();
      final loadedInterpreter = await Interpreter.fromAsset(modelAsset, options: interpreterOptions);
      _interpreter = loadedInterpreter;

      _interpreter!.allocateTensors();
      var inputTensors = _interpreter!.getInputTensors();
      if (inputTensors.isNotEmpty) {
        _inputShape = inputTensors[0].shape;
        _logger.i('Model loaded. Input shape: $_inputShape');
      } else {
        _logger.w('Model loaded, but input tensor information is unavailable.');
      }
      _isModelLoaded = true;

    } catch (e, stackTrace) {
      _logger.e('Error loading TFLite model', e, stackTrace);
      _isModelLoaded = false;
      _interpreter?.close();
      _interpreter = null;
      rethrow;
    }
  }

  /// Disposes of the TFLite interpreter resources.
  void dispose() {
    _logger.i("Closing TFLite interpreter.");
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    _inputShape = null;
  }

  /// Prepares input data to match the model's expected length (150).
  List<double> _prepareInputData(List<double> impactArray) {
    const int expectedLength = 150; // Model's expected sequence length

    if (impactArray.length == expectedLength) {
      return impactArray;
    }

    if (impactArray.length == 300) {
      return impactArray.sublist(75, 225); // Take middle 150
    }

    if (impactArray.length > expectedLength) {
      _logger.w('Input length ${impactArray.length} > $expectedLength. Using center $expectedLength values.');
      final int startIndex = (impactArray.length - expectedLength) ~/ 2;
      return impactArray.sublist(startIndex, startIndex + expectedLength);
    } else { // impactArray.length < expectedLength
      _logger.w('Input length ${impactArray.length} < $expectedLength. Padding with zeros.');
      return List<double>.from(impactArray)
        ..addAll(List.filled(expectedLength - impactArray.length, 0.0));
    }
  }

  /// Normalizes the signal using Z-score normalization (mean=0, std=1).
  List<double> _normalizeSignal(List<double> signal) {
    if (signal.isEmpty) {
      _logger.w('Attempting to normalize an empty signal.');
      return [];
    }

    final double sum = signal.fold(0.0, (prev, element) => prev + element);
    final double mean = sum / signal.length;

    double sumSquaredDiff = 0.0;
    for (final double value in signal) {
      sumSquaredDiff += pow(value - mean, 2);
    }
    final double variance = signal.isNotEmpty ? sumSquaredDiff / signal.length : 0.0;
    double std = sqrt(variance);

    const double epsilon = 1e-6;
    if (std < epsilon) {
      _logger.w('Signal standard deviation is near zero ($std). Using epsilon ($epsilon).');
      std = epsilon;
    }

    final List<double> normalized = List.filled(signal.length, 0.0);
    for (int i = 0; i < signal.length; i++) {
      normalized[i] = (signal[i] - mean) / std;
    }
    return normalized;
  }

  /// Predicts if the impact corresponds to a sweet spot hit.
  Future<bool> predictSweetSpot(List<double> impactArray) async {
    if (!_isModelLoaded || _interpreter == null) {
      _logger.w('Model not loaded. Attempting load...');
      try {
        await loadModel();
      } catch (e) {
        _logger.e('Model failed to load during prediction attempt.', e);
        return false;
      }
      if (!_isModelLoaded || _interpreter == null) {
        _logger.e('Model unavailable after load attempt.');
        return false;
      }
    }

    if (_inputShape == null || _inputShape!.length != 3) {
      _logger.e('Model input shape is unknown or invalid ($_inputShape). Cannot proceed.');
      return false;
    }

    const int expectedLength = 150;
    if (_inputShape![1] != expectedLength) {
      _logger.e('Model expected sequence length (${_inputShape![1]}) differs from processing length ($expectedLength).');
      return false;
    }
    if (_inputShape![2] != 1) {
      _logger.e('Model expected feature dimension (${_inputShape![2]}) is not 1.');
      return false;
    }

    try {
      final List<double> preparedArray = _prepareInputData(impactArray);
      if (preparedArray.length != expectedLength) {
        _logger.e('Prepared data length ${preparedArray.length} != expected $expectedLength.');
        return false;
      }

      final List<double> normalized = _normalizeSignal(preparedArray);

      final List<List<List<double>>> input = List.generate(1,
              (_) => List.generate(expectedLength, (j) => [normalized[j]])
      );

      final List<List<double>> output = List.generate(1, (_) => List.filled(1, 0.0));

      _logger.d('Running inference...');
      _interpreter!.run(input, output);
      _logger.d('Inference complete.');

      final double confidence = output[0][0];
      final bool isSweetSpot = confidence > 0.5; // Threshold

      _logger.i('Prediction Confidence: $confidence -> IsSweetSpot: $isSweetSpot');
      return isSweetSpot;

    } catch (e, stackTrace) {
      _logger.e('Error during prediction', e, stackTrace);
      return false;
    }
  }
}


/// Determines if an [Impact] corresponds to a sweet spot hit.
/// Caches the result in `impact.isSweetSpot`.
Future<bool> isSweetSpot(Impact impact) async {
  final logger = SweetSpotDetector._logger;

  if (impact.isSweetSpot) {
    return true; // Return cached result
  }

  try {
    final detector = SweetSpotDetector();

    if (!detector.isModelLoaded) {
      await detector.loadModel();
    }

    if (detector.isModelLoaded && impact.impactArray.isNotEmpty) {
      final bool prediction = await detector.predictSweetSpot(impact.impactArray);
      impact.isSweetSpot = prediction;
      return prediction;
    } else if (!detector.isModelLoaded) {
      logger.w('Sweet spot detection skipped: Model not loaded.');
    } else {
      logger.w('Sweet spot detection skipped: Impact array is empty.');
    }
  } catch (e, stackTrace) {
    logger.e('Error during sweet spot detection', e, stackTrace);
  }

  return false;
}