import 'package:flutter/material.dart';
import 'speech_screen.dart';
import 'drawing_screen.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose a Lesson")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LessonButton(
              title: "🎤 Speak Numbers",
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  SpeechScreen(),
                  ),
                );
              },
            ),
            LessonButton(
              title: "✍ Draw Numbers",
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>  DrawingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class LessonButton extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback onTap;

  const LessonButton({
    super.key,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 100,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
