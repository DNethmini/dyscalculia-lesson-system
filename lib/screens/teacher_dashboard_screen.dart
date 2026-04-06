import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class TeacherDashboardScreen
    extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends State<TeacherDashboardScreen> {

  //PIN entry state
  bool   _unlocked    = false;
  String _enteredPin  = '';
  bool   _pinError    = false;
  bool   _loading     = false;

  // Dashboard data
  Map<String, dynamic> _drawingProgress = {};
  Map<String, dynamic> _speechProgress  = {};
  Map<int, Map<String, int>> _digitData = {};
  List<Map<String, dynamic>> _patterns  = [];
  bool _dataLoading = true;

  // Change PIN state
  bool   _changingPin  = false;
  String _newPin       = '';
  String _confirmPin   = '';

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Row(children: [
          const SizedBox(width: 8),
          const Text("Teacher Dashboard"),
        ]),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: _unlocked
            ? [
          IconButton(
            icon: const Icon(Icons.lock),
            onPressed: () => setState(() {
              _unlocked   = false;
              _enteredPin = '';
              _pinError   = false;
            }),
            tooltip: "Lock",
          ),
        ]
            : null,
      ),
      body: _unlocked
          ? _buildDashboard()
          : _buildPinScreen(),
    );
  }

  Widget _buildPinScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [

            // Lock icon
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple,
                boxShadow: [BoxShadow(
                  color: const Color(0xFF1A237E)
                      .withOpacity(.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )],
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 48,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              "Teacher Access",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Enter your 4-digit PIN",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 32),

            // PIN dots display
            Row(
              mainAxisAlignment:
              MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled =
                    i < _enteredPin.length;
                return Container(
                  width:  20, height: 20,
                  margin: const EdgeInsets
                      .symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _pinError
                        ? Colors.red
                        : filled
                        ? const Color(
                        0xFF1A237E)
                        : Colors.grey
                        .shade300,
                  ),
                );
              }),
            ),

            if (_pinError) ...[
              const SizedBox(height: 8),
              const Text(
                "Incorrect PIN. Try again.",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Number pad
            _buildNumPad(),

            const SizedBox(height: 24),

            // Default PIN hint
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius:
                BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.blue.shade200),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 16),
                const SizedBox(width: 8),
                Text(
                  "Default PIN: 1234",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 13,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    final buttons = [
      '1','2','3',
      '4','5','6',
      '7','8','9',
      '⌫','0','✓',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: buttons.length,
      itemBuilder: (ctx, i) {
        final b = buttons[i];
        return _numPadButton(b);
      },
    );
  }

  Widget _numPadButton(String label) {
    final isAction = label == '⌫' || label == '✓';
    final isConfirm = label == '✓';

    return GestureDetector(
      onTap: () => _onNumPadTap(label),
      child: Container(
        decoration: BoxDecoration(
          color: isConfirm
              ? const Color(0xFF1A237E)
              : isAction
              ? Colors.grey.shade200
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: label == '⌫' ? 20 : 22,
              fontWeight: FontWeight.bold,
              color: isConfirm
                  ? Colors.white
                  : const Color(0xFF1A237E),
            ),
          ),
        ),
      ),
    );
  }

  void _onNumPadTap(String label) {
    setState(() => _pinError = false);

    if (label == '⌫') {
      if (_enteredPin.isNotEmpty) {
        setState(() => _enteredPin =
            _enteredPin.substring(
                0, _enteredPin.length - 1));
      }
    } else if (label == '✓') {
      _verifyPin();
    } else {
      if (_enteredPin.length < 4) {
        setState(() => _enteredPin += label);
        if (_enteredPin.length == 4) {
          Future.delayed(
              const Duration(milliseconds: 200),
              _verifyPin);
        }
      }
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _loading = true);
    final ok = await ProgressService
        .verifyPin(_enteredPin);
    if (ok) {
      setState(() {
        _unlocked = true;
        _loading  = false;
      });
      _loadData();
    } else {
      setState(() {
        _pinError   = true;
        _enteredPin = '';
        _loading    = false;
      });
    }
  }

  // DASHBOARD

  Future<void> _loadData() async {
    setState(() => _dataLoading = true);
    final draw    = await ProgressService
        .getDrawingProgress();
    final speech  = await ProgressService
        .getSpeechProgress();
    final digits  = await ProgressService
        .getDigitAnalytics();
    final patterns = await ProgressService
        .getMistakePatterns();

    setState(() {
      _drawingProgress = draw;
      _speechProgress  = speech;
      _digitData       = digits;
      _patterns        = patterns;
      _dataLoading     = false;
    });
  }

  Widget _buildDashboard() {
    if (_dataLoading) {
      return const Center(
          child: CircularProgressIndicator(
              color: Color(0xFF1A237E)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        //Overall summary
        _buildOverallSummary(),
        const SizedBox(height: 16),

        _buildDigitHeatmap(),
        const SizedBox(height: 16),

        //Mistake patterns
        _buildMistakePatterns(),
        const SizedBox(height: 16),

        //Settings
        _buildSettings(),
        const SizedBox(height: 16),
      ]),
    );
  }

  //Overall Summary
  Widget _buildOverallSummary() {
    final drawTotal   =
        _drawingProgress['total'] ?? 0;
    final drawCorrect =
        _drawingProgress['correct'] ?? 0;
    final speechTotal =
        _speechProgress['total'] ?? 0;
    final speechCorrect =
        _speechProgress['correct'] ?? 0;

    final totalAttempts = drawTotal + speechTotal;
    final totalCorrect  =
        drawCorrect + speechCorrect;
    final overallPct = totalAttempts > 0
        ? (totalCorrect / totalAttempts * 100)
        .toInt()
        : 0;

    return Column(children: [

      // Overall score card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
               Colors.deepPurple,
              Colors.deepPurple,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
          BorderRadius.circular(20),
          boxShadow: [BoxShadow(
            color: const Color(0xFF1A237E)
                .withOpacity(.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )],
        ),
        child: Column(children: [
          const Text(
            "📊 Student Overview",
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            "$overallPct%",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "$totalCorrect / $totalAttempts correct",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _miniStat(
              "✏️ Drawing",
              "$drawCorrect/$drawTotal",
              drawTotal > 0
                  ? drawCorrect / drawTotal
                  : 0,
            )),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(
              "🎤 Speech",
              "$speechCorrect/$speechTotal",
              speechTotal > 0
                  ? speechCorrect / speechTotal
                  : 0,
            )),
          ]),
        ]),
      ),
    ]);
  }

  Widget _miniStat(String label,
      String value, double pct) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(
            color: Colors.white70,
            fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor:
            Colors.white.withOpacity(.2),
            valueColor:
            AlwaysStoppedAnimation<Color>(
              pct >= 0.8
                  ? Colors.greenAccent
                  : pct >= 0.5
                  ? Colors.yellow
                  : Colors.redAccent,
            ),
          ),
        ),
      ]),
    );
  }

  //Digit Heatmap
  Widget _buildDigitHeatmap() {
    // Find most struggled digit
    int worstDigit  = -1;
    int worstWrong  = -1;

    _digitData.forEach((digit, data) {
      final wrong = data['wrong'] ?? 0;
      if (wrong > worstWrong) {
        worstWrong = wrong;
        worstDigit = digit;
      }
    });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(.06),
          blurRadius: 8,
        )],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [

          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📈 Per-Number Performance",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              if (worstDigit >= 0)
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius:
                    BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.red.shade200),
                  ),
                  child: Text(
                    "⚠️ Struggles with $worstDigit",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Grid of digits 0-9
          GridView.builder(
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.85,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 10,
            itemBuilder: (ctx, i) =>
                _digitCard(i),
          ),

          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              _legendItem(
                  Colors.green, "Good (≥80%)"),
              const SizedBox(width: 16),
              _legendItem(
                  Colors.orange, "OK (50-79%)"),
              const SizedBox(width: 16),
              _legendItem(
                  Colors.red, "Needs help (<50%)"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _digitCard(int digit) {
    final data    = _digitData[digit] ??
        {'correct': 0, 'wrong': 0};
    final correct = data['correct'] ?? 0;
    final wrong   = data['wrong']   ?? 0;
    final total   = correct + wrong;
    final pct     = total > 0
        ? correct / total : -1.0;

    Color bgColor;
    Color textColor;
    String emoji;

    if (pct < 0) {
      bgColor   = Colors.grey.shade100;
      textColor = Colors.grey.shade400;
      emoji     = "—";
    } else if (pct >= 0.8) {
      bgColor   = Colors.green.shade50;
      textColor = Colors.green.shade700;
      emoji     = "⭐";
    } else if (pct >= 0.5) {
      bgColor   = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      emoji     = "📝";
    } else {
      bgColor   = Colors.red.shade50;
      textColor = Colors.red.shade700;
      emoji     = "⚠️";
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Text(
            "$digit",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            emoji,
            style: const TextStyle(fontSize: 14),
          ),
          if (total > 0)
            Text(
              "$correct/$total",
              style: TextStyle(
                fontSize: 10,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              "no data",
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade400,
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(
        width: 12, height: 12,
        decoration: BoxDecoration(
          color: color.withOpacity(.3),
          shape: BoxShape.circle,
          border: Border.all(
              color: color, width: 1.5),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
        fontSize: 10,
        color: Colors.grey.shade600,
      )),
    ]);
  }

  // Mistake Patterns
  Widget _buildMistakePatterns() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(.06),
          blurRadius: 8,
        )],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [

          const Text(
            "Mistake Patterns",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "Questions answered wrong 2+ times",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(height: 12),

          if (_patterns.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets
                    .all(24),
                child: Column(children: [
                  const Text("✅",
                      style: TextStyle(
                          fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(
                    "No repeated mistakes!",
                    style: TextStyle(
                      color:
                      Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ]),
              ),
            )
          else
            ...(_patterns.take(10).map(
                  (p) => Container(
                margin: const EdgeInsets.only(
                    bottom: 8),
                padding: const EdgeInsets.all(
                    12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius:
                  BorderRadius.circular(10),
                  border: Border.all(
                      color:
                      Colors.red.shade200),
                ),
                child: Row(children: [
                  Container(
                    padding:
                    const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius:
                      BorderRadius.circular(
                          8),
                    ),
                    child: Text(
                      "×${p['count']}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                        FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['pattern'] ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                      Text(
                        p['type'] == 'drawing'
                            ? "✏️ Drawing"
                            : "🎤 Speech",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey
                              .shade500,
                        ),
                      ),
                    ],
                  )),
                ]),
              ),
            )),
        ],
      ),
    );
  }

  // Settings
  Widget _buildSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(.06),
          blurRadius: 8,
        )],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            "⚙️ Settings",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),

          const SizedBox(height: 12),

          // Change PIN
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: Icon(Icons.lock_outline,
                  color: Colors.blue.shade700),
            ),
            title: const Text("Change PIN"),
            subtitle: const Text(
                "Update teacher access PIN"),
            trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14),
            onTap: () =>
                _showChangePinDialog(),
          ),

          const Divider(),

          // Refresh data
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: Icon(Icons.refresh,
                  color: Colors.green.shade700),
            ),
            title: const Text("Refresh Data"),
            subtitle:
            const Text("Reload analytics"),
            trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14),
            onTap: _loadData,
          ),

          const Divider(),

          // Clear all data
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius:
                BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline,
                  color: Colors.red.shade700),
            ),
            title: const Text(
              "Clear All Progress",
              style: TextStyle(color: Colors.red),
            ),
            subtitle: const Text(
                "Delete all student data"),
            trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14),
            onTap: () =>
                _confirmClearAll(),
          ),
        ],
      ),
    );
  }

  //Change PIN
  void _showChangePinDialog() {
    String newPin     = '';
    String confirmPin = '';
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(20)),
          title: const Text("Change PIN"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration:
                const InputDecoration(
                  labelText: "New PIN (4 digits)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                keyboardType:
                TextInputType.number,
                maxLength: 4,
                obscureText: true,
                onChanged: (v) => newPin = v,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration:
                const InputDecoration(
                  labelText: "Confirm PIN",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                      Icons.lock_outline),
                ),
                keyboardType:
                TextInputType.number,
                maxLength: 4,
                obscureText: true,
                onChanged: (v) => confirmPin = v,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newPin.length != 4) {
                  setS(() => error =
                  "PIN must be 4 digits");
                  return;
                }
                if (newPin != confirmPin) {
                  setS(() => error =
                  "PINs don't match");
                  return;
                }
                await ProgressService
                    .setPin(newPin);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(
                    content: Text(
                        "PIN updated!"),
                    backgroundColor:
                    Colors.green,
                  ));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1A237E)),
              child: const Text("Save",
                  style: TextStyle(
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Confirm clear all
  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16)),
        title: const Text("Clear All Data"),
        content: const Text(
            "This will permanently delete ALL "
                "student progress data. "
                "This cannot be undone!"),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await ProgressService.clearAll();
              if (mounted) {
                Navigator.pop(context);
                _loadData();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(
                  content: Text(
                      "All data cleared"),
                  backgroundColor: Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text("Delete All",
                style: TextStyle(
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}