import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ImageModel {
  Interpreter? _interpreter; // make it nullable
  bool _isLoaded = false;

  /// Load TFLite model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/digit_cnn_model.tflite');
      _isLoaded = true;
      print("✅ Model loaded successfully");
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }
  bool get isReady => _isLoaded && _interpreter != null;

/// Image preprocessing
  Float32List preprocessImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception("Failed to decode image");
    }

    // Resize to 28x28
    img.Image resized = img.copyResize(image, width: 28, height: 28);

    // Convert to grayscale
    img.Image gray = img.grayscale(resized);

    // Normalize pixels
    final Float32List input = Float32List(28 * 28);
    int index = 0;

    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        final pixel = gray.getPixel(x, y);
        final double normalized = pixel.r / 255.0;
        input[index++] = normalized;
      }
    }

    return input;
  }

  /// Predict digit
  int predict(Uint8List imageBytes) {
    if (!_isLoaded || _interpreter == null) {
      throw Exception("Model not loaded yet. Call loadModel() first.");
    }

    final input = preprocessImage(imageBytes);
    final inputTensor = input.reshape([1, 28, 28, 1]);


    final output = List.filled(14, 0.0).reshape([1, 14]);

    _interpreter!.run(inputTensor, output);

    // Argmax
    int predictedIndex = 0;
    double maxScore = output[0][0];

    for (int i = 1; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        predictedIndex = i;
      }
    }

    return predictedIndex;
  }

  void close() {
    _interpreter?.close();
    _isLoaded = false;
  }
}
