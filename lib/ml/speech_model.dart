import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

class SpeechModel {
  late Interpreter _interpreter;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('models/speech_cnn_model.tflite');
      _isLoaded = true;
      print("✅ Speech model loaded successfully");
    } catch (e) {
      print("❌ Failed to load speech model: $e");
    }
  }

  bool get isReady => _isLoaded;

  /// Predict from Mel spectrogram features
  /// inputFeatures must be Float32List of size 128*32 (flattened spectrogram)
  int predict(Float32List inputFeatures, int numClasses) {
    if (!isReady) {
      throw Exception("Model not loaded yet.");
    }

    // Reshape to [1, 128, 32, 1] as expected by CNN
    final input = inputFeatures.reshape([1, 128, 32, 1]);

    // Output tensor [1, numClasses]
    final output = List.filled(numClasses, 0.0).reshape([1, numClasses]);

    _interpreter.run(input, output);

    // Argmax
    int predicted = 0;
    double maxScore = output[0][0];
    for (int i = 1; i < numClasses; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        predicted = i;
      }
    }

    return predicted;
  }

  void close() {
    _interpreter.close();
    _isLoaded = false;
  }
}
