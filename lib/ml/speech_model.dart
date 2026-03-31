import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SpeechModel {
  Interpreter? _interpreter;
  List<String> _labelNames = [];
  bool _isLoaded = false;

  // ✅ FSDD dataset settings
  // These MUST match Kaggle Cell 5
  static const int    sampleRate = 8000;
  static const int    nMels      = 40;
  static const int    nFft       = 512;
  static const int    hopLength  = 160;
  static const int    imgSize    = 40;

  Future<void> loadModel() async {
    try {
      _interpreter =
      await Interpreter.fromAsset(
        'assets/models/'
            'speech_cnn_model.tflite',
      );
      final j = await rootBundle.loadString(
        'assets/data/speech_labels.json',
      );
      _labelNames =
      List<String>.from(jsonDecode(j));
      _isLoaded = true;

      final inShape = _interpreter!
          .getInputTensor(0).shape;
      final outShape = _interpreter!
          .getOutputTensor(0).shape;

      print("✅ Speech model loaded");
      print("   Labels: $_labelNames");
      print("   Input:  $inShape");
      print("   Output: $outShape");
    } catch (e) {
      print("❌ Load error: $e");
    }
  }

  bool get isReady =>
      _isLoaded && _interpreter != null;
  List<String> get labelNames =>
      _labelNames;

  int? labelToNumber(String label) {
    try {
      return int.parse(label);
    } catch (_) {
      return null;
    }
  }

  // ── Main predict ──────────────────────
  String predict(Uint8List wavBytes) {
    if (!isReady) return "-1";

    try {
      print("\n Processing audio...");
      print("   File size: "
          "${wavBytes.length} bytes");

      final samples  = _parseWav(wavBytes);
      final padded   = _padOrTrim(samples);
      final frames   = _stft(padded);
      final filters  = _melFilterbank();
      final mel      =
      _applyMel(frames, filters);
      final db       = _toDb(mel);
      final norm     = _normalize(db);
      final resized  = _resize(norm);

      final tensor = resized.reshape(
          [1, imgSize, imgSize, 1]);
      final output = List.filled(
        _labelNames.length, 0.0,
      ).reshape([1, _labelNames.length]);

      _interpreter!.run(tensor, output);

      final scores =
      List<double>.from(output[0]);

      print("\n📊 Scores:");
      for (int i = 0;
      i < _labelNames.length; i++) {
        final pct = scores[i] * 100;
        final bar =
            "█" * (pct / 5).toInt();
        print("   ${_labelNames[i]
            .padLeft(2)}: "
            "${bar.padRight(22)} "
            "${pct.toStringAsFixed(1)}%");
      }

      final maxIdx = scores.indexOf(
        scores.reduce(
                (a, b) => a > b ? a : b),
      );
      final label      = _labelNames[maxIdx];
      final confidence = scores[maxIdx];

      print("\n Predicted: $label "
          "(${(confidence * 100)
          .toStringAsFixed(1)}%)");
      return label;

    } catch (e) {
      print("❌ Predict error: $e");
      return "-1";
    }
  }

  // ── Parse WAV + Auto Resample ─────────
  Float32List _parseWav(Uint8List bytes) {
    try {
      int offset = 44;
      for (int i = 0;
      i < bytes.length - 4; i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          offset = i + 8;
          break;
        }
      }

      // Read sample rate from header
      int wavSR = sampleRate;
      if (bytes.length > 27) {
        wavSR = bytes[24] |
        (bytes[25] << 8) |
        (bytes[26] << 16) |
        (bytes[27] << 24);
      }

      // Read channels
      int channels = 1;
      if (bytes.length > 23) {
        channels = bytes[22] |
        (bytes[23] << 8);
      }

      print("   WAV SR:   $wavSR Hz");
      print("   Channels: $channels");

      final numSamples =
          (bytes.length - offset) ~/
              (2 * channels);
      final raw = Float32List(numSamples);

      for (int i = 0;
      i < numSamples; i++) {
        final idx =
            offset + i * 2 * channels;
        if (idx + 1 >= bytes.length) break;
        int s = (bytes[idx + 1] << 8) |
        bytes[idx];
        if (s > 32767) s -= 65536;
        raw[i] = s / 32768.0;
      }

      print("   Raw: ${raw.length} "
          "samples "
          "(${(raw.length / wavSR)
          .toStringAsFixed(3)}s)");

      // Auto resample if needed
      if (wavSR != sampleRate) {
        print("   🔄 Resampling: "
            "$wavSR→$sampleRate Hz");
        final resampled =
        _resample(raw, wavSR,
            sampleRate);
        print("   After: "
            "${resampled.length} samples");
        return resampled;
      }

      return raw;
    } catch (e) {
      print("⚠️ WAV error: $e");
      return Float32List(sampleRate);
    }
  }

  // ── Linear interpolation resample ────
  Float32List _resample(
      Float32List input,
      int fromRate,
      int toRate) {
    if (fromRate == toRate) return input;

    final ratio = fromRate / toRate;
    final len   =
    (input.length / ratio).ceil();
    final out   = Float32List(len);

    for (int i = 0; i < len; i++) {
      final pos  = i * ratio;
      final idx  = pos.floor();
      final frac = pos - idx;

      final s0 = idx < input.length
          ? input[idx] : 0.0;
      final s1 = idx + 1 < input.length
          ? input[idx + 1] : 0.0;

      out[i] = s0 + (s1 - s0) * frac;
    }
    return out;
  }

  // ── Pad or trim to 1 second ───────────
  Float32List _padOrTrim(Float32List s) {
    final target = sampleRate;
    final out    = Float32List(target);
    final copy   =
    s.length < target
        ? s.length : target;
    for (int i = 0; i < copy; i++) {
      out[i] = s[i];
    }
    return out;
  }

  // ── STFT ──────────────────────────────
  List<Float32List> _stft(Float32List s) {
    final nF =
        (s.length - nFft) ~/ hopLength + 1;
    final nB = nFft ~/ 2 + 1;
    final out = <Float32List>[];

    final win = Float32List(nFft);
    for (int i = 0; i < nFft; i++) {
      win[i] = 0.5 *
          (1.0 - cos(
              2.0 * pi * i / (nFft - 1)));
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
        final a   =
            2.0 * pi * k / nFft;
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

  // ── Mel filterbank ────────────────────
  List<Float32List> _melFilterbank() {
    final nB = nFft ~/ 2 + 1;

    double hzToMel(double h) =>
        2595.0 *
            log(1.0 + h / 700.0) / ln10;
    double melToHz(double m) =>
        700.0 *
            (pow(10.0, m / 2595.0) - 1.0);

    final mMin =
    hzToMel(0.0);
    final mMax =
    hzToMel(sampleRate / 2.0);
    final mStep =
        (mMax - mMin) / (nMels + 1);

    final centers =
    List<double>.generate(
      nMels + 2,
          (i) => melToHz(mMin + i * mStep),
    );
    final bins = centers.map(
          (f) => (f * (nFft + 1) /
          sampleRate)
          .floor(),
    ).toList();

    final filters =
    List<Float32List>.generate(
      nMels,
          (_) => Float32List(nB),
    );

    for (int m = 0; m < nMels; m++) {
      for (int k = 0; k < nB; k++) {
        if (k >= bins[m] &&
            k <= bins[m + 1]) {
          filters[m][k] =
              (k - bins[m]) /
                  (bins[m + 1] -
                      bins[m] +
                      1e-10);
        } else if (k > bins[m + 1] &&
            k <= bins[m + 2]) {
          filters[m][k] =
              (bins[m + 2] - k) /
                  (bins[m + 2] -
                      bins[m + 1] +
                      1e-10);
        }
      }
    }
    return filters;
  }

  // ── Apply mel filters ─────────────────
  List<Float32List> _applyMel(
      List<Float32List> frames,
      List<Float32List> filters) {
    return frames.map((frame) {
      final mel = Float32List(nMels);
      for (int m = 0; m < nMels; m++) {
        double sum = 0.0;
        for (int k = 0;
        k < frame.length; k++) {
          sum +=
              filters[m][k] * frame[k];
        }
        mel[m] = sum + 1e-10;
      }
      return mel;
    }).toList();
  }

  // ── Power to dB ───────────────────────
  List<Float32List> _toDb(
      List<Float32List> mel) {
    double maxVal = 1e-10;
    for (final f in mel) {
      for (final v in f) {
        if (v > maxVal) maxVal = v;
      }
    }
    return mel.map((f) {
      final d = Float32List(f.length);
      for (int i = 0;
      i < f.length; i++) {
        d[i] = 10.0 *
            log(f[i] / maxVal + 1e-10) /
            ln10;
      }
      return d;
    }).toList();
  }

  // ── Normalize [0, 1] ──────────────────
  List<Float32List> _normalize(
      List<Float32List> spec) {
    double minVal =  double.infinity;
    double maxVal = -double.infinity;
    for (final f in spec) {
      for (final v in f) {
        if (v < minVal) minVal = v;
        if (v > maxVal) maxVal = v;
      }
    }
    final range = maxVal - minVal + 1e-10;
    return spec.map((f) {
      final n = Float32List(f.length);
      for (int i = 0;
      i < f.length; i++) {
        n[i] = (f[i] - minVal) / range;
      }
      return n;
    }).toList();
  }

  // ── Resize to imgSize × imgSize ───────
  Float32List _resize(
      List<Float32List> spec) {
    final out =
    Float32List(imgSize * imgSize);
    final sr = spec.length;
    final sc = spec[0].length;

    for (int r = 0; r < imgSize; r++) {
      for (int c = 0; c < imgSize; c++) {
        final fr =
            r * (sr - 1) / (imgSize - 1);
        final fc =
            c * (sc - 1) / (imgSize - 1);
        final r0 =
        fr.floor().clamp(0, sr - 1);
        final r1 =
        (r0 + 1).clamp(0, sr - 1);
        final c0 =
        fc.floor().clamp(0, sc - 1);
        final c1 =
        (c0 + 1).clamp(0, sc - 1);
        final dr = fr - r0;
        final dc = fc - c0;

        out[r * imgSize + c] =
            spec[r0][c0] * (1-dr) * (1-dc)+
                spec[r1][c0] * dr * (1-dc) +
                spec[r0][c1] * (1-dr) * dc +
                spec[r1][c1] * dr * dc;
      }
    }
    return out;
  }

  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
  }
}