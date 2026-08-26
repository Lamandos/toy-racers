import 'dart:convert';

import '../math/float32.dart';
import 'compatibility_exception.dart';
import 'compatibility_models.dart';

/// Canonically encodes schema-v2 snapshots and schema-v3 traces.
///
/// The encoder validates the shared output contract before writing so a Dart
/// runner cannot create a trace that the Kotlin comparator would reject.
final class CompatibilityTraceJson {
  CompatibilityTraceJson._();

  static String encode(CompatibilityTrace trace) {
    _validateTrace(trace);
    final output = StringBuffer('{');
    _field(output, 'schemaVersion', CompatibilityTrace.schemaVersion);
    output.write(',');
    _field(output, 'scenarioId', trace.scenarioId);
    output.write(',"seed":${trace.seed}');
    output.write(',"samples":[');
    for (var index = 0; index < trace.samples.length; index++) {
      if (index > 0) {
        output.write(',');
      }
      _sample(output, trace.samples[index]);
    }
    output.write(']}');
    return output.toString();
  }

  static String encodeSnapshot(CompatibilitySnapshot snapshot) {
    _validateSnapshot(snapshot, r'$');
    final output = StringBuffer();
    _snapshot(output, snapshot);
    return output.toString();
  }

  static void _sample(StringBuffer output, CompatibilityTraceSample sample) {
    output.write('{');
    _field(output, 'label', sample.label);
    output.write(',');
    _field(output, 'tick', sample.tick);
    output.write(',"snapshot":');
    _snapshot(output, sample.snapshot);
    output.write('}');
  }

  static void _snapshot(StringBuffer output, CompatibilitySnapshot snapshot) {
    output.write('{');
    _field(output, 'schemaVersion', CompatibilitySnapshot.schemaVersion);
    output.write(',');
    _field(output, 'simulationTick', snapshot.simulationTick);
    output.write(',');
    _field(output, 'raceState', snapshot.raceState);
    output.write(',"countdown":');
    _countdown(output, snapshot.countdown);
    output.write(',');
    _floatField(
      output,
      'elapsedSimulationTime',
      snapshot.elapsedSimulationTime,
    );
    output.write(',');
    _field(output, 'currentLap', snapshot.currentLap);
    output.write(',"currentProgress":');
    _progress(output, snapshot.currentProgress);
    output.write(',"participants":[');
    for (var index = 0; index < snapshot.participants.length; index++) {
      if (index > 0) {
        output.write(',');
      }
      _participant(output, snapshot.participants[index]);
    }
    output.write('],"ranking":');
    _stringArray(output, snapshot.ranking);
    output.write(',"finishedParticipants":');
    _stringArray(output, snapshot.finishedParticipants);
    output.write(',"finishResults":[');
    for (var index = 0; index < snapshot.finishResults.length; index++) {
      if (index > 0) {
        output.write(',');
      }
      _finishResult(output, snapshot.finishResults[index]);
    }
    output.write(']}');
  }

  static void _countdown(
    StringBuffer output,
    CompatibilityCountdown countdown,
  ) {
    output.write('{');
    _field(output, 'state', countdown.state);
    output.write(',');
    _floatField(output, 'remainingSeconds', countdown.remainingSeconds);
    output.write('}');
  }

  static void _progress(StringBuffer output, CompatibilityProgress progress) {
    output.write('{');
    _field(output, 'checkpoint', progress.checkpoint);
    output.write(',');
    _field(output, 'completedLaps', progress.completedLaps);
    output.write('}');
  }

  static void _participant(
    StringBuffer output,
    CompatibilityParticipantSnapshot participant,
  ) {
    output.write('{');
    _field(output, 'id', participant.id);
    output.write(',');
    _field(output, 'surface', participant.surface);
    output.write(',');
    _floatField(output, 'x', participant.x);
    output.write(',');
    _floatField(output, 'y', participant.y);
    output.write(',');
    _floatField(output, 'rotation', participant.rotation);
    output.write(',');
    _floatField(output, 'velocityX', participant.velocityX);
    output.write(',');
    _floatField(output, 'velocityY', participant.velocityY);
    output.write(',');
    _floatField(output, 'angularVelocity', participant.angularVelocity);
    output.write(',');
    _floatField(output, 'longitudinalSpeed', participant.longitudinalSpeed);
    output.write(',');
    _floatField(output, 'lateralSpeed', participant.lateralSpeed);
    output.write(',');
    _floatField(output, 'driftAmount', participant.driftAmount);
    output.write(',');
    _field(output, 'checkpoint', participant.checkpoint);
    output.write(',');
    _field(output, 'lap', participant.lap);
    output.write(',');
    _field(output, 'racePosition', participant.racePosition);
    output.write(',');
    _field(output, 'finished', participant.finished);
    output.write('}');
  }

  static void _finishResult(
    StringBuffer output,
    CompatibilityFinishResult result,
  ) {
    output.write('{');
    _field(output, 'participantId', result.participantId);
    output.write(',');
    _field(output, 'finishPosition', result.finishPosition);
    output.write(',');
    _floatField(output, 'elapsedSimulationTime', result.elapsedSimulationTime);
    output.write(',"bestLapTime":');
    if (result.bestLapTime == null) {
      output.write('null');
    } else {
      _float(output, result.bestLapTime!);
    }
    output.write('}');
  }

  static void _stringArray(StringBuffer output, List<String> values) {
    output.write('[');
    for (var index = 0; index < values.length; index++) {
      if (index > 0) {
        output.write(',');
      }
      output.write(jsonEncode(values[index]));
    }
    output.write(']');
  }

  static void _field(StringBuffer output, String name, Object value) {
    output.write(jsonEncode(name));
    output.write(':');
    output.write(value is String ? jsonEncode(value) : value);
  }

  static void _floatField(StringBuffer output, String name, double value) {
    output.write(jsonEncode(name));
    output.write(':');
    _float(output, value);
  }

  static void _float(StringBuffer output, double value) {
    if (!value.isFinite) {
      throw CompatibilityFormatException(r'$', 'output numbers must be finite');
    }
    final narrowed = Float32.narrow(value);
    output.write(_formatFloat(narrowed));
  }

  static String _formatFloat(double value) {
    final formatted = value.toStringAsFixed(_fractionDigits);
    if (formatted == _negativeZero) {
      return _zero;
    }
    if (!formatted.contains('e')) {
      return formatted;
    }
    return _expandLargeFloat(value);
  }

  static String _expandLargeFloat(double value) {
    final scientific = value.abs().toString();
    final exponentMarker = scientific.indexOf('e');
    final significand = scientific.substring(0, exponentMarker);
    final exponent = int.parse(scientific.substring(exponentMarker + 1));
    final decimalIndex = significand.indexOf('.');
    final wholeDigits = decimalIndex == -1 ? significand.length : decimalIndex;
    final digits = significand.replaceAll('.', '');
    final expandedLength = wholeDigits + exponent;
    final integer = digits.padRight(expandedLength, '0');
    return '${value.isNegative ? '-' : ''}$integer.$_zeroFraction';
  }

  static void _validateTrace(CompatibilityTrace trace) {
    _requireNonBlank(trace.scenarioId, r'$.scenarioId');
    _validateSeed(trace.seed, r'$.seed');
    if (trace.samples.isEmpty) {
      _fail(r'$.samples', 'must contain at least one sample');
    }
    var previousTick = -1;
    for (var index = 0; index < trace.samples.length; index++) {
      final sample = trace.samples[index];
      final path = r'$.samples[$index]';
      if (!_sampleLabels.contains(sample.label)) {
        _fail('$path.label', 'has an unsupported value: ${sample.label}');
      }
      if (sample.tick < 0) {
        _fail('$path.tick', 'must not be negative');
      }
      if (sample.tick < previousTick) {
        _fail('$path.tick', 'must not move backwards in replay order');
      }
      previousTick = sample.tick;
      _validateSnapshot(sample.snapshot, '$path.snapshot');
    }
  }

  static void _validateSnapshot(CompatibilitySnapshot snapshot, String path) {
    if (snapshot.simulationTick < 0) {
      _fail('$path.simulationTick', 'must not be negative');
    }
    if (!_raceStates.contains(snapshot.raceState)) {
      _fail(
        '$path.raceState',
        'has an unsupported value: ${snapshot.raceState}',
      );
    }
    _validateCountdown(snapshot.countdown, '$path.countdown');
    _requireFiniteAtLeast(
      snapshot.elapsedSimulationTime,
      '$path.elapsedSimulationTime',
      0,
    );
    if (snapshot.currentLap < 1) {
      _fail('$path.currentLap', 'must be at least one');
    }
    if (snapshot.currentProgress.checkpoint < 0 ||
        snapshot.currentProgress.completedLaps < 0) {
      _fail('$path.currentProgress', 'must not contain negative progress');
    }
    _validateParticipants(snapshot, path);
    _validateFinishResults(snapshot, path);
  }

  static void _validateCountdown(
    CompatibilityCountdown countdown,
    String path,
  ) {
    if (!_countdownStates.contains(countdown.state)) {
      _fail('$path.state', 'has an unsupported value: ${countdown.state}');
    }
    _requireFiniteAtLeast(
      countdown.remainingSeconds,
      '$path.remainingSeconds',
      0,
    );
  }

  static void _validateParticipants(
    CompatibilitySnapshot snapshot,
    String path,
  ) {
    if (snapshot.participants.isEmpty) {
      _fail('$path.participants', 'must contain at least one participant');
    }
    final ids = <String>[];
    for (var index = 0; index < snapshot.participants.length; index++) {
      final participant = snapshot.participants[index];
      final participantPath = '$path.participants[$index]';
      _requireNonBlank(participant.id, '$participantPath.id');
      if (!_surfaces.contains(participant.surface)) {
        _fail(
          '$participantPath.surface',
          'has an unsupported value: ${participant.surface}',
        );
      }
      _requireFinite(participant.x, '$participantPath.x');
      _requireFinite(participant.y, '$participantPath.y');
      _requireFinite(participant.velocityX, '$participantPath.velocityX');
      _requireFinite(participant.velocityY, '$participantPath.velocityY');
      _requireFinite(
        participant.angularVelocity,
        '$participantPath.angularVelocity',
      );
      _requireFinite(
        participant.longitudinalSpeed,
        '$participantPath.longitudinalSpeed',
      );
      _requireFinite(participant.lateralSpeed, '$participantPath.lateralSpeed');
      _requireFiniteInRange(
        participant.rotation,
        '$participantPath.rotation',
        0,
        360,
        exclusiveMaximum: true,
      );
      _requireFiniteInRange(
        participant.driftAmount,
        '$participantPath.driftAmount',
        0,
        1,
      );
      if (participant.checkpoint < 0 ||
          participant.lap < 0 ||
          participant.racePosition < 1) {
        _fail(participantPath, 'contains invalid progress or race position');
      }
      ids.add(participant.id);
    }
    final sortedIds = List<String>.of(ids)..sort();
    if (!_sameValues(ids, sortedIds) || ids.toSet().length != ids.length) {
      _fail(
        '$path.participants',
        'must be unique and sorted by participant ID',
      );
    }
    final expectedRanking =
        List<CompatibilityParticipantSnapshot>.of(snapshot.participants)..sort((
          left,
          right,
        ) {
          final positionOrder = left.racePosition.compareTo(right.racePosition);
          return positionOrder != 0
              ? positionOrder
              : left.id.compareTo(right.id);
        });
    if (!_sameValues(
      snapshot.ranking,
      expectedRanking.map((value) => value.id).toList(),
    )) {
      _fail(
        '$path.ranking',
        'must match participants sorted by race position and ID',
      );
    }
  }

  static void _validateFinishResults(
    CompatibilitySnapshot snapshot,
    String path,
  ) {
    final participantIds = snapshot.participants
        .map((value) => value.id)
        .toSet();
    final finishedIds = snapshot.participants
        .where((value) => value.finished)
        .map((value) => value.id)
        .toSet();
    final resultIds = <String>[];
    final positions = <int>{};
    for (var index = 0; index < snapshot.finishResults.length; index++) {
      final result = snapshot.finishResults[index];
      final resultPath = '$path.finishResults[$index]';
      _requireNonBlank(result.participantId, '$resultPath.participantId');
      if (!participantIds.contains(result.participantId) ||
          !finishedIds.contains(result.participantId)) {
        _fail(resultPath, 'must describe a finished participant');
      }
      if (result.finishPosition < 1 || !positions.add(result.finishPosition)) {
        _fail(
          '$resultPath.finishPosition',
          'must be a unique positive position',
        );
      }
      _requireFiniteAtLeast(
        result.elapsedSimulationTime,
        '$resultPath.elapsedSimulationTime',
        0,
      );
      if (result.bestLapTime != null) {
        _requireFiniteAtLeast(
          result.bestLapTime!,
          '$resultPath.bestLapTime',
          0,
        );
      }
      resultIds.add(result.participantId);
    }
    final orderedResults =
        List<CompatibilityFinishResult>.of(snapshot.finishResults)
          ..sort((left, right) {
            final positionOrder = left.finishPosition.compareTo(
              right.finishPosition,
            );
            return positionOrder != 0
                ? positionOrder
                : left.participantId.compareTo(right.participantId);
          });
    final orderedIds = orderedResults
        .map((value) => value.participantId)
        .toList();
    if (!_sameValues(resultIds, orderedIds) ||
        resultIds.toSet().length != resultIds.length) {
      _fail(
        '$path.finishResults',
        'must be unique and sorted by finish position and ID',
      );
    }
    final sortedResultIds = resultIds.toSet().toList()..sort();
    final sortedFinishedIds = finishedIds.toList()..sort();
    if (!_sameValues(sortedResultIds, sortedFinishedIds)) {
      _fail(
        '$path.finishResults',
        'must contain every finished participant exactly once',
      );
    }
    if (!_sameValues(snapshot.finishedParticipants, resultIds)) {
      _fail('$path.finishedParticipants', 'must match finishResults order');
    }
  }

  static void _validateSeed(String seed, String path) {
    if (!_canonicalSeed.hasMatch(seed)) {
      _fail(path, 'must be a canonical signed 64-bit integer');
    }
    final value = BigInt.parse(seed);
    if (value < _minimumSeed || value > _maximumSeed) {
      _fail(path, 'must fit in a signed 64-bit integer');
    }
  }

  static void _requireNonBlank(String value, String path) {
    if (value.isEmpty) {
      _fail(path, 'must not be empty');
    }
  }

  static double _requireFinite(double value, String path) {
    if (!value.isFinite) {
      _fail(path, 'must be finite');
    }
    try {
      return Float32.narrow(value);
    } on ArgumentError {
      _fail(path, 'must fit in a finite IEEE-754 binary32 value');
    }
  }

  static void _requireFiniteAtLeast(double value, String path, double minimum) {
    _requireFinite(value, path);
    if (value < minimum) {
      _fail(path, 'must be at least $minimum');
    }
  }

  static void _requireFiniteInRange(
    double value,
    String path,
    double minimum,
    double maximum, {
    bool exclusiveMaximum = false,
  }) {
    final narrowed = _requireFinite(value, path);
    if (narrowed < minimum ||
        (exclusiveMaximum ? narrowed >= maximum : narrowed > maximum)) {
      _fail(path, 'must be in the required range');
    }
  }

  static bool _sameValues<T>(List<T> left, List<T> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  static Never _fail(String path, String message) {
    throw CompatibilityFormatException(path, message);
  }

  static final RegExp _canonicalSeed = RegExp(r'^-?(?:0|[1-9][0-9]*)$');
  static final BigInt _minimumSeed = BigInt.parse('-9223372036854775808');
  static final BigInt _maximumSeed = BigInt.parse('9223372036854775807');
  static const Set<String> _countdownStates = <String>{
    'not-started',
    'active',
    'complete',
  };
  static const Set<String> _raceStates = <String>{
    'loading',
    'ready',
    'countdown',
    'racing',
    'paused',
    'finished',
  };
  static const Set<String> _sampleLabels = <String>{
    'loading',
    'ready',
    'countdown',
    'racing',
    'simulation',
    'checkpoint',
    'lap',
    'finish',
  };
  static const Set<String> _surfaces = <String>{
    'asphalt',
    'parquet',
    'tile',
    'grass',
    'boost',
    'oil',
  };
  static const int _fractionDigits = 6;
  static const String _negativeZero = '-0.000000';
  static const String _zero = '0.000000';
  static const String _zeroFraction = '000000';
}
