import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../services/progress_service.dart';
import 'speech_progress_screen.dart';

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() => _SpeechScreenState();
}

class _SpeechScreenState extends State<SpeechScreen>
    with SingleTickerProviderStateMixin {

  final SpeechToText _stt    = SpeechToText();
  final Random       _random = Random();

  bool    _sttReady      = false;
  bool    _isListening   = false;
  String  _liveText      = '';
  String? _feedback;
  String? _spokenWord;
  int     _score         = 0;
  int     _totalAttempts = 0;
  String  _localeId      = 'en_US';

  // ── This flag is set BEFORE calling _stt.listen()
  //    so status callbacks always see the correct state
  bool _expectingResults = false;

  late AnimationController  _anim;
  late Animation<double>    _pulse;
  late Map<String, dynamic> _task;

  static const Map<String, int> _wordMap = {
    'zero': 0,  'o': 0,
    'one':  1,  'won': 1,  'wan': 1,
    'two':  2,  'to':  2,  'too': 2,
    'three':3,  'tree':3,  'free':3,
    'four': 4,  'for': 4,  'fore':4,
    'five': 5,  'hive':5,
    'six':  6,  'sex': 6,  'sicks':6,
    'seven':7,  'sevan':7,
    'eight':8,  'ate': 8,  'ait': 8,
    'nine': 9,  'nein':9,  'nain':9,
  };

  static const Map<int, String> _numWord = {
    0:'zero', 1:'one',   2:'two',
    3:'three',4:'four',  5:'five',
    6:'six',  7:'seven', 8:'eight', 9:'nine',
  };

  static const Map<int, String> _sinhala = {
    0:'බිංදුව', 1:'එක',  2:'දෙක',
    3:'තුන',    4:'හතර', 5:'පහ',
    6:'හය',     7:'හත',  8:'අට',
    9:'නවය',
  };

  // The last recognised text — updated by every partial result
  String _buffer = '';

  @override
  void initState() {
    super.initState();
    _task = _genTask();
    _initSTT();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _stt.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  Future<void> _initSTT() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (err) {
          debugPrint('STT error: ${err.errorMsg}');
          // network_timeout / no-match errors still have valid buffer text
          if (_expectingResults && _buffer.trim().isNotEmpty) {
            _expectingResults = false;
            _handleResult(_buffer.trim());
          } else {
            _expectingResults = false;
            setState(() {
              _isListening = false;
              if (_buffer.isEmpty) {
                _feedback = '⚠️ Nothing heard!\nTry again.';
              }
            });
          }
        },
        onStatus: (status) {
          debugPrint('STT status: $status');
          // "done" / "notListening" = microphone has closed
          if (status == 'done' || status == 'notListening') {
            if (_expectingResults) {
              _expectingResults = false;
              final text = _buffer.trim();
              setState(() => _isListening = false);
              if (text.isNotEmpty) {
                _handleResult(text);
              } else {
                setState(() => _feedback = '⚠️ Nothing heard!\nTry again.');
              }
            } else {
              setState(() => _isListening = false);
            }
          }
        },
      );

      if (_sttReady) {
        final locales = await _stt.locales();
        final en = locales.firstWhere(
              (l) => l.localeId.startsWith('en'),
          orElse: () => locales.first,
        );
        _localeId = en.localeId;
        debugPrint('✅ STT ready — $_localeId');
      }
      setState(() {});
    } catch (e) {
      debugPrint('STT init: $e');
    }
  }

  // ─────────────────────────────────────────────
  Map<String, dynamic> _genTask() {
    int a, b, ans;
    String q;
    switch (_random.nextInt(4)) {
      case 0:
        a = _random.nextInt(5); b = _random.nextInt(10 - a);
        ans = a + b; q = 'What is $a + $b?'; break;
      case 1:
        b = _random.nextInt(9); a = b + _random.nextInt(10 - b);
        ans = a - b; q = 'What is $a - $b?'; break;
      case 2:
        a = _random.nextInt(4); b = _random.nextInt(4);
        ans = a * b; q = 'What is $a × $b?'; break;
      default:
        ans = _random.nextInt(8) + 1; b = _random.nextInt(4) + 1; a = ans * b;
        q = 'What is $a ÷ $b?';
    }
    return {'question': q, 'answer': ans};
  }

  // ─────────────────────────────────────────────
  Future<void> _startListening() async {
    if (_isListening || !_sttReady) return;

    _buffer           = '';
    _expectingResults = true;          // set BEFORE listen()

    setState(() {
      _isListening = true;
      _liveText    = '';
      _spokenWord  = null;
      _feedback    = null;
    });

    try {
      await _stt.listen(
        onResult:       _onResult,
        localeId:       _localeId,
        listenFor:      const Duration(seconds: 8),
        pauseFor:       const Duration(seconds: 2),
        partialResults: true,
        cancelOnError:  false,
      );
    } catch (e) {
      debugPrint('listen() error: $e');
      // Retry without locale specifier
      try {
        await _stt.listen(
          onResult:       _onResult,
          listenFor:      const Duration(seconds: 8),
          pauseFor:       const Duration(seconds: 2),
          partialResults: true,
          cancelOnError:  false,
        );
      } catch (e2) {
        _expectingResults = false;
        setState(() { _isListening = false; _feedback = '❌ Cannot listen.'; });
      }
    }
  }

  // ─────────────────────────────────────────────
  Future<void> _stopListening() async {
    if (!_isListening) return;
    _expectingResults = false;
    await _stt.stop();
    setState(() => _isListening = false);

    final text = _buffer.trim();
    if (text.isNotEmpty) {
      _handleResult(text);
    } else {
      setState(() => _feedback = '⚠️ Nothing heard!\nTry again.');
    }
  }

  // ─────────────────────────────────────────────
  void _onResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    debugPrint('onResult partial=${!result.finalResult} words="$words"');

    if (words.isNotEmpty) _buffer = words;   // keep updating buffer
    setState(() => _liveText = words);

    if (result.finalResult && words.isNotEmpty) {
      _expectingResults = false;
      setState(() => _isListening = false);
      _handleResult(words);
    }
  }

  // ─────────────────────────────────────────────
  void _handleResult(String text) {
    debugPrint('🗣️ Heard: "$text"');

    final lower = text.toLowerCase().trim();
    final words = lower.split(RegExp(r'\s+'));
    final exp   = _task['answer'] as int;

    int?    found;
    String? foundWord;

    // Pass 1 — token by token
    for (final w in words) {
      final n = int.tryParse(w);
      if (n != null && n >= 0 && n <= 9) { found = n; foundWord = w; break; }
      if (_wordMap.containsKey(w)) { found = _wordMap[w]; foundWord = w; break; }
    }

    // Pass 2 — substring scan, longest key first
    if (found == null) {
      for (final k in (_wordMap.keys.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))) {
        if (lower.contains(k)) { found = _wordMap[k]; foundWord = k; break; }
      }
    }

    _totalAttempts++;
    final bool isCorrect =
        found != null && found == exp;
    if (isCorrect) _score++;

    final String fb;
    if (found == exp) {
      _score++;

      fb = '✅ Correct!\n${_task["question"]} = $exp';
    } else if (found != null) {
      fb = '❌ Try again!\nAnswer: $exp (${_numWord[exp]})\n'
          'You said: $found (${_numWord[found] ?? ""})';
    } else {
      fb = '⚠️ Not recognized!\nSay "${_numWord[exp]}" clearly.\n'
          'You said: "$text"';
    }

    setState(() { _spokenWord = foundWord ?? text; _feedback = fb;_isListening=false;});
  }

  void _next() => setState(() {
    _task = _genTask(); _spokenWord = null;
    _feedback = null; _liveText = ''; _buffer = '';
  });

  void _retry() => setState(() {
    _spokenWord = null; _feedback = null; _liveText = ''; _buffer = '';
  });

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final int    ans  = _task['answer'] as int;
    final String word = _numWord[ans] ?? '$ans';
    final String sinh = _sinhala[ans] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Speech Practice'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
                Icons.bar_chart_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                const SpeechProgressScreen(),
              ),
            ),
            tooltip: "My Progress",
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(
              'Score: $_score/$_totalAttempts',
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            )),
          ),
        ],
      ),
      body: Column(children: [

        // ── Question ─────────────────────────────
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.deepPurple,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
              color: Colors.deepPurple.withOpacity(.3),
              blurRadius: 10, offset: const Offset(0, 4),
            )],
          ),
          child: Column(children: [
            const Text('Solve this:',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            Text(_task['question'],
                style: const TextStyle(
                    color: Colors.white, fontSize: 34,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Say the answer in English',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
          ]),
        ),

        // ── Mic area ─────────────────────────────
        Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.deepPurple.withOpacity(.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Hint card — shown only when idle and no feedback yet
              if (!_isListening && _feedback == null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.deepPurple.withOpacity(.2)),
                  ),
                  child: Column(children: [
                    const Text('Say:',
                        style: TextStyle(fontSize: 13, color: Colors.deepPurple)),
                    const SizedBox(height: 4),
                    Text(word,
                        style: const TextStyle(
                            fontSize: 38, color: Colors.deepPurple,
                            fontWeight: FontWeight.bold)),
                    if (sinh.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sinh,
                          style: TextStyle(
                              fontSize: 18,
                              color: Colors.deepPurple.withOpacity(.5))),
                    ],
                  ]),
                ),

              // Live transcript bubble
              if (_isListening && _liveText.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(
                      bottom: 16, left: 16, right: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_liveText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18, color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              // Mic button
              AnimatedBuilder(
                animation: _pulse,
                builder: (ctx, _) => Transform.scale(
                  scale: _isListening ? _pulse.value : 1.0,
                  child: GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: Container(
                      width: 130, height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !_sttReady
                            ? Colors.grey
                            : _isListening
                            ? Colors.red
                            : Colors.deepPurple,
                        boxShadow: [BoxShadow(
                          color: (!_sttReady
                              ? Colors.grey
                              : _isListening ? Colors.red : Colors.deepPurple)
                              .withOpacity(.4),
                          blurRadius: 20, spreadRadius: 4,
                        )],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white, size: 60,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                !_sttReady
                    ? 'Speech not available'
                    : _isListening
                    ? '🔴 Tap mic to stop'
                    : 'Tap mic then speak',
                style: TextStyle(
                  fontSize: 15,
                  color: _isListening ? Colors.red : Colors.grey.shade600,
                  fontWeight: _isListening
                      ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        )),

        // ── You said ─────────────────────────────
        if (_spokenWord != null)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            child: Text('You said: $_spokenWord',
              style: const TextStyle(
                  fontSize: 18, color: Colors.deepPurple,
                  fontWeight: FontWeight.w600),
            ),
          ),

        // ── Feedback ─────────────────────────────
        if (_feedback != null)
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _feedback!.contains('✅')
                  ? Colors.green.shade50
                  : _feedback!.contains('⚠️')
                  ? Colors.orange.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _feedback!.contains('✅')
                  ? Colors.green
                  : _feedback!.contains('⚠️')
                  ? Colors.orange : Colors.red),
            ),
            child: Text(_feedback!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold,
                color: _feedback!.contains('✅')
                    ? Colors.green.shade800
                    : _feedback!.contains('⚠️')
                    ? Colors.orange.shade800
                    : Colors.red.shade800,
              ),
            ),
          ),

        // ── Buttons ───────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _isListening ? null : _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                side: const BorderSide(color: Colors.deepPurple),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: _isListening ? null : _next,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ]),
        ),

      ]),
    );
  }
}