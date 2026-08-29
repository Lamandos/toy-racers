import 'dart:io';

import 'package:toy_racers/simulation.dart';

import 'behavior_runner.dart';

/// A materialized scenario and the trace file written for that scenario.
final class DifferentialFuzzTraceRequest {
  const DifferentialFuzzTraceRequest({
    required this.scenario,
    required this.output,
  });

  final File scenario;
  final File output;
}

/// Runs every requested differential fuzz scenario in one Dart VM process.
int executeDifferentialFuzzRunner(List<String> arguments, {IOSink? errorSink}) {
  try {
    for (final request in _parseRequests(arguments)) {
      final trace = BehaviorRunner().run(request.scenario);
      request.output.parent.createSync(recursive: true);
      request.output.writeAsStringSync(CompatibilityTraceJson.encode(trace));
    }
    return 0;
  } on Object catch (error) {
    errorSink?.writeln('Differential fuzz Dart runner failed: $error');
    return 1;
  }
}

List<DifferentialFuzzTraceRequest> _parseRequests(List<String> arguments) {
  if (arguments.isEmpty || arguments.length.isOdd) {
    throw ArgumentError(_usage);
  }
  final requests = <DifferentialFuzzTraceRequest>[];
  for (var index = 0; index < arguments.length; index += 4) {
    if (arguments.length <= index + 3 ||
        arguments[index] != _scenarioOption ||
        arguments[index + 2] != _outputOption) {
      throw ArgumentError(_usage);
    }
    requests.add(
      DifferentialFuzzTraceRequest(
        scenario: File(arguments[index + 1]),
        output: File(arguments[index + 3]),
      ),
    );
  }
  return requests;
}

void main(List<String> arguments) {
  final status = executeDifferentialFuzzRunner(arguments, errorSink: stderr);
  if (status != 0) {
    exitCode = status;
  }
}

const String _scenarioOption = '--scenario';
const String _outputOption = '--output';
const String _usage =
    'Usage: differential_fuzz_runner.dart --scenario <path> --output <path> [...]';
