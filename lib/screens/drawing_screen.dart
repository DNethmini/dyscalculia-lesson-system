import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import '../ml/image_model.dart';
import '../services/progress_service.dart';
import '../widgets/hint_widget.dart';
import 'drawing_progress_screen.dart';

class DrawingScreen extends StatefulWidget {
  const DrawingScreen({super.key});

  @override
  State<DrawingScreen> createState() =>
      _DrawingScreenState();
}

class _DrawingScreenState
    extends State<DrawingScreen> {

  final List<Offset?> _points  = [];
  final ImageModel    _model   = ImageModel();
  final Random        _random  = Random();

  String? _predictedLabel;
  String? _feedback;
  bool    _isProcessing  = false;
  int     _score         = 0;
  int     _totalAttempts = 0;
  bool    _showHint      = false;
  int     _wrongStreak   = 0;

  Size _canvasSize = const Size(300, 300);

  late Map<String, dynamic> _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = _generateTask();
    _model.loadModel().then(
            (_) => setState(() {}));
  }

  // Generate task
  Map<String, dynamic> _generateTask() {
    int a, b, answer;
    String question;
    final type = _random.nextInt(4);

    switch (type) {
      case 0:
        a = _random.nextInt(5);
        b = _random.nextInt(10 - a);
        answer = a + b;
        question = "What is $a + $b?";
        break;
      case 1:
        b = _random.nextInt(9);
        a = b + _random.nextInt(10 - b);
        answer = a - b;
        question = "What is $a - $b?";
        break;
      case 2:
        a = _random.nextInt(4);
        b = _random.nextInt(4);
        answer = a * b;
        question = "What is $a × $b?";
        break;
      default:
        answer = _random.nextInt(8) + 1;
        b = _random.nextInt(4) + 1;
        a = answer * b;
        question = "What is $a ÷ $b?";
    }

    return {
      "question": question,
      "answer":   answer,
      "expectedLabel": _numberToLabel(answer),
    };
  }

  String _numberToLabel(int n) {
    const labels = {
      0: "zero",  1: "one",   2: "two",
      3: "three", 4: "four",  5: "five",
      6: "six",   7: "seven", 8: "eight",
      9: "nine",
    };
    return labels[n] ?? "zero";
  }

  //Predict
  Future<void> _predict() async {
    if (!_model.isReady) {
      setState(() =>
      _feedback = "Model not loaded!");
      return;
    }
    if (_points.isEmpty) {
      setState(() =>
      _feedback = "✏️ Draw a number first!");
      return;
    }

    setState(() {
      _isProcessing = true;
      _feedback     = null;
    });

    try {
      final recorder = ui.PictureRecorder();
      final canvas   = Canvas(recorder);
      final w = _canvasSize.width;
      final h = _canvasSize.height;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = const ui.Color(0xFFFFFFFF),
      );

      final paint = Paint()
        ..color    = const ui.Color(0xFF000000)
        ..strokeWidth = 20.0
        ..strokeCap   = StrokeCap.round
        ..strokeJoin  = StrokeJoin.round;

      for (int i = 0;
      i < _points.length - 1; i++) {
        if (_points[i] != null &&
            _points[i + 1] != null) {
          canvas.drawLine(
              _points[i]!, _points[i+1]!, paint);
        }
      }

      final picture  = recorder.endRecording();
      final image    = await picture.toImage(
          w.toInt(), h.toInt());
      final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png);
      final bytes    =
      byteData!.buffer.asUint8List();

      final String predicted   =
      _model.predict(bytes);
      final String expected    =
      _currentTask["expectedLabel"];
      final int    expAnswer   =
      _currentTask["answer"] as int;
      final String question    =
      _currentTask["question"];

      final bool isCorrect = predicted == expected;
      _totalAttempts++;

      if (isCorrect) {
        _score++;
        _wrongStreak = 0;
        setState(() => _showHint = false);
      } else {
        _wrongStreak++;
        if (_wrongStreak >= 2) {
          setState(() => _showHint = true);
        }
      }

      // Save progress
      await ProgressService.saveDrawingAttempt(
        isCorrect: isCorrect,
        question:  question,
        answer:    expAnswer,
        predicted: predicted,
      );

      setState(() {
        _predictedLabel = predicted;
        _feedback = isCorrect
            ? "✅ Correct! $question = $expAnswer"
            : "❌ Not quite! $question = $expAnswer\n"
            "You wrote: $predicted";
        _isProcessing = false;
      });

    } catch (e) {
      setState(() {
        _feedback     = "Error: $e";
        _isProcessing = false;
      });
    }
  }

  void _clear() => setState(() {
    _points.clear();
    _predictedLabel = null;
    _feedback       = null;
  });

  void _nextTask() => setState(() {
    _currentTask    = _generateTask();
    _points.clear();
    _predictedLabel = null;
    _feedback       = null;
    _wrongStreak    = 0;
    _showHint       = false;
  });

  @override
  Widget build(BuildContext context) {
    final int answer =
    _currentTask["answer"] as int;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Math Practice"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Progress button
          IconButton(
            icon: const Icon(
                Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) =>
              const DrawingProgressScreen()),
            ),
            tooltip: "My Progress",
          ),
          Padding(
            padding: const EdgeInsets.only(
                right: 12),
            child: Center(
              child: Text(
                "Score: $_score/$_totalAttempts",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [

        //Question card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(
              vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius:
            BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.deepPurple
                  .withOpacity(.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )],
          ),
          child: Column(children: [
            const Text("Solve this:",
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14)),
            const SizedBox(height: 8),
            Text(_currentTask["question"],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),
            const Text("Draw your answer below",
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13)),
          ]),
        ),

        // Hint widgets
        if (_showHint)
          HintWidget(
            number: answer,
            onClose: () =>
                setState(() => _showHint = false),
          ),

        // Drawing canvas
        Expanded(child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(16),
            border: Border.all(
                color: Colors.deepPurple
                    .withOpacity(.3),
                width: 2),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
            )],
          ),
          child: ClipRRect(
            borderRadius:
            BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                _canvasSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  onPanUpdate: (d) =>
                      setState(() =>
                          _points.add(
                              d.localPosition)),
                  onPanEnd: (_) =>
                      _points.add(null),
                  child: CustomPaint(
                    painter: _DrawPainter(
                        _points),
                    size: Size.infinite,
                  ),
                );
              },
            ),
          ),
        )),

        // Predicted label
        if (_predictedLabel != null)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            child: Text(
              "You wrote: $_predictedLabel",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.deepPurple,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        // Feedback
        if (_feedback != null)
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _feedback!.contains("✅")
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius:
              BorderRadius.circular(12),
              border: Border.all(
                  color: _feedback!.contains("✅")
                      ? Colors.green
                      : Colors.red),
            ),
            child: Text(_feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _feedback!.contains("✅")
                    ? Colors.green.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),

        //Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.refresh),
              label: const Text("Clear"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(
                    color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null : _predict,
                  icon: _isProcessing
                      ? const SizedBox(
                      width: 18, height: 18,
                      child:
                      CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isProcessing
                      ? "Checking..." : "Submit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12)),
                  ),
                )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              onPressed: _nextTask,
              icon: const Icon(
                  Icons.arrow_forward),
              label: const Text("Next"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12)),
              ),
            )),
          ]),
        ),
      ]),
    );
  }
}

class _DrawPainter extends CustomPainter {
  final List<Offset?> points;
  _DrawPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width,
            size.height),
        Paint()..color = Colors.white);

    final paint = Paint()
      ..color      = Colors.black
      ..strokeWidth = 20
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null &&
          points[i+1] != null) {
        canvas.drawLine(
            points[i]!, points[i+1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(
      CustomPainter old) => true;
}