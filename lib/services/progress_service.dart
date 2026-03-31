import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _drawingKey    = 'drawing_progress';
  static const String _speechKey     = 'speech_progress';
  static const String _wrongCountKey = 'wrong_counts';
  static const String _teacherPin    = 'teacher_pin';
  static const String _defaultPin    = '1234';

  // ── Save drawing attempt ──────────────────────
  static Future<void> saveDrawingAttempt({
    required bool   isCorrect,
    required String question,
    required int    answer,
    required String predicted,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Save attempt history
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
      'timestamp': DateTime.now().toIso8601String(),
      'type':      'drawing',
    });

    await prefs.setString(
        _drawingKey, jsonEncode(history));

    // Track wrong counts per question
    if (!isCorrect) {
      await _incrementWrongCount(
          'drawing_$question');
    } else {
      await _resetWrongCount('drawing_$question');
    }
  }

  // ── Save speech attempt ───────────────────────
  static Future<void> saveSpeechAttempt({
    required bool   isCorrect,
    required String question,
    required int    answer,
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
      'timestamp': DateTime.now().toIso8601String(),
      'type':      'speech',
    });

    await prefs.setString(
        _speechKey, jsonEncode(history));

    if (!isCorrect) {
      await _incrementWrongCount(
          'speech_$question');
    } else {
      await _resetWrongCount('speech_$question');
    }
  }

  // ── Get wrong count for a question ───────────
  static Future<int> getWrongCount(
      String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data  = prefs.getString(_wrongCountKey);
    if (data == null) return 0;
    final map = Map<String, dynamic>.from(
        jsonDecode(data));
    return (map[key] ?? 0) as int;
  }

  // ── Increment wrong count ─────────────────────
  static Future<void> _incrementWrongCount(
      String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data  = prefs.getString(_wrongCountKey);
    final map   = data != null
        ? Map<String, dynamic>.from(
        jsonDecode(data))
        : <String, dynamic>{};
    map[key] = ((map[key] ?? 0) as int) + 1;
    await prefs.setString(
        _wrongCountKey, jsonEncode(map));
  }

  // ── Reset wrong count on correct answer ──────
  static Future<void> _resetWrongCount(
      String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data  = prefs.getString(_wrongCountKey);
    if (data == null) return;
    final map = Map<String, dynamic>.from(
        jsonDecode(data));
    map[key] = 0;
    await prefs.setString(
        _wrongCountKey, jsonEncode(map));
  }

  // ── Get drawing progress ──────────────────────
  static Future<Map<String, dynamic>>
  getDrawingProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data  = prefs.getString(_drawingKey);
    if (data == null) {
      return {'total': 0, 'correct': 0, 'history': []};
    }
    final history = List<Map<String, dynamic>>
        .from(jsonDecode(data));
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
    final data  = prefs.getString(_speechKey);
    if (data == null) {
      return {'total': 0, 'correct': 0, 'history': []};
    }
    final history = List<Map<String, dynamic>>
        .from(jsonDecode(data));
    final correct = history
        .where((h) => h['correct'] == true)
        .length;
    return {
      'total':   history.length,
      'correct': correct,
      'history': history,
    };
  }

  // ── Get per-digit analytics ───────────────────
  static Future<Map<int, Map<String, int>>>
  getDigitAnalytics() async {
    final prefs = await SharedPreferences.getInstance();

    final Map<int, Map<String, int>> result = {};
    for (int i = 0; i <= 9; i++) {
      result[i] = {'correct': 0, 'wrong': 0};
    }

    // Drawing history
    final drawData = prefs.getString(_drawingKey);
    if (drawData != null) {
      final history = List<Map<String, dynamic>>
          .from(jsonDecode(drawData));
      for (final h in history) {
        final ans = h['answer'] as int?;
        if (ans != null && ans >= 0 && ans <= 9) {
          if (h['correct'] == true) {
            result[ans]!['correct'] =
                result[ans]!['correct']! + 1;
          } else {
            result[ans]!['wrong'] =
                result[ans]!['wrong']! + 1;
          }
        }
      }
    }

    // Speech history
    final speechData = prefs.getString(_speechKey);
    if (speechData != null) {
      final history = List<Map<String, dynamic>>
          .from(jsonDecode(speechData));
      for (final h in history) {
        final ans = h['answer'] as int?;
        if (ans != null && ans >= 0 && ans <= 9) {
          if (h['correct'] == true) {
            result[ans]!['correct'] =
                result[ans]!['correct']! + 1;
          } else {
            result[ans]!['wrong'] =
                result[ans]!['wrong']! + 1;
          }
        }
      }
    }

    return result;
  }

  // ── Get mistake patterns ──────────────────────
  static Future<List<Map<String, dynamic>>>
  getMistakePatterns() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> patterns = [];

    // Drawing mistakes
    final drawData = prefs.getString(_drawingKey);
    if (drawData != null) {
      final history = List<Map<String, dynamic>>
          .from(jsonDecode(drawData));
      final wrongOnes =
      history.where((h) => h['correct'] == false);

      final Map<String, int> counts = {};
      for (final h in wrongOnes) {
        final key =
            "${h['question']} → wrote ${h['predicted']}";
        counts[key] = (counts[key] ?? 0) + 1;
      }

      counts.forEach((pattern, count) {
        if (count >= 2) {
          patterns.add({
            'pattern': pattern,
            'count':   count,
            'type':    'drawing',
          });
        }
      });
    }

    // Speech mistakes
    final speechData = prefs.getString(_speechKey);
    if (speechData != null) {
      final history = List<Map<String, dynamic>>
          .from(jsonDecode(speechData));
      final wrongOnes =
      history.where((h) => h['correct'] == false);

      final Map<String, int> counts = {};
      for (final h in wrongOnes) {
        final key =
            "${h['question']} → said ${h['spoken']}";
        counts[key] = (counts[key] ?? 0) + 1;
      }

      counts.forEach((pattern, count) {
        if (count >= 2) {
          patterns.add({
            'pattern': pattern,
            'count':   count,
            'type':    'speech',
          });
        }
      });
    }

    patterns.sort((a, b) =>
        (b['count'] as int)
            .compareTo(a['count'] as int));
    return patterns;
  }

  // ── PIN management ────────────────────────────
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_teacherPin)
        ?? _defaultPin;
    return pin == saved;
  }

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teacherPin, pin);
  }

  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_teacherPin)
        ?? _defaultPin;
  }

  // ── Clear methods ─────────────────────────────
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_drawingKey);
    await prefs.remove(_speechKey);
    await prefs.remove(_wrongCountKey);
  }

  static Future<void> clearDrawing() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_drawingKey);
  }

  static Future<void> clearSpeech() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_speechKey);
  }
}