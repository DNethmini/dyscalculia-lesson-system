import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class SpeechProgressScreen extends StatefulWidget {
  const SpeechProgressScreen({super.key});

  @override
  State<SpeechProgressScreen> createState() =>
      _SpeechProgressScreenState();
}

class _SpeechProgressScreenState
    extends State<SpeechProgressScreen>
    with SingleTickerProviderStateMixin {

  bool _loading = true;
  int  _total   = 0;
  int  _correct = 0;
  List _history = [];

  late AnimationController _starAnim;
  late Animation<double>   _starScale;

  @override
  void initState() {
    super.initState();
    _load();

    _starAnim = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 800),
    )..forward();

    _starScale = Tween<double>(
        begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
      parent: _starAnim,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _starAnim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data =
    await ProgressService.getSpeechProgress();
    setState(() {
      _total   = data['total'];
      _correct = data['correct'];
      _history = data['history'];
      _loading = false;
    });
  }

  int get _starCount {
    if (_total == 0) return 0;
    final pct = _correct / _total;
    if (pct >= 0.8) return 3;
    if (pct >= 0.5) return 2;
    if (pct >  0.0) return 1;
    return 0;
  }

  String get _message {
    if (_total == 0) return "No attempts yet!";
    final pct = _correct / _total;
    if (pct >= 0.8) return "Amazing! 🌟";
    if (pct >= 0.5) return "Well done! 👏";
    if (pct >  0.0) return "Keep going! 🎤";
    return "Practice more! 💬";
  }

  Color get _scoreColor {
    if (_total == 0) return Colors.grey;
    final pct = _correct / _total;
    if (pct >= 0.8) return Colors.green;
    if (pct >= 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        title: const Text("🎤 Speech Progress"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () =>
                _confirmClear(context),
            tooltip: "Clear Progress",
          ),
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(
              color: Colors.green))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          _buildStarsCard(),
          const SizedBox(height: 16),

          _buildStatsRow(),
          const SizedBox(height: 16),

          _buildProgressBar(),
          const SizedBox(height: 20),

          if (_history.isNotEmpty) ...[
            const Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                "Recent Attempts",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildHistory(),
          ] else
            _buildEmptyState(),
        ]),
      ),
    );
  }

  Widget _buildStarsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade600,
            Colors.teal.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
            Colors.green.withOpacity(.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        const Text(
          "🎤 Speech Practice",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),

        ScaleTransition(
          scale: _starScale,
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < _starCount;
              return Padding(
                padding:
                const EdgeInsets.symmetric(
                    horizontal: 6),
                child: Icon(
                  filled
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: filled
                      ? Colors.yellow.shade300
                      : Colors.white30,
                  size: 56,
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        Text(
          _message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _total > 0
              ? "$_correct out of "
              "$_total correct"
              : "Start practicing!",
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
        ),
      ]),
    );
  }

  Widget _buildStatsRow() {
    final wrong = _total - _correct;
    final pct   = _total > 0
        ? (_correct / _total * 100).toInt()
        : 0;

    return Row(children: [
      _statCard("✅", "$_correct",
          "Correct", Colors.green),
      const SizedBox(width: 10),
      _statCard("❌", "$wrong",
          "Wrong", Colors.red),
      const SizedBox(width: 10),
      _statCard("🎯", "$pct%",
          "Score", Colors.teal),
    ]);
  }

  Widget _statCard(String emoji, String value,
      String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(
              fontSize: 24)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          )),
          Text(label, style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          )),
        ]),
      ),
    );
  }

  Widget _buildProgressBar() {
    final pct = _total > 0
        ? _correct / _total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
          children: [
            const Text("Progress",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                )),
            Text("${(pct * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _scoreColor,
                )),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius:
          BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(
                milliseconds: 1200),
            builder: (ctx, val, _) =>
                LinearProgressIndicator(
                  value: val,
                  minHeight: 18,
                  backgroundColor:
                  Colors.grey.shade200,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(
                      _scoreColor),
                ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _total == 0
              ? "No tasks completed yet"
              : "$_total tasks completed total",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
        ),
      ]),
    );
  }

  Widget _buildHistory() {
    final recent =
    _history.reversed.take(10).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics:
      const NeverScrollableScrollPhysics(),
      itemCount: recent.length,
      itemBuilder: (ctx, i) {
        final item =
        recent[i] as Map<String, dynamic>;
        final ok = item['correct'] == true;

        return Container(
          margin:
          const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ok
                ? Colors.green.shade50
                : Colors.red.shade50,
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color: ok
                  ? Colors.green.shade200
                  : Colors.red.shade200,
            ),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok
                    ? Colors.green
                    : Colors.red,
              ),
              child: Icon(
                ok
                    ? Icons.check
                    : Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  item['question'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  ok
                      ? "✅ Correct! = "
                      "${item['answer']}"
                      : "❌ Answer: "
                      "${item['answer']}"
                      "  You said: "
                      "${item['spoken']}",
                  style: TextStyle(
                    fontSize: 12,
                    color: ok
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ],
            )),
          ]),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const Text("🎤",
            style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text(
          "No speech attempts yet!",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Complete some speech tasks\n"
              "to see your progress here.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
        ),
      ]),
    );
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text("Clear Progress?"),
        content: const Text(
            "This will delete all your speech "
                "progress. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await ProgressService
                  .clearSpeech();
              if (mounted) {
                Navigator.pop(context);
                _load();
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text("Clear",
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}