import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ImageModel {
  Interpreter? _interpreter;
  List<String> _classNames = [];
  bool _isLoaded = false;

  // ── Load model + class names ──────────────────────────────
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/digit_cnn_model.tflite',
      );
      final jsonStr = await rootBundle.loadString(
        'assets/data/class_names.json',
      );
      _classNames = List<String>.from(jsonDecode(jsonStr));
      _isLoaded = true;
      print("✅ Model loaded. Classes: $_classNames");
    } catch (e) {
      print("❌ Failed to load model: $e");
    }
  }

  bool get isReady => _isLoaded && _interpreter != null;

  // ── Preprocess canvas image ───────────────────────────────
  Float32List preprocessImage(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception("Failed to decode image");

    // Step 1: Convert to grayscale
    img.Image grayscale = img.grayscale(image);

    // Step 2: Find bounding box of dark pixels (strokes)
    // Canvas: white background (255) + black strokes (0)
    int top    = grayscale.height;
    int bottom = 0;
    int left   = grayscale.width;
    int right  = 0;
    bool found = false;

    for (int y = 0; y < grayscale.height; y++) {
      for (int x = 0; x < grayscale.width; x++) {
        final pixel = grayscale.getPixel(x, y);
        if (pixel.r < 200) {
          if (y < top)    top    = y;
          if (y > bottom) bottom = y;
          if (x < left)   left   = x;
          if (x > right)  right  = x;
          found = true;
        }
      }
    }

    print("🔍 Bounding box: found=$found, "
        "top=$top, bottom=$bottom, "
        "left=$left, right=$right");

    // Step 3: Square crop centered on digit
    img.Image cropped;

    if (found) {
      int digitH = bottom - top;
      int digitW = right  - left;

      // Use larger dimension for padding calculation
      int larger = digitH > digitW ? digitH : digitW;
      int pad    = (larger * 0.4).toInt().clamp(15, 80);

      // Make a SQUARE size based on larger dimension
      int size = larger + pad * 2;

      // Center point of the digit
      int centerX = left + digitW ~/ 2;
      int centerY = top  + digitH ~/ 2;

      // Square crop coords centered on digit
      int cropLeft   = (centerX - size ~/ 2).clamp(0, grayscale.width);
      int cropTop    = (centerY - size ~/ 2).clamp(0, grayscale.height);
      int cropRight  = (centerX + size ~/ 2).clamp(0, grayscale.width);
      int cropBottom = (centerY + size ~/ 2).clamp(0, grayscale.height);

      int cropW = cropRight  - cropLeft;
      int cropH = cropBottom - cropTop;

      if (cropW > 5 && cropH > 5) {
        cropped = img.copyCrop(
          grayscale,
          x: cropLeft,
          y: cropTop,
          width: cropW,
          height: cropH,
        );
        print("✂️ Cropped to: ${cropped.width}x${cropped.height}");
      } else {
        print("⚠️ Crop too small, using full image");
        cropped = grayscale;
      }
    } else {
      print("⚠️ No stroke found, using full image");
      cropped = grayscale;
    }

    // Step 4: Resize to 28x28
    img.Image resized = img.copyResize(
      cropped,
      width: 28,
      height: 28,
      interpolation: img.Interpolation.linear,
    );

    // Step 5: Normalize + Invert
    // Canvas: white bg (255) → 0.0, black strokes (0) → 1.0
    Float32List input = Float32List(28 * 28);
    for (int y = 0; y < 28; y++) {
      for (int x = 0; x < 28; x++) {
        final pixel = resized.getPixel(x, y);
        input[y * 28 + x] = 1.0 - (pixel.r / 255.0);
      }
    }

    double maxVal = input.reduce((a, b) => a > b ? a : b);
    double minVal = input.reduce((a, b) => a < b ? a : b);
    print("🖼️ Input stats — min: $minVal, max: $maxVal");

    if (maxVal < 0.1) {
      print("❌ WARNING: Image appears blank!");
    }

    return input;
  }

  // ── Run prediction → returns label string ─────────────────
  String predict(Uint8List imageBytes) {
    if (!isReady) return "Model not loaded";

    try {
      Float32List input = preprocessImage(imageBytes);

      // Shape: [1, 28, 28, 1]
      var inputTensor = input.reshape([1, 28, 28, 1]);

      // Output: [1, 14]
      var output = List.filled(1 * _classNames.length, 0.0)
          .reshape([1, _classNames.length]);

      _interpreter!.run(inputTensor, output);

      List<double> scores = List<double>.from(output[0]);

      // Print only scores above 1%
      print("📊 Scores:");
      for (int i = 0; i < _classNames.length; i++) {
        if (scores[i] > 0.01) {
          print("   ${_classNames[i].padRight(10)}: "
              "${(scores[i] * 100).toStringAsFixed(1)}%");
        }
      }

      int predictedIndex = scores.indexOf(
        scores.reduce((a, b) => a > b ? a : b),
      );

      String label      = _classNames[predictedIndex];
      double confidence = scores[predictedIndex];

      print("✅ Predicted: $label "
          "(${(confidence * 100).toStringAsFixed(1)}%)");
      return label;

    } catch (e) {
      print("❌ Prediction error: $e");
      return "Error";
    }
  }

  // ── Get top 3 predictions ─────────────────────────────────
  List<Map<String, dynamic>> predictTopK(
      Uint8List imageBytes, {int k = 3}) {
    if (!isReady) return [];

    try {
      Float32List input = preprocessImage(imageBytes);

      var inputTensor = input.reshape([1, 28, 28, 1]);
      var output      = List.filled(1 * _classNames.length, 0.0)
          .reshape([1, _classNames.length]);

      _interpreter!.run(inputTensor, output);

      List<double> scores  = List<double>.from(output[0]);
      List<int>    indices = List.generate(scores.length, (i) => i);
      indices.sort((a, b) => scores[b].compareTo(scores[a]));

      return indices.take(k).map((i) => {
        "label":      _classNames[i],
        "confidence": scores[i],
      }).toList();

    } catch (e) {
      print("❌ Prediction error: $e");
      return [];
    }
  }

  // ── Dispose ───────────────────────────────────────────────
  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}