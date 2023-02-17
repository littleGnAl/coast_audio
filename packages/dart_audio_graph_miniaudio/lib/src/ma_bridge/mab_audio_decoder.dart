import 'dart:ffi';

import 'package:dart_audio_graph/dart_audio_graph.dart';
import 'package:dart_audio_graph_miniaudio/dart_audio_graph_miniaudio.dart';
import 'package:dart_audio_graph_miniaudio/generated/ma_bridge_bindings.dart';
import 'package:dart_audio_graph_miniaudio/src/ma_extension.dart';
import 'package:ffi/ffi.dart';

class MabAudioDecoderResult {
  const MabAudioDecoderResult.success(this.maResult, this.framesRead);
  const MabAudioDecoderResult.atEnd(this.maResult, this.framesRead);
  const MabAudioDecoderResult.failed(this.maResult) : framesRead = null;

  bool get isError => framesRead == null;

  bool get isEnd => maResult.name == MaResultName.atEnd;

  final MaResult maResult;
  final int? framesRead;
}

class MabAudioDecoderFormat {
  const MabAudioDecoderFormat(this.format, this.length);
  final AudioFormat format;
  final int length;
}

class MabAudioDecoder extends MabBase {
  static MabAudioDecoderFormat getFormat(String filePath) {
    final pFilePath = filePath.toNativeUtf8();
    final pFormat = malloc.allocate<mab_audio_decoder_format>(sizeOf<mab_audio_decoder_format>());
    try {
      mabLibrary.mab_audio_decoder_get_format(pFilePath.cast(), pFormat).throwMaResultIfNeeded();
      return MabAudioDecoderFormat(
        AudioFormat(sampleRate: pFormat.ref.sampleRate, channels: pFormat.ref.channels),
        pFormat.ref.length,
      );
    } finally {
      malloc.free(pFilePath);
      malloc.free(pFormat);
    }
  }

  MabAudioDecoder.file({
    required this.filePath,
    required this.format,
    MabDitherMode ditherMode = MabDitherMode.none,
    MabChannelMixMode channelMixMode = MabChannelMixMode.rectangular,
  }) {
    final config = library.mab_audio_decoder_config_init(format.sampleRate, format.channels);
    config.ditherMode = ditherMode.value;
    config.channelMixMode = channelMixMode.value;

    addPtrToDisposableBag(_pFilePath);
    library.mab_audio_decoder_init_file(_pDecoder, _pFilePath, config).throwMaResultIfNeeded();
  }

  final String filePath;
  final AudioFormat format;

  late final _pDecoder = allocate<mab_audio_decoder>(sizeOf<mab_audio_decoder>());
  late final _pFilePath = filePath.toNativeUtf8().cast<Char>();
  late final _pFramesRead = allocate<UnsignedLongLong>(sizeOf<UnsignedLongLong>());

  var _cachedCursor = 0;
  int? _cachedLength;
  var _cursorChanged = false;

  int get cursor => _cachedCursor;

  set cursor(int value) {
    _cachedCursor = value;
    _cursorChanged = true;
  }

  int get length {
    if (_cachedLength != null) {
      return _cachedLength!;
    }

    final pLength = allocate<UnsignedLongLong>(sizeOf<UnsignedLongLong>());
    library.mab_audio_decoder_get_length(_pDecoder, pLength).throwMaResultIfNeeded();
    _cachedLength = pLength.value;
    return pLength.value;
  }

  void flushCursor() {
    if (_cursorChanged) {
      library.mab_audio_decoder_set_cursor(_pDecoder, cursor).throwMaResultIfNeeded();
      _cursorChanged = false;
    }
  }

  MabAudioDecoderResult decode(FrameBuffer buffer) {
    flushCursor();
    final result = library.mab_audio_decoder_decode(_pDecoder, buffer.pBuffer.cast(), buffer.sizeInFrames, _pFramesRead).toMaResult();
    switch (result.name) {
      case MaResultName.success:
        _cachedCursor += _pFramesRead.value;
        return MabAudioDecoderResult.success(result, _pFramesRead.value);
      case MaResultName.atEnd:
        _cachedCursor += _pFramesRead.value;
        return MabAudioDecoderResult.atEnd(result, _pFramesRead.value);
      default:
        return MabAudioDecoderResult.failed(result);
    }
  }

  @override
  void uninit() {
    library.mab_audio_decoder_uninit(_pDecoder).throwMaResultIfNeeded();
  }
}