import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../ml/speech_model.dart';
import '../services/progress_service.dart';
import '../widgets/hint_widget.dart';
import 'speech_progress_screen.dart';

class SpeechScreen extends StatefulWidget {
  const SpeechScreen({super.key});

  @override
  State<SpeechScreen> createState() =>
      _SpeechScreenState();
}

class _SpeechScreenState
    extends State<SpeechScreen>
    with SingleTickerProviderStateMixin {

  final SpeechModel  _model  = SpeechModel();
  final SpeechToText _stt    = SpeechToText();
  final Random       _random = Random();

  int _selectedMode = 0; // 0=Speak, 1=Upload

  // Speech state
  bool   _sttReady    = false;
  bool   _isListening = false;
  String _liveText    = '';
  String _lastWords   = ''; // tracks last heard words
  String _localeId    = 'en_US';
  bool   _processed   = false; //prevents double processing

  // Upload state
  bool    _isUploading     = false;
  String? _selectedFileName;

  // Result state
  String? _predictedLabel;
  String? _feedback;
  bool    _isCorrect     = false;
  int     _score         = 0;
  int     _totalAttempts = 0;
  bool    _showHint      = false;
  int     _wrongStreak   = 0;

  late AnimationController _anim;
  late Animation<double>   _pulse;
  late Map<String, dynamic> _task;

  static const Map<String, int> _wordMap = {
    'zero': 0,  'o': 0,
    'one':  1,  'won': 1,  'wan': 1,
    'two':  2,  'to':  2,  'too': 2,
    'three':3,  'tree':3,  'free':3,
    'four': 4,  'for': 4,  'fore':4,
    'five': 5,  'hive':5,
    'six':  6,  'sicks':6,
    'seven':7,  'sevan':7,
    'eight':8,  'ate': 8,  'ait': 8,
    'nine': 9,  'nein':9,  'nain':9,
  };

  static const Map<int, String> _numWord = {
    0:'zero', 1:'one',   2:'two',
    3:'three',4:'four',  5:'five',
    6:'six',  7:'seven', 8:'eight',
    9:'nine',
  };

  @override
  void initState() {
    super.initState();
    _task = _genTask();
    _model.loadModel()
        .then((_) => setState(() {}));
    _initSTT();

    _anim = AnimationController(
      vsync: this,
      duration:
      const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _pulse =
        Tween<double>(begin: 1.0, end: 1.12)
            .animate(CurvedAnimation(
          parent: _anim,
          curve: Curves.easeInOut,
        ));
  }

  @override
  void dispose() {
    _anim.dispose();
    _stt.stop();
    _model.dispose();
    super.dispose();
  }

  // Init STT
  Future<void> _initSTT() async {
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          print("STT error: ${e.errorMsg}");
          //On error, process whatever was heard
          if (mounted && _lastWords.isNotEmpty
              && !_processed) {
            _processText(_lastWords);
          } else if (mounted) {
            setState(() => _isListening = false);
          }
        },
        onStatus: (status) {
          print("STT status: $status");
          if (!mounted) return;

          // process the last heard words
          if (status == 'done' ||
              status == 'notListening' ||
              status == 'doneNoResult') {
            if (_lastWords.isNotEmpty &&
                !_processed) {
              _processText(_lastWords);
            } else if (!_processed) {
              setState(() {
                _isListening = false;
                if (_lastWords.isEmpty &&
                    _feedback == null) {
                  _feedback =
                  "Nothing heard!\n"
                      "Tap mic and speak clearly.";
                }
              });
            }
          } else {
            setState(() {
              _isListening = status == 'listening';
            });
          }
        },
      );

      if (_sttReady) {
        final locales = await _stt.locales();
        final eng = locales.firstWhere(
              (l) => l.localeId.startsWith('en'),
          orElse: () => locales.first,
        );
        _localeId = eng.localeId;
        print("STT: $_localeId");
      } else {
        print("STT not available");
      }

      if (mounted) setState(() {});
    } catch (e) {
      print("STT init error: $e");
    }
  }

  //Generate task
  Map<String, dynamic> _genTask() {
    int a, b, ans;
    String q;
    switch (_random.nextInt(4)) {
      case 0:
        a = _random.nextInt(5);
        b = _random.nextInt(10 - a);
        ans = a + b;
        q = "What is $a + $b?";
        break;
      case 1:
        b = _random.nextInt(9);
        a = b + _random.nextInt(10 - b);
        ans = a - b;
        q = "What is $a - $b?";
        break;
      case 2:
        a = _random.nextInt(4);
        b = _random.nextInt(4);
        ans = a * b;
        q = "What is $a × $b?";
        break;
      default:
        ans = _random.nextInt(8) + 1;
        b   = _random.nextInt(4) + 1;
        a   = ans * b;
        q   = "What is $a ÷ $b?";
    }
    return {"question": q, "answer": ans};
  }

  // LIVE SPEECH

  Future<void> _startListening() async {
    if (!_sttReady || _isListening) return;

    // Reset state
    setState(() {
      _isListening    = true;
      _liveText       = '';
      _lastWords      = '';      // clear last words
      _processed      = false;   // allow processing
      _predictedLabel = null;
      _feedback       = null;
      _isCorrect      = false;
    });

    try {
      await _stt.listen(
        onResult: _onResult,
        localeId: _localeId,
        listenFor:
        const Duration(seconds: 10),
        pauseFor:
        const Duration(seconds: 3),
        partialResults: true,
        cancelOnError:  false,
        listenMode:
        ListenMode.confirmation,
      );
    } catch (e) {
      print("Listen error: $e");
      if (mounted) {
        setState(() {
          _isListening = false;
          _feedback    = "Mic error: $e";
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _stt.stop();
    } catch (e) {
      print("Stop error: $e");
    }
    //After manual stop, process last words
    if (mounted && _lastWords.isNotEmpty
        && !_processed) {
      _processText(_lastWords);
    } else if (mounted) {
      setState(() => _isListening = false);
    }
  }

  // always store partial results
  void _onResult(SpeechRecognitionResult r) {
    final words = r.recognizedWords.trim();
    print("Result: '$words' "
        "final=${r.finalResult}");

    if (words.isNotEmpty) {
      // Always update live text
      if (mounted) {
        setState(() => _liveText = words);
      }
      // Always store latest words
      _lastWords = words;
    }

    //Process immediately on final result
    if (r.finalResult && !_processed) {
      _processText(words.isNotEmpty
          ? words : _lastWords);
    }
  }

  // Process spoken text
  void _processText(String text) {
    if (_processed) return;   // prevent double call
    _processed = true;

    print("Processing: '$text'");

    if (text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _feedback =
          "Nothing heard!\n"
              "Tap mic and speak clearly.";
          _isCorrect = false;
        });
      }
      return;
    }

    final lower = text.toLowerCase().trim();
    final words = lower.split(RegExp(r'\s+'));
    final exp   = _task["answer"] as int;

    int?    found;
    String? foundWord;

    // Check word by word
    for (final w in words) {
      final n = int.tryParse(w);
      if (n != null && n >= 0 && n <= 9) {
        found = n; foundWord = w; break;
      }
      if (_wordMap.containsKey(w)) {
        found = _wordMap[w];
        foundWord = w; break;
      }
    }

    // Substring fallback
    if (found == null) {
      _wordMap.forEach((w, n) {
        if (found == null &&
            lower.contains(w)) {
          found = n; foundWord = w;
        }
      });
    }

    print("Found: $found, Expected: $exp");

    _totalAttempts++;
    final bool ok =
        found != null && found == exp;

    if (ok) {
      _score++;
      _wrongStreak = 0;
    } else {
      _wrongStreak++;
      if (_wrongStreak >= 2 && mounted) {
        setState(() => _showHint = true);
      }
    }

    // Save async
    ProgressService.saveSpeechAttempt(
      isCorrect: ok,
      question:  _task["question"],
      answer:    exp,
      spoken:    foundWord ?? text,
    ).catchError((e) =>
        print("Save error: $e"));

    // Build feedback
    String fb;
    if (ok) {
      fb = "Correct!\n"
          "${_task["question"]} = $exp "
          "(${_numWord[exp]})";
    } else if (found != null) {
      fb = "Try again!\n"
          "Answer: $exp "
          "(${_numWord[exp]})\n"
          "You said: $found "
          "(${_numWord[found] ?? ''})";
    } else {
      fb = "Not recognised!\n"
          "Say \"${_numWord[exp]}\" clearly.\n"
          "I heard: \"$text\"";
    }

    if (mounted) {
      setState(() {
        _predictedLabel = foundWord ?? text;
        _feedback       = fb;
        _isCorrect      = ok;
        _isListening    = false;
        if (ok) _showHint = false;
      });
    }
  }

  // UPLOAD WAV
  Future<void> _pickAndPredict() async {
    if (!_model.isReady) {
      _snack("Model still loading...");
      return;
    }

    try {
      String? initDir;

      if (Platform.isAndroid) {
        for (final p in [
          '/storage/emulated/0/Music',
          '/storage/emulated/0/Download',
          '/sdcard/Music',
        ]) {
          if (Directory(p).existsSync()) {
            initDir = p; break;
          }
        }
      } else if (Platform.isWindows) {
        final home =
            Platform.environment[
            'USERPROFILE'] ??
                'C:\\Users';
        for (final p in [
          '$home\\Music',
          '$home\\Downloads',
        ]) {
          if (Directory(p).existsSync()) {
            initDir = p; break;
          }
        }
      }

      final result = await FilePicker
          .platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav','WAV'],
        allowMultiple:     false,
        initialDirectory:  initDir,
      );

      if (result == null ||
          result.files.isEmpty) return;

      final picked = result.files.first;
      if (picked.path == null) {
        _snack("Cannot access file");
        return;
      }

      if (mounted) {
        setState(() {
          _isUploading      = true;
          _selectedFileName = picked.name;
          _predictedLabel   = null;
          _feedback         = null;
          _isCorrect        = false;
        });
      }

      final bytes = await File(
          picked.path!).readAsBytes();
      await _processWav(bytes);

    } catch (e) {
      print("Picker error: $e");
      if (mounted) {
        setState(() {
          _isUploading = false;
          _feedback    = "Error: $e";
        });
      }
    }
  }

  Future<void> _processWav(
      Uint8List bytes) async {
    try {
      final label  = _model.predict(bytes);
      final number =
      _model.labelToNumber(label);
      final exp    =
      _task["answer"] as int;

      _totalAttempts++;
      final bool ok =
          number != null && number == exp;

      if (ok) {
        _score++;
        _wrongStreak = 0;
      } else {
        _wrongStreak++;
        if (_wrongStreak >= 2 && mounted) {
          setState(() => _showHint = true);
        }
      }

      ProgressService.saveSpeechAttempt(
        isCorrect: ok,
        question:  _task["question"],
        answer:    exp,
        spoken:    label,
      ).catchError((e) => print(e));

      String fb;
      if (ok) {
        fb = "✅ Correct!\n"
            "${_task["question"]} = $exp "
            "(${_numWord[exp]})";
      } else if (number != null) {
        fb = "❌ Try again!\n"
            "Answer: $exp "
            "(${_numWord[exp]})\n"
            "Model heard: $number "
            "(${_numWord[number] ?? label})";
      } else {
        fb = "⚠️ Could not recognise!\n"
            "Answer: $exp "
            "(${_numWord[exp]})\n"
            "Use an 8000Hz WAV file";
      }

      if (mounted) {
        setState(() {
          _predictedLabel = label;
          _feedback       = fb;
          _isCorrect      = ok;
          _isUploading    = false;
          if (ok) _showHint = false;
        });
      }
    } catch (e) {
      print("WAV error: $e");
      if (mounted) {
        setState(() {
          _feedback    = "❌ Error: $e";
          _isUploading = false;
        });
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
      content:  Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }

  void _next() {
    _stt.stop().catchError((_) {});
    if (mounted) setState(() {
      _task             = _genTask();
      _predictedLabel   = null;
      _feedback         = null;
      _selectedFileName = null;
      _liveText         = '';
      _lastWords        = '';
      _wrongStreak      = 0;
      _showHint         = false;
      _isUploading      = false;
      _isListening      = false;
      _isCorrect        = false;
      _processed        = false;
    });
  }

  void _retry() {
    _stt.stop().catchError((_) {});
    if (mounted) setState(() {
      _predictedLabel   = null;
      _feedback         = null;
      _selectedFileName = null;
      _liveText         = '';
      _lastWords        = '';
      _isUploading      = false;
      _isListening      = false;
      _isCorrect        = false;
      _processed        = false;
    });
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    final int ans = _task["answer"] as int;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
            "Speech Practice"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
                Icons.bar_chart_rounded),
            onPressed: () =>
                Navigator.push(context,
                    MaterialPageRoute(
                      builder: (_) =>
                      const SpeechProgressScreen(),
                    )),
          ),
          Padding(
            padding: const EdgeInsets.only(
                right: 12),
            child: Center(child: Text(
              "Score: $_score/$_totalAttempts",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
            bottom: 24),
        child: Column(children: [

          //Question
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding:
            const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 16),
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
              Text(_task["question"],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight:
                    FontWeight.bold,
                  )),
              const SizedBox(height: 8),
              const Text(
                  "Say or upload your answer",
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13)),
            ]),
          ),

          //Hint
          if (_showHint)
            HintWidget(
              number: ans,
              onClose: () => setState(
                      () => _showHint = false),
            ),

          const SizedBox(height: 8),

          // Mode toggle
          Padding(
            padding:
            const EdgeInsets.symmetric(
                horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                  color: Colors.black
                      .withOpacity(.06),
                  blurRadius: 8,
                )],
              ),
              child: Row(children: [

                Expanded(child:
                GestureDetector(
                  onTap: () {
                    if (_selectedMode != 0) {
                      setState(() {
                        _selectedMode = 0;
                        _retry();
                      });
                    }
                  },
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedMode == 0
                          ? Colors.deepPurple
                          : Colors.transparent,
                      borderRadius:
                      BorderRadius
                          .circular(16),
                    ),
                    child: Column(children: [
                      Icon(Icons.mic_rounded,
                          color:
                          _selectedMode == 0
                              ? Colors.white
                              : Colors.deepPurple,
                          size: 26),
                      const SizedBox(height: 4),
                      Text("Speak",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            _selectedMode == 0
                                ? Colors.white
                                : Colors.deepPurple,
                          )),
                    ]),
                  ),
                )),

                Expanded(child:
                GestureDetector(
                  onTap: () {
                    if (_selectedMode != 1) {
                      setState(() {
                        _selectedMode = 1;
                        _retry();
                      });
                    }
                  },
                  child: Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                        vertical: 14),
                    decoration: BoxDecoration(
                      color: _selectedMode == 1
                          ? Colors.deepPurple
                          : Colors.transparent,
                      borderRadius:
                      BorderRadius
                          .circular(16),
                    ),
                    child: Column(children: [
                      Icon(
                          Icons
                              .upload_file_rounded,
                          color:
                          _selectedMode == 1
                              ? Colors.white
                              : Colors.deepPurple,
                          size: 26),
                      const SizedBox(height: 4),
                      Text("Upload WAV",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                            FontWeight.bold,
                            color:
                            _selectedMode == 1
                                ? Colors.white
                                : Colors.deepPurple,
                          )),
                    ]),
                  ),
                )),

              ]),
            ),
          ),

          const SizedBox(height: 16),

          // Mode content
          if (_selectedMode == 0)
            _buildSpeakUI()
          else
            _buildUploadUI(),

          const SizedBox(height: 12),

          //Live text
          if (_selectedMode == 0 &&
              _liveText.isNotEmpty)
            Container(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4),
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius:
                BorderRadius.circular(10),
                border: Border.all(
                    color:
                    Colors.blue.shade200),
              ),
              child: Row(children: [
                Icon(Icons.hearing,
                    color:
                    Colors.blue.shade700,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  "Heard: \"$_liveText\"",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.blue.shade800,
                    fontWeight:
                    FontWeight.w500,
                  ),
                )),
              ]),
            ),

          // File info
          if (_selectedMode == 1 &&
              _selectedFileName != null)
            Container(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4),
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                    color:
                    Colors.grey.shade300),
              ),
              child: Row(children: [
                const Icon(Icons.audio_file,
                    color: Colors.deepPurple,
                    size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _selectedFileName!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight:
                    FontWeight.w500,
                    color: Colors.deepPurple,
                  ),
                  overflow:
                  TextOverflow.ellipsis,
                )),
                if (_predictedLabel != null)
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                        horizontal: 8,
                        vertical: 4),
                    decoration: BoxDecoration(
                      color: _isCorrect
                          ? Colors.green
                          : Colors.orange,
                      borderRadius:
                      BorderRadius
                          .circular(20),
                    ),
                    child: Text(
                      "→ $_predictedLabel",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ]),
            ),

          // Result card
          if (_predictedLabel != null &&
              !_isUploading)
            Container(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6),
              padding:
              const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(14),
                border: Border.all(
                  color: _isCorrect
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black
                      .withOpacity(.05),
                  blurRadius: 8,
                )],
              ),
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCorrect
                        ? Colors.green
                        : Colors.orange,
                  ),
                  child: Center(child: Text(
                    _predictedLabel!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  )),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        _selectedMode == 0
                            ? "You said: "
                            : "Model heard: ",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Flexible(child: Text(
                        _numWord[int.tryParse(
                            _predictedLabel!)
                            ?? -1] ??
                            _predictedLabel!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      )),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Text(
                        "Expected: ",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        "${_numWord[ans] ?? ''} ($ans)",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w600,
                          color: _isCorrect
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ]),
                  ],
                )),
                Icon(
                  _isCorrect
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: _isCorrect
                      ? Colors.green
                      : Colors.orange,
                  size: 30,
                ),
              ]),
            ),

          // Feedback card
          if (_feedback != null)
            Container(
              margin:
              const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4),
              padding:
              const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isCorrect
                    ? Colors.green.shade50
                    : _feedback!.contains("⚠️")
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                borderRadius:
                BorderRadius.circular(12),
                border: Border.all(
                  color: _isCorrect
                      ? Colors.green
                      : _feedback!.contains("⚠️")
                      ? Colors.orange
                      : Colors.red,
                ),
              ),
              child: Text(
                _feedback!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isCorrect
                      ? Colors.green.shade800
                      : _feedback!.contains("⚠️")
                      ? Colors.orange.shade800
                      : Colors.red.shade800,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Buttons
          Padding(
            padding:
            const EdgeInsets.symmetric(
                horizontal: 16),
            child: Row(children: [
              Expanded(child:
              OutlinedButton.icon(
                onPressed: _isUploading ||
                    _isListening
                    ? null : _retry,
                icon: const Icon(
                    Icons.refresh),
                label: const Text(
                    "Try Again"),
                style:
                OutlinedButton.styleFrom(
                  foregroundColor:
                  Colors.deepPurple,
                  side: const BorderSide(
                      color:
                      Colors.deepPurple),
                  padding:
                  const EdgeInsets
                      .symmetric(
                      vertical: 14),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius
                        .circular(12),
                  ),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ||
                      _isListening
                      ? null : _next,
                  icon: const Icon(
                      Icons.arrow_forward),
                  label:
                  const Text("Next"),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    Colors.green,
                    foregroundColor:
                    Colors.white,
                    padding:
                    const EdgeInsets
                        .symmetric(
                        vertical: 14),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius
                          .circular(12),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }


  // SPEAK UI
  Widget _buildSpeakUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black
                .withOpacity(.06),
            blurRadius: 10,
          )],
        ),
        child: Column(children: [

          // Status
          Text(
            !_sttReady
                ? "🎤 Speech not available"
                : _isListening
                ? "🔴 Listening... speak now!"
                : _feedback != null
                ? "Done!"
                : "Tap mic to speak",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: _isListening
                  ? Colors.red
                  : Colors.grey.shade600,
              fontWeight: _isListening
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),

          const SizedBox(height: 20),

          // Mic button
          AnimatedBuilder(
            animation: _pulse,
            builder: (ctx, _) =>
                Transform.scale(
                  scale: _isListening
                      ? _pulse.value : 1.0,
                  child: GestureDetector(
                    onTap: () async {
                      if (_isListening) {
                        await _stopListening();
                      } else if (
                      _feedback == null) {
                        await _startListening();
                      }
                    },
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !_sttReady
                            ? Colors.grey.shade400
                            : _isListening
                            ? Colors.red
                            : _feedback != null
                            ? Colors
                            .grey.shade400
                            : Colors
                            .deepPurple,
                        boxShadow: [BoxShadow(
                          color: (!_sttReady
                              ? Colors.grey
                              : _isListening
                              ? Colors.red
                              : Colors.deepPurple)
                              .withOpacity(.35),
                          blurRadius: 20,
                          spreadRadius: 4,
                        )],
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
          ),

          const SizedBox(height: 16),

          Container(
            padding:
            const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8),
            decoration: BoxDecoration(
              color: _isListening
                  ? Colors.red.shade50
                  : Colors.deepPurple
                  .withOpacity(.08),
              borderRadius:
              BorderRadius.circular(20),
              border: _isListening
                  ? Border.all(
                  color:
                  Colors.red.shade200)
                  : null,
            ),
            child: Text(
              _isListening
                  ? "Tap mic again to stop"
                  : _feedback != null
                  ? "Tap Try Again or Next"
                  : "Tap once to start, "
                  "tap again to stop",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isListening
                    ? Colors.red
                    : Colors.deepPurple,
                fontSize: 12,
                fontWeight: _isListening
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ]),
      ),
    );
  }


  // UPLOAD UI
  Widget _buildUploadUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: Colors.black
                .withOpacity(.06),
            blurRadius: 10,
          )],
        ),
        child: Column(children: [

          Container(
            padding:
            const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius:
              BorderRadius.circular(10),
              border: Border.all(
                  color:
                  Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline,
                  color:
                  Colors.blue.shade700,
                  size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                "Upload a WAV file from "
                    "the FSDD dataset "
                    "(8000 Hz mono WAV)",
                style: TextStyle(
                  fontSize: 12,
                  color:
                  Colors.blue.shade700,
                ),
              )),
            ]),
          ),

          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _pulse,
            builder: (ctx, _) =>
                Transform.scale(
                  scale: _isUploading
                      ? _pulse.value : 1.0,
                  child: GestureDetector(
                    onTap: _isUploading
                        ? null
                        : _pickAndPredict,
                    child: Container(
                      width: double.infinity,
                      padding:
                      const EdgeInsets
                          .symmetric(
                          vertical: 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isUploading
                              ? [Colors.grey.shade400,
                            Colors.grey.shade500]
                              : [Colors.deepPurple,
                            Colors.deepPurple
                                .shade700],
                          begin:
                          Alignment.topLeft,
                          end: Alignment
                              .bottomRight,
                        ),
                        borderRadius:
                        BorderRadius.circular(
                            16),
                        boxShadow: [BoxShadow(
                          color: Colors.deepPurple
                              .withOpacity(.3),
                          blurRadius: 12,
                          offset:
                          const Offset(0, 4),
                        )],
                      ),
                      child: Column(children: [
                        Icon(
                          _isUploading
                              ? Icons.hourglass_top
                              : Icons
                              .upload_file_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isUploading
                              ? "Analysing WAV..."
                              : "Tap to Upload\nWAV File",
                          textAlign:
                          TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        if (!_isUploading) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Opens Music folder",
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
          ),

          if (_isUploading) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(
                color: Colors.deepPurple),
            const SizedBox(height: 8),
            const Text(
              "Running model inference...",
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 13,
              ),
            ),
          ],
        ]),
      ),
    );
  }
}