import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SpeechModel {
  Interpreter? _interpreter;
  List<String> _labelNames = [];
  bool _isLoaded = false;

  // ✅ MUST match Kaggle Cell 6 settings exactly
  static const int    sampleRate = 8000;
  static const int    nMels      = 32;
  static const int    nFft       = 512;
  static const int    hopLength  = 256;
  static const int    imgSize    = 32;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/speech_cnn_model.tflite',
      );
      final j = await rootBundle.loadString(
        'assets/data/speech_labels.json',
      );
      _labelNames = List<String>.from(jsonDecode(j));
      _isLoaded   = true;
      print("✅ Speech model: $_labelNames");
    } catch (e) {
      print("❌ Load: $e");
    }
  }

  bool get isReady =>
      _isLoaded && _interpreter != null;

  int? labelToNumber(String label) {
    try { return int.parse(label); }
    catch (_) { return null; }
  }

  String predict(Uint8List wavBytes) {
    if (!isReady) return "-1";
    try {
      final spec   = _pipeline(wavBytes);
      final tensor = spec.reshape(
          [1, imgSize, imgSize, 1]);
      final out = List.filled(
        _labelNames.length, 0.0,
      ).reshape([1, _labelNames.length]);

      _interpreter!.run(tensor, out);

      final scores = List<double>.from(out[0]);
      print("📊 Scores:");
      for (int i = 0;
      i < _labelNames.length; i++) {
        print("   ${_labelNames[i]}: "
            "${(scores[i]*100).toStringAsFixed(1)}%");
      }

      final idx = scores.indexOf(
          scores.reduce((a, b) => a > b ? a : b));
      print("✅ → ${_labelNames[idx]} "
          "(${(scores[idx]*100).toStringAsFixed(1)}%)");
      return _labelNames[idx];
    } catch (e) {
      print("❌ Predict: $e");
      return "-1";
    }
  }

  // ── Full pipeline ─────────────────────────────
  Float32List _pipeline(Uint8List wav) {
    final s  = _parseWav(wav);
    final p  = _padTrim(s);
    final fr = _stft(p);
    final mf = _melFilters();
    final m  = _applyMel(fr, mf);
    final db = _toDb(m);
    final n  = _norm(db);
    return _resize(n);
  }

  Float32List _parseWav(Uint8List b) {
    try {
      int off = 44;
      for (int i = 0; i < b.length - 4; i++) {
        if (b[i]==0x64 && b[i+1]==0x61 &&
            b[i+2]==0x74 && b[i+3]==0x61) {
          off = i + 8; break;
        }
      }
      final n   = (b.length - off) ~/ 2;
      final out = Float32List(n);
      for (int i = 0; i < n; i++) {
        final idx = off + i * 2;
        if (idx + 1 >= b.length) break;
        int s = (b[idx+1] << 8) | b[idx];
        if (s > 32767) s -= 65536;
        out[i] = s / 32768.0;
      }
      print("🎤 WAV: $n samples "
          "(${(n/sampleRate).toStringAsFixed(2)}s)");
      return out;
    } catch (_) {
      return Float32List(sampleRate);
    }
  }

  Float32List _padTrim(Float32List s) {
    final t   = sampleRate;
    final out = Float32List(t);
    final c   = s.length < t ? s.length : t;
    for (int i = 0; i < c; i++) out[i] = s[i];
    return out;
  }

  List<Float32List> _stft(Float32List s) {
    final nF  = (s.length - nFft) ~/ hopLength + 1;
    final nB  = nFft ~/ 2 + 1;
    final out = <Float32List>[];

    final win = Float32List(nFft);
    for (int i = 0; i < nFft; i++) {
      win[i] = 0.5 *
          (1.0 - cos(2.0 * pi * i / (nFft - 1)));
    }

    for (int f = 0; f < nF; f++) {
      final st  = f * hopLength;
      final wnd = Float32List(nFft);
      for (int i = 0; i < nFft; i++) {
        final idx = st + i;
        wnd[i]    = idx < s.length
            ? s[idx] * win[i] : 0.0;
      }
      final pwr = Float32List(nB);
      for (int k = 0; k < nB; k++) {
        double re = 0.0, im = 0.0;
        final a   = 2.0 * pi * k / nFft;
        for (int n = 0; n < nFft; n++) {
          re += wnd[n] * cos(a * n);
          im -= wnd[n] * sin(a * n);
        }
        pwr[k] = re * re + im * im;
      }
      out.add(pwr);
    }
    return out;
  }

  List<Float32List> _melFilters() {
    final nB = nFft ~/ 2 + 1;
    double h2m(double h) =>
        2595.0 * log(1.0 + h / 700.0) / ln10;
    double m2h(double m) =>
        700.0 * (pow(10.0, m / 2595.0) - 1.0);

    final mn  = h2m(0.0);
    final mx  = h2m(sampleRate / 2.0);
    final stp = (mx - mn) / (nMels + 1);

    final ctr  = List<double>.generate(
        nMels + 2, (i) => m2h(mn + i * stp));
    final bins = ctr.map(
            (f) => (f*(nFft+1)/sampleRate).floor()
    ).toList();

    final f = List<Float32List>.generate(
        nMels, (_) => Float32List(nB));

    for (int m = 0; m < nMels; m++) {
      for (int k = 0; k < nB; k++) {
        if (k >= bins[m] && k <= bins[m+1]) {
          f[m][k] = (k - bins[m]) /
              (bins[m+1] - bins[m] + 1e-10);
        } else if (k > bins[m+1] &&
            k <= bins[m+2]) {
          f[m][k] = (bins[m+2] - k) /
              (bins[m+2] - bins[m+1] + 1e-10);
        }
      }
    }
    return f;
  }

  List<Float32List> _applyMel(
      List<Float32List> frames,
      List<Float32List> filters,
      ) {
    return frames.map((fr) {
      final m = Float32List(nMels);
      for (int i = 0; i < nMels; i++) {
        double s = 0.0;
        for (int k = 0; k < fr.length; k++) {
          s += filters[i][k] * fr[k];
        }
        m[i] = s + 1e-10;
      }
      return m;
    }).toList();
  }

  List<Float32List> _toDb(
      List<Float32List> mel) {
    double mx = 1e-10;
    for (final f in mel) {
      for (final v in f) {
        if (v > mx) mx = v;
      }
    }
    return mel.map((f) {
      final d = Float32List(f.length);
      for (int i = 0; i < f.length; i++) {
        d[i] = 10.0 *
            log(f[i] / mx + 1e-10) / ln10;
      }
      return d;
    }).toList();
  }

  List<Float32List> _norm(
      List<Float32List> s) {
    double mn =  double.infinity;
    double mx = -double.infinity;
    for (final f in s) {
      for (final v in f) {
        if (v < mn) mn = v;
        if (v > mx) mx = v;
      }
    }
    final r = mx - mn + 1e-10;
    return s.map((f) {
      final n = Float32List(f.length);
      for (int i = 0; i < f.length; i++) {
        n[i] = (f[i] - mn) / r;
      }
      return n;
    }).toList();
  }

  Float32List _resize(List<Float32List> s) {
    final out = Float32List(imgSize * imgSize);
    final sr  = s.length;
    final sc  = s[0].length;
    for (int r = 0; r < imgSize; r++) {
      for (int c = 0; c < imgSize; c++) {
        final fr = r*(sr-1)/(imgSize-1);
        final fc = c*(sc-1)/(imgSize-1);
        final r0 = fr.floor().clamp(0,sr-1);
        final r1 = (r0+1).clamp(0,sr-1);
        final c0 = fc.floor().clamp(0,sc-1);
        final c1 = (c0+1).clamp(0,sc-1);
        final dr = fr-r0, dc = fc-c0;
        out[r*imgSize+c] =
            s[r0][c0]*(1-dr)*(1-dc)+
                s[r1][c0]*dr*(1-dc)+
                s[r0][c1]*(1-dr)*dc+
                s[r1][c1]*dr*dc;
      }
    }
    return out;
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}