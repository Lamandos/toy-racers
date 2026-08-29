import 'dart:convert';
import 'dart:io';

import 'package:toy_racers/simulation.dart';

/// A reusable full inventory discovered from checked-in scenario sources.
final class BehavioralInventory {
  BehavioralInventory._(this.fixtures);

  final List<BehavioralFixture> fixtures;

  static BehavioralInventory load(
    Directory repositoryRoot,
    Directory expectedOutput,
  ) {
    final legacy = _legacyFixtures(repositoryRoot, expectedOutput);
    final files = _fileFixtures(repositoryRoot);
    return BehavioralInventory._(<BehavioralFixture>[...legacy, ...files]);
  }

  static List<BehavioralFixture> _legacyFixtures(
    Directory repositoryRoot,
    Directory expectedOutput,
  ) {
    final fixtureDirectory = Directory.fromUri(
      repositoryRoot.uri.resolve('core/src/test/resources/compat/'),
    );
    final scenariosFile = File.fromUri(
      fixtureDirectory.uri.resolve('scenarios.json'),
    );
    final goldensFile = File.fromUri(
      fixtureDirectory.uri.resolve('goldens.json'),
    );
    final scenarios = _parseLegacyScenarios(scenariosFile, fixtureDirectory);
    final traces = _legacyTraces(goldensFile);
    _validateLegacyCoverage(scenarios, traces);
    return <BehavioralFixture>[
      for (final scenario in scenarios)
        BehavioralFixture(
          label: 'legacy/${scenario.id}',
          category: legacyCategory,
          outputPath: 'legacy/${scenario.id}.json',
          scenario: scenario,
          expectedGolden: _writeLegacyGolden(
            expectedOutput,
            scenario.id,
            traces[scenario.id]!,
          ),
        ),
    ];
  }

  static List<CompatibilityScenario> _parseLegacyScenarios(
    File scenariosFile,
    Directory fixtureDirectory,
  ) => const CompatibilityScenarioParser()
      .parseScenarioDocument(
        scenariosFile.readAsStringSync(),
        inputScriptSource: (name) =>
            File.fromUri(fixtureDirectory.uri.resolve(name)).readAsStringSync(),
      )
      .scenarios;

  static void _validateLegacyCoverage(
    List<CompatibilityScenario> scenarios,
    Map<String, Object?> traces,
  ) {
    final scenarioIds = scenarios.map((scenario) => scenario.id).toSet();
    if (traces.keys.toSet().difference(scenarioIds).isNotEmpty ||
        scenarioIds.difference(traces.keys.toSet()).isNotEmpty) {
      throw StateError(
        'Legacy scenarios and golden traces must have matching IDs.',
      );
    }
  }

  static List<BehavioralFixture> _fileFixtures(Directory repositoryRoot) {
    final scenarioDirectory = Directory.fromUri(
      repositoryRoot.uri.resolve('compatibility/scenarios/'),
    );
    final goldenDirectory = Directory.fromUri(
      repositoryRoot.uri.resolve('compatibility/golden/'),
    );
    final files = _jsonFiles(scenarioDirectory);
    final scenarioFiles = <File>[];
    final referencedScripts = <String>{};
    for (final file in files) {
      final document = _jsonObject(file);
      if (document.containsKey(_scenariosField)) {
        scenarioFiles.add(file);
        referencedScripts.addAll(_referencedScripts(file, document));
      }
    }
    _validateInputScripts(files, scenarioFiles, referencedScripts);
    final fixtures = scenarioFiles
        .map((file) => _fileFixture(file, scenarioDirectory, goldenDirectory))
        .toList();
    _validateGoldenCoverage(goldenDirectory, fixtures);
    return fixtures;
  }

  static BehavioralFixture _fileFixture(
    File file,
    Directory scenarioDirectory,
    Directory goldenDirectory,
  ) {
    final relativePath = _relativePath(scenarioDirectory, file);
    final document = _parseFileScenario(file);
    if (document.scenarios.length != 1) {
      throw StateError('$relativePath must contain exactly one scenario.');
    }
    final expectedGolden = File.fromUri(
      goldenDirectory.uri.resolve(relativePath),
    );
    if (!expectedGolden.existsSync()) {
      throw StateError('Missing golden for $relativePath.');
    }
    return BehavioralFixture(
      label: relativePath,
      category: _category(relativePath),
      outputPath: 'file/$relativePath',
      scenario: document.scenarios.single,
      expectedGolden: expectedGolden,
    );
  }

  static Map<String, Object?> _legacyTraces(File file) {
    final root = _jsonObject(file);
    final value = root['traces'];
    if (value is! Map<String, dynamic>) {
      throw StateError('Legacy golden document must contain a traces object.');
    }
    return Map<String, Object?>.from(value);
  }

  static File _writeLegacyGolden(
    Directory output,
    String scenarioId,
    Object? trace,
  ) {
    final file = File.fromUri(output.uri.resolve('legacy/$scenarioId.json'));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(trace));
    return file;
  }

  static Iterable<String> _referencedScripts(
    File file,
    Map<String, dynamic> document,
  ) sync* {
    final scenarios = document[_scenariosField];
    if (scenarios is! List<dynamic>) {
      return;
    }
    for (final scenario in scenarios) {
      if (scenario is! Map<String, dynamic>) {
        continue;
      }
      final inputScript = scenario[_inputScriptField];
      if (inputScript is String) {
        yield File.fromUri(file.parent.uri.resolve(inputScript)).absolute.path;
      }
    }
  }

  static void _validateInputScripts(
    List<File> files,
    List<File> scenarios,
    Set<String> referencedScripts,
  ) {
    final scenarioPaths = scenarios.map((file) => file.absolute.path).toSet();
    final ignored = files
        .map((file) => file.absolute.path)
        .where((path) => !scenarioPaths.contains(path))
        .toSet();
    if (ignored.difference(referencedScripts).isNotEmpty ||
        referencedScripts.difference(ignored).isNotEmpty) {
      throw StateError(
        'Every non-scenario JSON file must be a referenced input script.',
      );
    }
  }

  static CompatibilityScenarioDocument _parseFileScenario(File file) =>
      const CompatibilityScenarioParser().parseScenarioDocument(
        file.readAsStringSync(),
        inputScriptSource: (name) =>
            File.fromUri(file.parent.uri.resolve(name)).readAsStringSync(),
      );

  static void _validateGoldenCoverage(
    Directory goldenDirectory,
    List<BehavioralFixture> fixtures,
  ) {
    final expected = fixtures.map((fixture) => fixture.label).toSet();
    final actual = _jsonFiles(goldenDirectory)
        .map((file) => _relativePath(goldenDirectory, file))
        .toSet();
    final missingGoldens = expected.difference(actual);
    final unexpectedGoldens = actual.difference(expected);
    if (expected.length != fixtures.length ||
        missingGoldens.isNotEmpty ||
        unexpectedGoldens.isNotEmpty) {
      throw StateError(
        'File scenarios and golden traces must map one-to-one: '
        'missing=$missingGoldens unexpected=$unexpectedGoldens.',
      );
    }
  }

  static Map<String, dynamic> _jsonObject(File file) {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw StateError('${file.path} must contain a JSON object.');
    }
    return decoded;
  }

  static String _relativePath(Directory root, File file) {
    final rootPath = root.uri.path;
    final filePath = file.uri.path;
    if (!filePath.startsWith(rootPath)) {
      throw StateError('${file.path} is outside ${root.path}.');
    }
    return filePath.substring(rootPath.length);
  }

  static String _category(String relativePath) => relativePath.split('/').first;

  static const String _inputScriptField = 'inputScript';
  static const String legacyCategory = 'legacy';
  static const String _scenariosField = 'scenarios';
}

/// One scenario and its read-only expected trace.
final class BehavioralFixture {
  const BehavioralFixture({
    required this.label,
    required this.category,
    required this.outputPath,
    required this.scenario,
    required this.expectedGolden,
  });

  final String label;
  final String category;
  final String outputPath;
  final CompatibilityScenario scenario;
  final File expectedGolden;
}

List<File> _jsonFiles(Directory directory) =>
    directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((left, right) => left.path.compareTo(right.path));
