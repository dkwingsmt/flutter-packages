// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The style generator: reads the specs of a library directory and returns
/// every file it owns in the target package (generated parts and the engine
/// copy).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/emit_component.dart';
import 'src/emit_library.dart';
import 'src/model.dart';
import 'src/reader.dart';
import 'src/regions.dart';

export 'src/emit_library.dart' show emitFacade;
export 'src/model.dart';
export 'src/reader.dart' show SpecError, readSpecs;
export 'src/regions.dart' show Region, computeRegions, coverageGaps;

/// The files of one library: absolute path -> content. [engineDir] is the
/// engine directory of the target; every `.dart` file there that is not in
/// [files] is stale.
final class Generated {
  Generated(this.files, this.engineDir, this.warnings);

  final Map<String, String> files;
  final String engineDir;

  /// Spec findings that don't stop generation (full-coverage gaps).
  final List<String> warnings;
}

/// Generates everything for the library spec directory [specDir] of the
/// generator package at [packageRoot].
Future<Generated> generate(String specDir, {required String packageRoot}) async {
  final LibraryModel lib = await readSpecs(specDir);
  final String target = p.normalize(p.join(packageRoot, lib.target));
  String rel(String path) => p.relative(path, from: p.dirname(packageRoot));
  final Map<String, String> files = <String, String>{};
  files[p.join(target, lib.environmentOutput)] = emitEnvironment(lib, specRelative: rel(lib.specPath));
  files[p.join(target, lib.facadeOutput)] = emitFacade(lib, specRelative: rel(lib.specPath));
  for (final ComponentModel c in lib.components) {
    files[p.join(target, c.output)] = emitComponent(lib, c, specRelative: rel(c.specPath));
  }
  final String engineDir = p.join(target, lib.engineOutput);
  final Directory template = Directory(p.join(packageRoot, 'engine'));
  for (final FileSystemEntity e in template.listSync()..sort((a, b) => a.path.compareTo(b.path))) {
    if (e is File && e.path.endsWith('.dart')) {
      files[p.join(engineDir, p.basename(e.path))] = copiedEngineFile(e.readAsStringSync(), p.basename(e.path));
    }
  }
  return Generated(files, engineDir, <String>[for (final ComponentModel c in lib.components) ...coverageGaps(c)]);
}

/// An engine template file as copied into a target: a notice after the
/// license header.
String copiedEngineFile(String source, String name) {
  const String license = '// found in the LICENSE file.\n';
  final String notice = '\n// COPIED from packages/style_codegen/engine/$name by the generator. Do not\n'
      '// edit here: edit the template and run the generator.\n';
  final int i = source.indexOf(license);
  return i < 0 ? '${notice.substring(1)}\n$source' : source.replaceRange(i + license.length, i + license.length, notice);
}
