// Runs `dart analyze` on example/ (which loads this plugin from path) and
// checks that every rule reports exactly on the lines marked with an
// `// expect_lint: <rule>` comment, and nowhere else.
//
//   dart run tool/check_example.dart

import 'dart:io';

const _rules = {
  'fixed_height_around_text',
  'separately_scaled_square',
  'tap_height_with_h',
  'screenutil_import',
};

Future<void> main() async {
  final example = Directory('example').absolute.path;

  final expected = <String>{};
  final marker = RegExp(r'//\s*expect_lint:\s*(\w+)');
  for (final entity in Directory('$example/lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final match = marker.firstMatch(lines[i]);
      if (match != null) expected.add('${entity.path}:${i + 2} ${match[1]}');
    }
  }

  final result = await Process.run('dart', [
    'analyze',
    '--format=machine',
    '.',
  ], workingDirectory: example);
  final actual = <String>{};
  for (final line in '${result.stdout}\n${result.stderr}'.split('\n')) {
    final parts = line.split('|');
    if (parts.length < 8) continue;
    final rule = parts[2].toLowerCase();
    if (parts[0] == 'ERROR') {
      stderr.writeln('Analysis error: $line');
      exitCode = 1;
    }
    if (_rules.contains(rule)) actual.add('${parts[3]}:${parts[4]} $rule');
  }

  final missing = expected.difference(actual);
  final extra = actual.difference(expected);
  for (final m in missing) {
    stderr.writeln('Expected but not reported: $m');
  }
  for (final e in extra) {
    stderr.writeln('Reported but not expected: $e');
  }
  if (missing.isNotEmpty || extra.isNotEmpty || actual.isEmpty) {
    exitCode = 1;
  } else {
    stdout.writeln(
      'All ${actual.length} expected diagnostics reported, '
      'nothing else.',
    );
  }
}
