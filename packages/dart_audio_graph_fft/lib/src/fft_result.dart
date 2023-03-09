import 'dart:typed_data';

import 'package:dart_audio_graph/dart_audio_graph.dart';

class FftResult {
  FftResult({
    required this.frames,
    required this.format,
    required this.complexArray,
  });

  final int frames;
  final AudioFormat format;
  final Float64x2List complexArray;

  double getFrequency(int index) {
    return index * format.sampleRate / frames;
  }

  int getIndex(double frequency) {
    return (frequency * frames) ~/ format.sampleRate;
  }
}
