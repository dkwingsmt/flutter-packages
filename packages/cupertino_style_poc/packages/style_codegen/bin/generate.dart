// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Usage (in packages/style_codegen):
//   dart run style_codegen:generate            # write every library under specs/
//   dart run style_codegen:generate --check    # exit 1 when a file is stale
//   dart run style_codegen:generate specs/cupertino

import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:style_codegen/style_codegen.dart';

Future<void> main(List<String> args) async {
  final bool check = args.contains('--check');
  final Uri lib = (await Isolate.resolvePackageUri(Uri.parse('package:style_codegen/style_codegen.dart')))!;
  final String root = p.dirname(p.dirname(lib.toFilePath()));
  final List<String> dirs = <String>[
    for (final String a in args)
      if (!a.startsWith('--')) p.normalize(p.absolute(a)),
  ];
  if (dirs.isEmpty) {
    for (final FileSystemEntity e in Directory(p.join(root, 'specs')).listSync()..sort((a, b) => a.path.compareTo(b.path))) {
      if (e is Directory) {
        dirs.add(e.path);
      }
    }
  }
  final List<String> stale = <String>[];
  for (final String dir in dirs) {
    final Generated g;
    try {
      g = await generate(dir, packageRoot: root);
    } on SpecError catch (e) {
      stderr.writeln(e.message);
      exitCode = 2;
      return;
    }
    for (final String w in g.warnings) {
      stderr.writeln('warning: $w');
    }
    for (final MapEntry<String, String> f in g.files.entries) {
      final File file = File(f.key);
      final bool same = file.existsSync() && file.readAsStringSync() == f.value;
      if (same) {
        continue;
      }
      stale.add(p.relative(f.key));
      if (!check) {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(f.value);
      }
    }
    final Directory engine = Directory(g.engineDir);
    if (engine.existsSync()) {
      for (final FileSystemEntity e in engine.listSync()) {
        if (e is File && e.path.endsWith('.dart') && !g.files.containsKey(p.normalize(e.path))) {
          stale.add('${p.relative(e.path)} (not in the engine template)');
          if (!check) {
            e.deleteSync();
          }
        }
      }
    }
  }
  if (stale.isEmpty) {
    stdout.writeln('Up to date.');
  } else if (check) {
    stderr.writeln('Stale generated files (run `dart run style_codegen:generate`):');
    for (final String s in stale) {
      stderr.writeln('  $s');
    }
    exitCode = 1;
  } else {
    stdout.writeln('Wrote:');
    for (final String s in stale) {
      stdout.writeln('  $s');
    }
  }
}
