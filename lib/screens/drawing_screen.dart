import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import '../ml/image_model.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  final List<Offset?> points = [];
  final ImageModel model = ImageModel();
  int? prediction;
  String? feedback;

  // List of tasks (question + correct answer)
  final List<Map<String, dynamic>> tasks = [
    {"question": "What is 2 + 2?", "answer": 4},
    {"question": "What is 5 - 3?", "answer": 2},
    {"question": "What is 3 × 3?", "answer": 9},
    {"question": "What is 10 ÷ 2?", "answer": 5},
    {"question": "What is 7 + 6?", "answer": 13},
    {"question": "What is 8 - 4?", "answer": 4},
  ];

  int currentTaskIndex = 0;

  String get currentQuestion => tasks[currentTaskIndex]["question"];
  int get expectedAnswer => tasks[currentTaskIndex]["answer"];

  @override
  void initState() {
    super.initState();
    model.loadModel().then((_) {
      setState(() {}); // model ready
    });
  }

  Future<void> _predict() async {
    if (!model.isReady) {
      setState(() {
        feedback = "⚠️ Model not loaded yet. Please wait.";
      });
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawColor(Colors.white, BlendMode.src);

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(280, 280);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final bytes = byteData!.buffer.asUint8List();
    final result = model.predict(bytes);

    setState(() {
      prediction = result;

      if (prediction == expectedAnswer) {
        feedback = "✅ Correct! $currentQuestion = $expectedAnswer.";
      } else {
        feedback =
        "❌ Oops! $currentQuestion = $expectedAnswer, but you wrote $prediction.";
      }
    });
  }

  void _clear() {
    setState(() {
      points.clear();
      prediction = null;
      feedback = null;
    });
  }

  void _nextTask() {
    setState(() {
      currentTaskIndex = (currentTaskIndex + 1) % tasks.length;
      points.clear();
      prediction = null;
      feedback = null;
    });
  }

  void _randomTask() {
    final random = Random();
    setState(() {
      currentTaskIndex = random.nextInt(tasks.length);
      points.clear();
      prediction = null;
      feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Math Practice")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              currentQuestion,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  points.add(details.localPosition);
                });
              },
              onPanEnd: (_) => points.add(null),
              child: CustomPaint(
                painter: DrawPainter(points),
                size: Size.infinite,
              ),
            ),
          ),
          if (prediction != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "Predicted Number: $prediction",
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                feedback!,
                style: TextStyle(
                  fontSize: 20,
                  color: feedback!.contains("Correct")
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(onPressed: _predict, child: const Text("Submit")),
                ElevatedButton(onPressed: _clear, child: const Text("Clear")),
                ElevatedButton(onPressed: _nextTask, child: const Text("Next Task")),
                ElevatedButton(onPressed: _randomTask, child: const Text("Random Task")),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class DrawPainter extends CustomPainter {
  final List<Offset?> points;

  DrawPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
