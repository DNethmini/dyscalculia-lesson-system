import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _drawingKey = 'drawing_progress';
  static const String _speechKey  = 'speech_progress';

  // ── Save drawing attempt ──────────────────────
  static Future<void> saveDrawingAttempt({
    required bool isCorrect,
    required String question,
    required int answer,
    required String predicted,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_drawingKey);
    final List<Map<String, dynamic>> history =
    existing != null
        ? List<Map<String, dynamic>>.from(
        jsonDecode(existing))
        : [];

    history.add({
      'correct':   isCorrect,
      'question':  question,
      'answer':    answer,
      'predicted': predicted,
      'timestamp': DateTime.now()
          .toIso8601String(),
    });

    await prefs.setString(
        _drawingKey, jsonEncode(history));
  }

  // ── Save speech attempt ───────────────────────
  static Future<void> saveSpeechAttempt({
    required bool isCorrect,
    required String question,
    required int answer,
    required String spoken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_speechKey);
    final List<Map<String, dynamic>> history =
    existing != null
        ? List<Map<String, dynamic>>.from(
        jsonDecode(existing))
        : [];

    history.add({
      'correct':   isCorrect,
      'question':  question,
      'answer':    answer,
      'spoken':    spoken,
      'timestamp': DateTime.now()
          .toIso8601String(),
    });

    await prefs.setString(
        _speechKey, jsonEncode(history));
  }

  // ── Get drawing progress ──────────────────────
  static Future<Map<String, dynamic>>
  getDrawingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_drawingKey);
    if (existing == null) {
      return {
        'total':   0,
        'correct': 0,
        'history': [],
      };
    }
    final List<Map<String, dynamic>> history =
    List<Map<String, dynamic>>.from(
        jsonDecode(existing));
    final correct = history
        .where((h) => h['correct'] == true)
        .length;
    return {
      'total':   history.length,
      'correct': correct,
      'history': history,
    };
  }

  // ── Get speech progress ───────────────────────
  static Future<Map<String, dynamic>>
  getSpeechProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_speechKey);
    if (existing == null) {
      return {
        'total':   0,
        'correct': 0,
        'history': [],
      };
    }
    final List<Map<String, dynamic>> history =
    List<Map<String, dynamic>>.from(
        jsonDecode(existing));
    final correct = history
        .where((h) => h['correct'] == true)
        .length;
    return {
      'total':   history.length,
      'correct': correct,
      'history': history,
    };
  }

  // ── Clear all progress ────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_drawingKey);
    await prefs.remove(_speechKey);
  }

  // ── Clear drawing progress ────────────────────
  static Future<void> clearDrawing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_drawingKey);
  }

  // ── Clear speech progress ─────────────────────
  static Future<void> clearSpeech() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_speechKey);
  }
}