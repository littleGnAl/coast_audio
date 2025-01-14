import 'dart:io';
import 'dart:typed_data';

import 'package:coast_audio/coast_audio.dart';

class AudioFileDataSource extends SyncDisposable implements AudioInputDataSource, AudioOutputDataSource {
  AudioFileDataSource({
    required File file,
    required FileMode mode,
  }) : file = file.openSync(mode: mode);
  AudioFileDataSource.fromRandomAccessFile({required this.file});
  final RandomAccessFile file;

  @override
  int get length => file.lengthSync();

  @override
  int get position => file.positionSync();

  @override
  bool get canSeek => true;

  var _isDisposed = false;
  @override
  bool get isDisposed => _isDisposed;

  @override
  void seek(int count, [SeekOrigin origin = SeekOrigin.current]) {
    final newPosition = origin.getPosition(position: position, length: length, count: count);
    file.setPositionSync(newPosition);
  }

  @override
  int readBytes(Uint8List buffer, int offset, int count) {
    return file.readIntoSync(buffer, offset, count);
  }

  @override
  int writeBytes(Uint8List buffer, int offset, int count) {
    file.writeFromSync(buffer, offset, count);
    return count;
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    file.closeSync();
  }
}
