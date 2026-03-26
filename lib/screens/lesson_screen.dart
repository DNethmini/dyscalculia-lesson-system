import 'package:flutter/material.dart';
import 'speech_screen.dart';
import 'drawing_screen.dart';

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Choose a Lesson'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // ── Welcome banner ────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(children: [
              const Text('👋 Hello!',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'Pick a lesson and start\npracticing numbers!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(.85),
                  height: 1.5,
                ),
              ),
            ]),
          ),

          const SizedBox(height: 28),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'What do you want to practice?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Speech card ───────────────────────────
          _LessonCard(
            emoji: '🎤',
            title: 'Speak Numbers',
            subtitle: 'Say the answer out loud!',
            color: Colors.green.shade600,
            shadowColor: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SpeechScreen()),
            ),
          ),

          const SizedBox(height: 16),

          // ── Drawing card ──────────────────────────
          _LessonCard(
            emoji: '✏️',
            title: 'Draw Numbers',
            subtitle: 'Write the answer with your finger!',
            color: Colors.deepPurple,
            shadowColor: Colors.deepPurple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const DrawingScreen()),
            ),
          ),

          const SizedBox(height: 32),

          // ── Tip box ───────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.amber.shade300, width: 1.5),
            ),
            child: Row(children: [
              const Text('💡',
                  style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Try both lessons every day\nto improve your score!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.amber.shade900,
                    height: 1.5,
                  ),
                ),
              ),
            ]),
          ),

        ]),
      ),
    );
  }
}

// ── Lesson card widget ────────────────────────────
class _LessonCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color  color;
  final Color  shadowColor;
  final VoidCallback onTap;

  const _LessonCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(children: [

          // Emoji bubble
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 34)),
            ),
          ),

          const SizedBox(width: 18),

          // Text
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(.85),
                  )),
            ],
          )),

          // Arrow
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),

        ]),
      ),
    );
  }
}