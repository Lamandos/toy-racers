import 'race_audio_mix.dart';

typedef RaceAudioMixWriter = Future<void> Function(RaceAudioMix mix);

/// Serializes mix writes while keeping only the latest frame target pending.
final class RaceAudioMixQueue {
  RaceAudioMixQueue(this._write);

  final RaceAudioMixWriter _write;
  RaceAudioMix? _pending;
  Future<void>? _draining;

  /// Applies [mix] after the current write and replaces older pending targets.
  Future<void> enqueue(RaceAudioMix mix) {
    _pending = mix;
    final draining = _draining;
    if (draining != null) {
      return draining;
    }
    final drain = _drain();
    final tracked = drain.whenComplete(() => _draining = null);
    _draining = tracked;
    return tracked;
  }

  /// Completes after every mix write already accepted by the queue.
  Future<void> get idle => _draining ?? Future<void>.value();

  Future<void> _drain() async {
    while (_pending != null) {
      final mix = _pending!;
      _pending = null;
      await _write(mix);
    }
  }
}
