import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen> {
  final AudioRecorder recorder = AudioRecorder();

  bool isRecording = false;
  int? spokenAnswer;
  String? feedback;

  // Math tasks
  final List<Map<String, dynamic>> tasks = [
    {"question": "What is 2 + 2?", "answer": 4},
    {"question": "What is 5 - 3?", "answer": 2},
    {"question": "What is 3 * 3?", "answer": 9},
    {"question": "What is 10 ÷ 2?", "answer": 5},
    {"question": "What is 7 + 6?", "answer": 13},
    {"question": "What is 8 - 4?", "answer": 4},
  ];

  int currentTaskIndex = 0;

  String get currentQuestion => tasks[currentTaskIndex]["question"];
  int get expectedAnswer => tasks[currentTaskIndex]["answer"];

  // ------------------ RECORD VOICE ------------------

  Future<void> startRecording() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) return;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/answer.wav';

    await recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
      ),
      path: path,
    );

    setState(() {
      isRecording = true;
      feedback = "🎤 Listening...";
    });
  }

  Future<void> stopRecording() async {
    final path = await recorder.stop();

    setState(() {
      isRecording = false;
    });

    if (path == null) return;

    // 🔴 TEMPORARY PLACEHOLDER
    // Replace this with your trained speech model
    int predictedNumber = expectedAnswer; // simulate correct answer

    setState(() {
      spokenAnswer = predictedNumber;

      if (spokenAnswer == expectedAnswer) {
        feedback = "✅ Correct! Answer is $expectedAnswer.";
      } else {
        feedback =
        "❌ Incorrect. You said $spokenAnswer, correct answer is $expectedAnswer.";
      }
    });
  }

  // ------------------ TASK CONTROL ------------------

  void nextTask() {
    setState(() {
      currentTaskIndex = (currentTaskIndex + 1) % tasks.length;
      reset();
    });
  }

  void randomTask() {
    setState(() {
      currentTaskIndex = Random().nextInt(tasks.length);
      reset();
    });
  }

  void reset() {
    spokenAnswer = null;
    feedback = null;
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Speak Numbers")),
      body: Center( // ✅ Center everything on the screen
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // ✅ Vertical centering
          crossAxisAlignment: CrossAxisAlignment.center, // ✅ Horizontal centering
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                currentQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (spokenAnswer != null)
              Text(
                "You said: $spokenAnswer",
                style: const TextStyle(fontSize: 22),
              ),

            const SizedBox(height: 10),

            if (feedback != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  feedback!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: feedback!.contains("Correct")
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),

            const SizedBox(height: 30),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(isRecording ? Icons.stop : Icons.mic),
                  label: Text(isRecording ? "Stop Speaking" : "Speak Answer"),
                  onPressed: isRecording ? stopRecording : startRecording,
                ),
                ElevatedButton(
                  onPressed: nextTask,
                  child: const Text("Next Task"),
                ),
                ElevatedButton(
                  onPressed: randomTask,
                  child: const Text("Random Task"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
