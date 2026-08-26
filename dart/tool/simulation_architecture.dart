import 'dart:collection';
import 'dart:io';

final _directivePattern = RegExp(
  r'''^[ \t]*(?:import|export|part)\b[^;]*;''',
  multiLine: true,
);
final _uriPattern = RegExp(r'''['"]([^'"]+)['"]''');
final _namedPartOfPattern = RegExp(
  r'''^[ \t]*part\s+of\s+(?!['"])[^;]+;''',
  multiLine: true,
);
final _wallClockPattern = RegExp(
  r'''(?:DateTime\.(?:now|timestamp)\b|Stopwatch\s*\(|\b(?:[A-Za-z_]\w*\s*\.\s*)?Timer\s*(?:\(|\.\s*(?:new|periodic|run)\b)|Future(?:<[^>]+>)?\.delayed\b)''',
);

/// Finds presentation or wall-clock dependencies reachable from simulation.
///
/// Every simulation source is a root so an unexported source cannot bypass
/// the boundary check. Local imports are followed recursively, including
/// imports outside `lib/simulation`; all URI alternatives in conditional
/// directives are inspected.
List<String> findSimulationArchitectureViolations({
  required Directory libDirectory,
}) {
  final simulationDirectory = Directory(
    '${libDirectory.path}${Platform.pathSeparator}simulation',
  );
  final entryPoints = <File>[
    File('${libDirectory.path}${Platform.pathSeparator}simulation.dart'),
    ...simulationDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ];
  return findArchitectureViolations(
    libDirectory: libDirectory,
    entryPoints: entryPoints,
  );
}

/// Finds prohibited dependencies reachable from [entryPoints].
List<String> findArchitectureViolations({
  required Directory libDirectory,
  required Iterable<File> entryPoints,
}) {
  final pending = Queue<File>()..addAll(entryPoints);
  final visited = <String>{};
  final violations = <String>{};

  while (pending.isNotEmpty) {
    final sourceFile = pending.removeFirst().absolute;
    if (!sourceFile.existsSync() || !visited.add(sourceFile.path)) {
      continue;
    }
    final source = sourceFile.readAsStringSync();
    if (_namedPartOfPattern.hasMatch(source)) {
      violations.add('${sourceFile.path} uses a named part of declaration');
    }
    if (_wallClockPattern.hasMatch(source)) {
      violations.add('${sourceFile.path} references wall-clock APIs');
    }

    for (final directive in _directivePattern.allMatches(source)) {
      final directiveText = directive.group(0)!;
      for (final uriMatch in _uriPattern.allMatches(directiveText)) {
        final uri = uriMatch.group(1)!;
        if (_isProhibitedPresentationUri(uri)) {
          violations.add('${sourceFile.path} references $uri');
        }
        final localDependency = _resolveLocalDependency(
          sourceFile,
          uri,
          libDirectory,
        );
        if (localDependency != null) {
          pending.add(localDependency);
        }
      }
    }
  }

  return violations.toList()..sort();
}

bool _isProhibitedPresentationUri(String uri) =>
    uri == 'dart:ui' ||
    uri.startsWith('package:flutter/') ||
    uri.startsWith('package:flame/');

File? _resolveLocalDependency(
  File sourceFile,
  String uri,
  Directory libDirectory,
) {
  if (uri.startsWith('package:toy_racers/')) {
    final packagePath = uri.substring('package:toy_racers/'.length);
    return File('${libDirectory.path}${Platform.pathSeparator}$packagePath');
  }
  if (uri.startsWith('dart:') || uri.startsWith('package:')) {
    return null;
  }
  return File(Uri.file(sourceFile.path).resolve(uri).toFilePath());
}
