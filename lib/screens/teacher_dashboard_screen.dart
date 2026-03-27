import 'package:flutter/material.dart';
import '../services/progress_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends State<TeacherDashboardScreen> {

  bool _unlocked = false;
  String _enteredPin = '';
  bool _pinError = false;

  Map<String, dynamic> _drawingProgress = {};
  Map<String, dynamic> _speechProgress = {};
  Map<int, Map<String, int>> _digitData = {};
  List<Map<String, dynamic>> _patterns = [];

  bool _dataLoading = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        backgroundColor: Colors.deepPurple,
      ),
      body: _unlocked ? _buildDashboard(screenWidth) : _buildPinScreen(screenWidth),
    );
  }

  // ================= PIN SCREEN =================

  Widget _buildPinScreen(double w) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(w * 0.08),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: w * 0.25,
              height: w * 0.25,
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 40),
            ),
            SizedBox(height: w * 0.05),

            Text(
              "Enter PIN",
              style: TextStyle(fontSize: w * 0.06, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: w * 0.08),

            Wrap(
              spacing: 10,
              children: List.generate(4, (i) {
                return CircleAvatar(
                  radius: w * 0.025,
                  backgroundColor: i < _enteredPin.length
                      ? Colors.deepPurple
                      : Colors.grey.shade300,
                );
              }),
            ),

            if (_pinError)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text("Wrong PIN", style: TextStyle(color: Colors.red)),
              ),

            SizedBox(height: w * 0.08),

            _buildNumPad(w),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad(double w) {
    final buttons = ['1','2','3','4','5','6','7','8','9','⌫','0','✓'];

    return GridView.builder(
      shrinkWrap: true,
      itemCount: buttons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
      ),
      itemBuilder: (_, i) {
        final b = buttons[i];
        return GestureDetector(
          onTap: () => _onNumTap(b),
          child: Container(
            margin: EdgeInsets.all(w * 0.02),
            decoration: BoxDecoration(
              color: b == '✓'
                  ? Colors.deepPurple
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                b,
                style: TextStyle(
                  fontSize: w * 0.06,
                  color: b == '✓' ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onNumTap(String val) {
    setState(() => _pinError = false);

    if (val == '⌫') {
      if (_enteredPin.isNotEmpty) {
        _enteredPin =
            _enteredPin.substring(0, _enteredPin.length - 1);
      }
    } else if (val == '✓') {
      if (_enteredPin == "1234") {
        setState(() => _unlocked = true);
        _loadData();
      } else {
        setState(() {
          _pinError = true;
          _enteredPin = '';
        });
      }
    } else {
      if (_enteredPin.length < 4) {
        _enteredPin += val;
      }
    }
    setState(() {});
  }

  // ================= DASHBOARD =================

  Widget _buildDashboard(double w) {
    if (_dataLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(w * 0.04),
      child: Column(
        children: [
          _overallCard(w),
          SizedBox(height: w * 0.04),
          _digitGrid(w),
          SizedBox(height: w * 0.04),
          _patternsBox(w),
        ],
      ),
    );
  }

  // ================= OVERALL =================

  Widget _overallCard(double w) {
    int total = (_drawingProgress['total'] ?? 0) +
        (_speechProgress['total'] ?? 0);
    int correct = (_drawingProgress['correct'] ?? 0) +
        (_speechProgress['correct'] ?? 0);

    int percent = total > 0 ? (correct / total * 100).toInt() : 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(w * 0.05),
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            "$percent%",
            style: TextStyle(
              fontSize: w * 0.12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "$correct / $total correct",
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // ================= DIGIT GRID =================

  Widget _digitGrid(double w) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 10,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: w < 600 ? 5 : 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (_, i) {
        final data = _digitData[i] ?? {'correct': 0, 'wrong': 0};
        final total = data['correct']! + data['wrong']!;

        return Container(
          margin: EdgeInsets.all(w * 0.01),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              "$i",
              style: TextStyle(fontSize: w * 0.06),
            ),
          ),
        );
      },
    );
  }

  // ================= PATTERNS =================

  Widget _patternsBox(double w) {
    return Container(
      padding: EdgeInsets.all(w * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Text("Mistakes"),
          ..._patterns.map((p) => Text(p['pattern'] ?? '')),
        ],
      ),
    );
  }

  // ================= LOAD =================

  Future<void> _loadData() async {
    final draw = await ProgressService.getDrawingProgress();
    final speech = await ProgressService.getSpeechProgress();
    final digits = await ProgressService.getDigitAnalytics();
    final patterns = await ProgressService.getMistakePatterns();

    setState(() {
      _drawingProgress = draw;
      _speechProgress = speech;
      _digitData = digits;
      _patterns = patterns;
      _dataLoading = false;
    });
  }
}