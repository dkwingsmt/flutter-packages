// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Output helpers shared by the emitters.
library;

String lowerFirst(String s) => s.isEmpty ? s : '${s[0].toLowerCase()}${s.substring(1)}';

String upperFirst(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// Greedy word wrap of [text] to [width] columns; continuation lines start
/// with [indent].
String wrapDoc(String text, int width, String indent) {
  final List<String> lines = <String>[];
  String current = '';
  for (final String w in text.split(' ')) {
    if (current.isNotEmpty && current.length + 1 + w.length > width) {
      lines.add(current);
      current = w;
    } else {
      current = current.isEmpty ? w : '$current $w';
    }
  }
  lines.add(current);
  return lines.join('\n$indent');
}

/// The private declarations of [copied] that [texts] reference, directly or
/// through each other, in their order in [copied].
List<String> copiedHelpers(Map<String, String> copied, List<String> texts) {
  final Set<String> used = <String>{};
  final List<String> pending = <String>[...texts];
  while (pending.isNotEmpty) {
    final String t = pending.removeLast();
    for (final MapEntry<String, String> e in copied.entries) {
      if (!used.contains(e.key) && RegExp('(?<![A-Za-z0-9_\$])${RegExp.escape(e.key)}(?![A-Za-z0-9_\$])').hasMatch(t)) {
        used.add(e.key);
        pending.add(e.value);
      }
    }
  }
  final Set<String> seen = <String>{};
  return <String>[
    for (final MapEntry<String, String> e in copied.entries)
      if (used.contains(e.key) && seen.add(e.value)) e.value,
  ];
}

/// A generated Dart file.
final class Out {
  final StringBuffer _b = StringBuffer();

  void line(String s) => _b.writeln(s);

  void blank() => _b.writeln();

  /// Verbatim source (may be several lines).
  void raw(String s) => _b.writeln(s);

  void doc(String text, {int indent = 0}) {
    final String pad = ' ' * indent;
    for (final String l in text.split('\n')) {
      _b.writeln(l.isEmpty ? '$pad///' : '$pad/// $l');
    }
  }

  void comment(String text) {
    for (final String l in text.split('\n')) {
      _b.writeln(l.isEmpty ? '//' : '// $l');
    }
  }

  void section(String title) {
    final String head = '// ---- $title ';
    _b.writeln('$head${'-' * (78 - head.length).clamp(4, 78)}');
    _b.writeln();
  }

  /// License, generated-file notice, ignores and `part of`.
  void header(String spec, {String? partOf, List<String> ignores = const <String>[]}) {
    _b.writeln('// Copyright 2013 The Flutter Authors');
    _b.writeln('// Use of this source code is governed by a BSD-style license that can be');
    _b.writeln('// found in the LICENSE file.');
    _b.writeln();
    _b.writeln('// GENERATED FILE. Do not edit: change the spec and run the generator.');
    _b.writeln('//   spec:      $spec');
    _b.writeln('//   generator: packages/style_codegen (dart run style_codegen:generate)');
    if (ignores.isNotEmpty) {
      _b.writeln('// ignore_for_file: ${ignores.join(', ')}');
    }
    if (partOf != null) {
      _b.writeln("part of '$partOf';");
    }
    _b.writeln();
  }

  @override
  String toString() => _b.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trimRight() + '\n';
}
