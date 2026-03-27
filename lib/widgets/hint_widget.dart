import 'dart:math';

import 'package:flutter/material.dart';

class HintWidget extends StatefulWidget {
  final int number;
  final VoidCallback? onClose;

  const HintWidget({
    super.key,
    required this.number,
    this.onClose,
  });

  @override
  State<HintWidget> createState() =>
      _HintWidgetState();
}

class _HintWidgetState
    extends State<HintWidget>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;
  late Animation<double>   _fadeIn;
  late Animation<double>   _bounceIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 600),
    )..forward();

    _fadeIn   = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5),
    ));
    _bounceIn = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFF9C4),
              Color(0xFFFFECB3),
            ],
          ),
          borderRadius:
          BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange
                  .withOpacity(.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Header
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text("💡",
                      style: TextStyle(
                          fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    "Hint for ${widget.number}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ]),
                if (widget.onClose != null)
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                        Icons.close,
                        color: Colors.orange,
                        size: 20),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Dots visual
            ScaleTransition(
              scale: _bounceIn,
              child: _buildDotsVisual(
                  widget.number),
            ),

            const SizedBox(height: 10),

            // Finger count
            _buildFingerVisual(widget.number),

            const SizedBox(height: 8),

            // Number word
            Text(
              _numberWord(widget.number),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dots visual ───────────────────────────────
  Widget _buildDotsVisual(int n) {
    if (n == 0) {
      return Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.orange.shade400,
              width: 3,
            ),
          ),
          child: const Center(
            child: Text("∅",
                style: TextStyle(
                    fontSize: 28,
                    color: Colors.orange)),
          ),
        ),
        const SizedBox(height: 4),
        const Text("Nothing / Empty",
            style: TextStyle(
                fontSize: 12,
                color: Colors.orange)),
      ]);
    }

    return Column(children: [
      // Dots in rows of 5
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: List.generate(n, (i) =>
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(
                  milliseconds: 300 + i * 80),
              curve: Curves.elasticOut,
              builder: (ctx, val, _) =>
                  Transform.scale(
                    scale: val,
                    child: Container(
                      width:  36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _dotColor(i),
                        boxShadow: [
                          BoxShadow(
                            color: _dotColor(i)
                                .withOpacity(.4),
                            blurRadius: 4,
                            offset:
                            const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "${i + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
            ),
        ),
      ),
    ]);
  }

  Color _dotColor(int index) {
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];
    return colors[index % colors.length];
  }

  // ── Finger visual ─────────────────────────────
  Widget _buildFingerVisual(int n) {
    if (n > 10) return const SizedBox.shrink();

    return Column(children: [
      const Text("🖐 Count on fingers:",
          style: TextStyle(
              fontSize: 12,
              color: Colors.deepOrange)),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          // Left hand (5 fingers)
          _buildHand(
              min(n, 5), 5, Colors.orange),
          if (n > 5) ...[
            const SizedBox(width: 12),
            // Right hand
            _buildHand(
                n - 5, 5, Colors.deepOrange),
          ],
        ],
      ),
    ]);
  }

  Widget _buildHand(
      int raised, int total, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isRaised = i < raised;
        return Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 2),
          child: Text(
            isRaised ? "☝️" : "✊",
            style: TextStyle(
              fontSize: isRaised ? 22 : 18,
            ),
          ),
        );
      }),
    );
  }

  String _numberWord(int n) {
    const words = [
      "Zero", "One",   "Two",   "Three",
      "Four", "Five",  "Six",   "Seven",
      "Eight","Nine",
    ];
    if (n >= 0 && n < words.length) {
      return words[n];
    }
    return n.toString();
  }
}