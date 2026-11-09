// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Compile-time type safety of the derive API, checked with the analyzer:
// every snippet under test/fixtures/type_errors/ must fail on each line
// marked `// error` and nowhere else, and the correctly typed control
// (test/fixtures/type_ok.dart) must analyze without issues. The fixtures
// are excluded from `flutter analyze` (analysis_options.yaml); given as
// explicit paths, the analyzer still checks them.
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One analyzer diagnostic in `--format=machine` form.
typedef Diagnostic = ({String severity, String code, String file, int line, String message});

String _dart() {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final String dart = '$root/bin/dart';
    if (File(dart).existsSync()) {
      return dart;
    }
  }
  return 'dart';
}

List<Diagnostic> _analyze(List<String> paths) {
  final ProcessResult r = Process.runSync(_dart(), <String>['analyze', '--format=machine', ...paths]);
  final String out = '${r.stdout}\n${r.stderr}';
  return <Diagnostic>[
    for (final String line in out.split('\n'))
      if (line.split('|') case [final String severity, _, final String code, final String file, final String l, _, _, final String message, ...])
        (severity: severity, code: code, file: file, line: int.parse(l), message: message),
  ];
}

void main() {
  final List<File> negative = Directory('test/fixtures/type_errors')
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  const String control = 'test/fixtures/type_ok.dart';
  late final List<Diagnostic> all = _analyze(<String>[control, for (final File f in negative) f.path]);

  test('covers the planned cases', () {
    expect(negative.map((File f) => f.uri.pathSegments.last).toSet(), containsAll(<String>[
      'opacity_on_non_color_slot.dart',
      'color_field_in_edge_insets_slot.dart',
      'wrong_type_in_parts.dart',
      'empty_parts.dart',
      'wrong_token_type.dart',
      'wrong_custom_token_type.dart',
      'wrong_token_value.dart',
      'wrong_callback_return_type.dart',
      'value_of_wrong_type.dart',
      'field_of_another_component.dart',
    ]));
  });

  test('the correctly typed control has no diagnostics', () {
    expect(all.where((Diagnostic d) => d.file.endsWith('type_ok.dart')), isEmpty);
  });

  test('an empty .parts() fails its assert during const evaluation', () {
    final List<Diagnostic> mine = all.where((Diagnostic d) => d.file.endsWith('/empty_parts.dart')).toList();
    expect(mine, isNotEmpty);
    expect(mine.map((Diagnostic d) => d.code).toSet(), <String>{'CONST_EVAL_THROWS_EXCEPTION'});
  });

  for (final File f in negative) {
    final String name = f.uri.pathSegments.last;
    test('$name: an error on every marked line and nowhere else', () {
      final List<String> lines = f.readAsLinesSync();
      final Set<int> marked = <int>{
        for (int i = 0; i < lines.length; i++)
          if (lines[i].trimRight().endsWith('// error')) i + 1,
      };
      expect(marked, isNotEmpty);
      final List<Diagnostic> mine = all.where((Diagnostic d) => d.file.endsWith('/$name')).toList();
      final Set<int> errorLines = <int>{
        for (final Diagnostic d in mine)
          if (d.severity == 'ERROR') d.line,
      };
      expect(errorLines, marked, reason: mine.map((Diagnostic d) => '${d.line}: ${d.code} ${d.message}').join('\n'));
      expect(mine.where((Diagnostic d) => d.severity != 'ERROR'), isEmpty, reason: 'no warnings besides the errors');
    });
  }
}
