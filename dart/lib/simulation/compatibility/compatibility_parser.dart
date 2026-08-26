import '../input/driver_input.dart';
import '../math/float32.dart';
import 'compatibility_exception.dart';
import 'compatibility_models.dart';
import 'strict_json_reader.dart';

/// Supplies an input-script source by its validated, directory-local filename.
///
/// The scenario contract only permits a lowercase-hyphen filename, never a
/// path.  A file-backed runner should therefore resolve this value directly
/// beside the scenario it is reading.
typedef CompatibilityInputScriptSource = String Function(String filename);

/// Parses the shared compatibility documents without a Dart-specific schema.
///
/// Validation follows the versioned JSON documents under
/// `compatibility/schemas/`.  Numeric values are narrowed to binary32 at the
/// same input boundary as Kotlin `Float`, while signed 64-bit seeds stay in
/// exact decimal form.
final class CompatibilityScenarioParser {
  const CompatibilityScenarioParser();

  /// Parses a scenario v1, v2, or v3 document and resolves any v1 input script.
  CompatibilityScenarioDocument parseScenarioDocument(
    String source, {
    required CompatibilityInputScriptSource inputScriptSource,
  }) {
    final root = _object(readCompatibilityJson(source), r'$');
    _requireOnlyProperties(root, _documentProperties, r'$');
    final schemaVersion = _intInRange(
      _required(root, 'schemaVersion', r'$'),
      r'$.schemaVersion',
      minimum: 1,
      maximum: 3,
    );
    final scenarios = _array(
      _required(root, 'scenarios', r'$'),
      r'$.scenarios',
    );
    if (scenarios.values.isEmpty) {
      _fail(r'$.scenarios', 'must be a non-empty array');
    }
    return CompatibilityScenarioDocument(
      schemaVersion: schemaVersion,
      scenarios: <CompatibilityScenario>[
        for (var index = 0; index < scenarios.values.length; index++)
          _parseScenario(
            scenarios.values[index],
            r'$.scenarios[$index]',
            schemaVersion,
            inputScriptSource,
          ),
      ],
    );
  }

  /// Parses a standalone input-script v1 document.
  CompatibilityInputScript parseInputScriptDocument(
    String source, {
    String path = r'$',
  }) {
    final root = _object(readCompatibilityJson(source), path);
    _requireOnlyProperties(root, _inputScriptProperties, path);
    final version = _intInRange(
      _required(root, 'schemaVersion', path),
      '$path.schemaVersion',
      minimum: CompatibilityInputScript.schemaVersion,
      maximum: CompatibilityInputScript.schemaVersion,
    );
    if (version != CompatibilityInputScript.schemaVersion) {
      _fail('$path.schemaVersion', 'has an unsupported input-script version');
    }
    final segments = _parseInputSegments(
      _required(root, 'segments', path),
      '$path.segments',
    );
    _validateScriptSegments(segments, '$path.segments');
    return CompatibilityInputScript(segments: segments);
  }

  CompatibilityScenario _parseScenario(
    CompatibilityJsonValue value,
    String path,
    int schemaVersion,
    CompatibilityInputScriptSource inputScriptSource,
  ) {
    final object = _object(value, path);
    final allowed = schemaVersion == 1
        ? _legacyScenarioProperties
        : _scenarioProperties;
    _requireOnlyProperties(object, allowed, path);
    final id = _scenarioId(_required(object, 'id', path), '$path.id');
    final seed = _seed(_required(object, 'seed', path), '$path.seed');
    final trackId = _enum(
      _required(object, 'trackId', path),
      '$path.trackId',
      _trackIds,
    );
    final playerCar = _enum(
      _required(object, 'playerCar', path),
      '$path.playerCar',
      _playerCars,
    );
    final inputOrigin = _enum(
      _required(object, 'inputOrigin', path),
      '$path.inputOrigin',
      _inputOrigins,
    );
    final tags = _tags(_required(object, 'tags', path), '$path.tags');
    final ticks = _intInRange(
      _required(object, 'ticks', path),
      '$path.ticks',
      minimum: 1,
      maximum: _maximumTick,
    );
    final snapshotIntervalTicks = _intInRange(
      _required(object, 'snapshotIntervalTicks', path),
      '$path.snapshotIntervalTicks',
      minimum: 1,
      maximum: _maximumTick,
    );
    final hasInlineSegments = object.values.containsKey('inputSegments');
    final hasInputScript = object.values.containsKey('inputScript');
    if (hasInlineSegments == hasInputScript) {
      _fail(path, 'must contain exactly one of inputSegments or inputScript');
    }
    final inputSegments = hasInlineSegments
        ? _parseInputSegments(
            object.values['inputSegments']!,
            '$path.inputSegments',
          )
        : _readInputScript(object, path, inputScriptSource).segments;
    _validateSegments(inputSegments, '$path.inputSegments', ticks);
    final inputTweaks = schemaVersion == 1
        ? const <CompatibilityInputTweak>[]
        : _parseInputTweaks(
            object.values['inputTweaks'],
            '$path.inputTweaks',
            ticks,
          );
    final initialStates = _parseInitialStates(
      object.values['initialStates'],
      '$path.initialStates',
      trackId,
      schemaVersion,
    );
    final fullRace = object.values.containsKey('fullRace')
        ? _boolean(object.values['fullRace']!, '$path.fullRace')
        : false;
    return CompatibilityScenario(
      schemaVersion: schemaVersion,
      id: id,
      seed: seed,
      trackId: trackId,
      playerCar: playerCar,
      inputOrigin: inputOrigin,
      tags: tags,
      ticks: ticks,
      snapshotIntervalTicks: snapshotIntervalTicks,
      inputSegments: inputSegments,
      inputTweaks: inputTweaks,
      initialStates: initialStates,
      fullRace: fullRace,
    );
  }

  CompatibilityInputScript _readInputScript(
    CompatibilityJsonObject scenario,
    String path,
    CompatibilityInputScriptSource inputScriptSource,
  ) {
    final filename = _string(
      scenario.values['inputScript']!,
      '$path.inputScript',
    );
    if (!_inputScriptFilename.hasMatch(filename)) {
      _fail('$path.inputScript', 'must be a lowercase-hyphen JSON filename');
    }
    return parseInputScriptDocument(
      inputScriptSource(filename),
      path: 'input script $filename',
    );
  }

  List<CompatibilityInputSegment> _parseInputSegments(
    CompatibilityJsonValue value,
    String path,
  ) {
    final segments = _array(value, path);
    if (segments.values.isEmpty) {
      _fail(path, 'must be a non-empty array');
    }
    return <CompatibilityInputSegment>[
      for (var index = 0; index < segments.values.length; index++)
        _parseInputSegment(segments.values[index], '$path[$index]'),
    ];
  }

  CompatibilityInputSegment _parseInputSegment(
    CompatibilityJsonValue value,
    String path,
  ) {
    final object = _object(value, path);
    _requireOnlyProperties(object, _inputSegmentProperties, path);
    return CompatibilityInputSegment(
      fromTick: _intInRange(
        _required(object, 'fromTick', path),
        '$path.fromTick',
        minimum: 1,
        maximum: _maximumTick,
      ),
      toTick: _intInRange(
        _required(object, 'toTick', path),
        '$path.toTick',
        minimum: 1,
        maximum: _maximumTick,
      ),
      input: DriverInput(
        throttle: _optionalFloat(object, 'throttle', path) ?? 0,
        brake: _optionalFloat(object, 'brake', path) ?? 0,
        steering: _optionalFloat(object, 'steering', path) ?? 0,
      ),
    );
  }

  List<CompatibilityInputTweak> _parseInputTweaks(
    CompatibilityJsonValue? value,
    String path,
    int ticks,
  ) {
    if (value == null) {
      return const <CompatibilityInputTweak>[];
    }
    final tweaks = _array(value, path);
    final parsed = <CompatibilityInputTweak>[];
    for (var index = 0; index < tweaks.values.length; index++) {
      final itemPath = '$path[$index]';
      final object = _object(tweaks.values[index], itemPath);
      _requireOnlyProperties(object, _inputTweakProperties, itemPath);
      parsed.add(
        CompatibilityInputTweak(
          tick: _intInRange(
            _required(object, 'tick', itemPath),
            '$itemPath.tick',
            minimum: 1,
            maximum: ticks,
          ),
          delta: DriverInput(
            throttle: _optionalFloat(object, 'throttleDelta', itemPath) ?? 0,
            brake: _optionalFloat(object, 'brakeDelta', itemPath) ?? 0,
            steering: _optionalFloat(object, 'steeringDelta', itemPath) ?? 0,
          ),
        ),
      );
    }
    for (var index = 1; index < parsed.length; index++) {
      if (parsed[index - 1].tick >= parsed[index].tick) {
        _fail(path, 'must have strictly ascending, unique ticks');
      }
    }
    return parsed;
  }

  List<CompatibilityInitialState> _parseInitialStates(
    CompatibilityJsonValue? value,
    String path,
    String trackId,
    int schemaVersion,
  ) {
    if (value == null) {
      return const <CompatibilityInitialState>[];
    }
    final states = _array(value, path);
    final finishPositions = <int>{};
    final parsed = <CompatibilityInitialState>[];
    for (var index = 0; index < states.values.length; index++) {
      final itemPath = '$path[$index]';
      final object = _object(states.values[index], itemPath);
      _requireOnlyProperties(
        object,
        schemaVersion == 3
            ? _v3InitialStateProperties
            : _legacyInitialStateProperties,
        itemPath,
      );
      final lapStartTime = _optionalFloatAtLeast(
        object,
        'lapStartTime',
        itemPath,
        minimum: 0,
      );
      final totalRaceTime = _optionalFloatAtLeast(
        object,
        'totalRaceTime',
        itemPath,
        minimum: 0,
      );
      if (lapStartTime != null && lapStartTime > (totalRaceTime ?? 0)) {
        _fail('$itemPath.lapStartTime', 'must not exceed totalRaceTime');
      }
      final finished = object.values.containsKey('finished')
          ? _boolean(object.values['finished']!, '$itemPath.finished')
          : false;
      final finishPosition = object.values.containsKey('finishPosition')
          ? _intInRange(
              object.values['finishPosition']!,
              '$itemPath.finishPosition',
              minimum: 1,
              maximum: _maximumFinishPosition,
            )
          : null;
      if (finished && finishPosition == null) {
        _fail('$itemPath.finishPosition', 'is required when finished is true');
      }
      if (!finished && finishPosition != null) {
        _fail(
          '$itemPath.finished',
          'must be true when finishPosition is provided',
        );
      }
      if (finishPosition != null && !finishPositions.add(finishPosition)) {
        _fail(
          '$itemPath.finishPosition',
          'must be unique across initialStates',
        );
      }
      parsed.add(
        CompatibilityInitialState(
          id: _enum(
            _required(object, 'id', itemPath),
            '$itemPath.id',
            _initialStateIds,
          ),
          x: _optionalFloat(object, 'x', itemPath),
          y: _optionalFloat(object, 'y', itemPath),
          rotationDeg: _optionalFloat(object, 'rotationDeg', itemPath),
          speed: _optionalFloat(object, 'speed', itemPath),
          velocityX: _optionalFloat(object, 'velocityX', itemPath),
          velocityY: _optionalFloat(object, 'velocityY', itemPath),
          angularVelocity: _optionalFloat(object, 'angularVelocity', itemPath),
          lateralSpeed: _optionalFloat(object, 'lateralSpeed', itemPath),
          driftAmount: _optionalFloatInRange(
            object,
            'driftAmount',
            itemPath,
            minimum: 0,
            maximum: 1,
          ),
          surfaceSpeedMultiplier: _optionalFloatInRange(
            object,
            'surfaceSpeedMultiplier',
            itemPath,
            minimum: 0,
            maximum: 1,
          ),
          currentCheckpointIndex: _optionalIntInRange(
            object,
            'currentCheckpointIndex',
            itemPath,
            minimum: 0,
            maximum: _checkpointMaximum(trackId),
          ),
          completedLaps: _optionalIntInRange(
            object,
            'completedLaps',
            itemPath,
            minimum: 0,
            maximum: 3,
          ),
          lapStartTime: lapStartTime,
          totalRaceTime: totalRaceTime,
          bestLapTime: _optionalFloatAtLeast(
            object,
            'bestLapTime',
            itemPath,
            minimum: 0,
          ),
          finished: object.values.containsKey('finished') ? finished : null,
          finishPosition: finishPosition,
        ),
      );
    }
    return parsed;
  }

  void _validateScriptSegments(
    List<CompatibilityInputSegment> segments,
    String path,
  ) {
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (segment.fromTick > segment.toTick) {
        _fail('$path[$index]', 'has an invalid input range');
      }
      if (index > 0 && segments[index - 1].toTick >= segment.fromTick) {
        _fail(path, 'contains overlapping or unordered input ranges');
      }
    }
  }

  void _validateSegments(
    List<CompatibilityInputSegment> segments,
    String path,
    int ticks,
  ) {
    _validateScriptSegments(segments, path);
    for (var index = 0; index < segments.length; index++) {
      if (segments[index].toTick > ticks) {
        _fail('$path[$index]', 'has an input range outside scenario ticks');
      }
    }
  }

  List<String> _tags(CompatibilityJsonValue value, String path) {
    final tags = _array(value, path).values;
    final result = <String>[];
    final unique = <String>{};
    for (var index = 0; index < tags.length; index++) {
      final tag = _string(tags[index], '$path[$index]');
      if (!unique.add(tag)) {
        _fail(path, 'must not contain duplicate tags');
      }
      result.add(tag);
    }
    return result;
  }

  String _seed(CompatibilityJsonValue value, String path) {
    final seed = _integer(value, path);
    if (seed < _minimumSeed || seed > _maximumSeed) {
      _fail(path, 'must fit in a signed 64-bit integer');
    }
    return seed.toString();
  }

  int _checkpointMaximum(String trackId) => trackId == 'track-01' ? 3 : 5;

  static CompatibilityJsonObject _object(
    CompatibilityJsonValue value,
    String path,
  ) {
    if (value is CompatibilityJsonObject) {
      return value;
    }
    _fail(path, 'must be an object');
  }

  static CompatibilityJsonArray _array(
    CompatibilityJsonValue value,
    String path,
  ) {
    if (value is CompatibilityJsonArray) {
      return value;
    }
    _fail(path, 'must be an array');
  }

  static CompatibilityJsonValue _required(
    CompatibilityJsonObject object,
    String name,
    String path,
  ) {
    final value = object.values[name];
    if (value == null) {
      _fail('$path.$name', 'is required');
    }
    return value;
  }

  static String _string(CompatibilityJsonValue value, String path) {
    if (value is CompatibilityJsonString) {
      return value.value;
    }
    _fail(path, 'must be a string');
  }

  static bool _boolean(CompatibilityJsonValue value, String path) {
    if (value is CompatibilityJsonBoolean) {
      return value.value;
    }
    _fail(path, 'must be a boolean');
  }

  static String _enum(
    CompatibilityJsonValue value,
    String path,
    Set<String> allowed,
  ) {
    final result = _string(value, path);
    if (!allowed.contains(result)) {
      _fail(path, 'has an unsupported value: $result');
    }
    return result;
  }

  static String _scenarioId(CompatibilityJsonValue value, String path) {
    final id = _string(value, path);
    if (!_scenarioIdPattern.hasMatch(id)) {
      _fail(path, 'must be a lowercase kebab-case identifier');
    }
    return id;
  }

  static int _intInRange(
    CompatibilityJsonValue value,
    String path, {
    required int minimum,
    required int maximum,
  }) {
    final integer = _integer(value, path);
    final minimumValue = BigInt.from(minimum);
    final maximumValue = BigInt.from(maximum);
    if (integer < minimumValue || integer > maximumValue) {
      _fail(path, 'must be in the range $minimum..$maximum');
    }
    return integer.toInt();
  }

  static int? _optionalIntInRange(
    CompatibilityJsonObject object,
    String name,
    String path, {
    required int minimum,
    required int maximum,
  }) {
    final value = object.values[name];
    return value == null
        ? null
        : _intInRange(value, '$path.$name', minimum: minimum, maximum: maximum);
  }

  static BigInt _integer(CompatibilityJsonValue value, String path) {
    if (value is! CompatibilityJsonNumber) {
      _fail(path, 'must be an integer');
    }
    final integer = value.integralValue;
    if (integer == null) {
      _fail(path, 'must be an integer');
    }
    return integer;
  }

  static double? _optionalFloat(
    CompatibilityJsonObject object,
    String name,
    String path,
  ) {
    final value = object.values[name];
    return value == null ? null : _float(value, '$path.$name');
  }

  static double? _optionalFloatAtLeast(
    CompatibilityJsonObject object,
    String name,
    String path, {
    required double minimum,
  }) => _optionalFloatInRange(
    object,
    name,
    path,
    minimum: minimum,
    maximum: null,
  );

  static double? _optionalFloatInRange(
    CompatibilityJsonObject object,
    String name,
    String path, {
    required double minimum,
    required double? maximum,
  }) {
    final value = object.values[name];
    if (value == null) {
      return null;
    }
    final fieldPath = '$path.$name';
    final number = _finiteNumber(value, fieldPath);
    if (number < minimum || (maximum != null && number > maximum)) {
      final range = maximum == null
          ? 'at least $minimum'
          : 'in the range $minimum..$maximum';
      _fail(fieldPath, 'must be $range');
    }
    return _narrowFloat(number, fieldPath);
  }

  static double _float(CompatibilityJsonValue value, String path) {
    return _narrowFloat(_finiteNumber(value, path), path);
  }

  static double _finiteNumber(CompatibilityJsonValue value, String path) {
    if (value is! CompatibilityJsonNumber) {
      _fail(path, 'must be a number');
    }
    final number = value.finiteDouble;
    if (number == null) {
      _fail(path, 'must be a finite number');
    }
    return number;
  }

  static double _narrowFloat(double number, String path) {
    try {
      return Float32.narrow(number);
    } on ArgumentError {
      _fail(path, 'must fit in a finite IEEE-754 binary32 value');
    }
  }

  static void _requireOnlyProperties(
    CompatibilityJsonObject object,
    Set<String> allowed,
    String path,
  ) {
    for (final name in object.values.keys) {
      if (!allowed.contains(name)) {
        _fail('$path.$name', 'is not allowed by this schema version');
      }
    }
  }

  static Never _fail(String path, String message) {
    throw CompatibilityFormatException(path, message);
  }

  static const int _maximumFinishPosition = 6;
  static const int _maximumTick = 2147483647;
  static final BigInt _minimumSeed = BigInt.parse('-9223372036854775808');
  static final BigInt _maximumSeed = BigInt.parse('9223372036854775807');
  static final RegExp _inputScriptFilename = RegExp(
    r'^[a-z0-9][a-z0-9-]*\.json$',
  );
  static final RegExp _scenarioIdPattern = RegExp(
    r'^[a-z0-9]+(?:-[a-z0-9]+)*$',
  );
  static const Set<String> _documentProperties = <String>{
    'schemaVersion',
    'scenarios',
  };
  static const Set<String> _inputScriptProperties = <String>{
    'schemaVersion',
    'segments',
  };
  static const Set<String> _inputSegmentProperties = <String>{
    'fromTick',
    'toTick',
    'throttle',
    'brake',
    'steering',
  };
  static const Set<String> _inputTweakProperties = <String>{
    'tick',
    'throttleDelta',
    'brakeDelta',
    'steeringDelta',
  };
  static const Set<String> _scenarioProperties = <String>{
    'id',
    'seed',
    'trackId',
    'playerCar',
    'inputOrigin',
    'tags',
    'ticks',
    'snapshotIntervalTicks',
    'inputSegments',
    'inputScript',
    'inputTweaks',
    'initialStates',
    'fullRace',
  };
  static const Set<String> _legacyScenarioProperties = <String>{
    'id',
    'seed',
    'trackId',
    'playerCar',
    'inputOrigin',
    'tags',
    'ticks',
    'snapshotIntervalTicks',
    'inputSegments',
    'inputScript',
    'initialStates',
    'fullRace',
  };
  static const Set<String> _legacyInitialStateProperties = <String>{
    'id',
    'x',
    'y',
    'rotationDeg',
    'speed',
    'velocityX',
    'velocityY',
    'angularVelocity',
    'lateralSpeed',
    'driftAmount',
    'surfaceSpeedMultiplier',
    'currentCheckpointIndex',
    'completedLaps',
    'totalRaceTime',
    'finished',
    'finishPosition',
  };
  static const Set<String> _v3InitialStateProperties = <String>{
    'id',
    'x',
    'y',
    'rotationDeg',
    'speed',
    'velocityX',
    'velocityY',
    'angularVelocity',
    'lateralSpeed',
    'driftAmount',
    'surfaceSpeedMultiplier',
    'currentCheckpointIndex',
    'completedLaps',
    'lapStartTime',
    'totalRaceTime',
    'bestLapTime',
    'finished',
    'finishPosition',
  };
  static const Set<String> _initialStateIds = <String>{
    'player',
    'ai-0',
    'ai-1',
    'ai-2',
    'ai-3',
    'ai-4',
  };
  static const Set<String> _inputOrigins = <String>{'keyboard', 'touch'};
  static const Set<String> _playerCars = <String>{
    'red-stripe',
    'blue-stripe',
    'yellow-sport',
    'green-racer',
    'orange-truck',
  };
  static const Set<String> _trackIds = <String>{'track-01', 'track-02'};
}
