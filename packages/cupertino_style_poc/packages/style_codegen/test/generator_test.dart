// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:style_codegen/style_codegen.dart';
import 'package:test/test.dart';

void main() {
  final String root = Directory.current.path;
  final String specs = p.join(root, 'specs', 'cupertino');

  test('the committed files are what the specs generate', () async {
    final Generated g = await generate(specs, packageRoot: root);
    for (final MapEntry<String, String> f in g.files.entries) {
      expect(File(f.key).readAsStringSync(), f.value, reason: '${p.relative(f.key)} is stale: run `dart run style_codegen:generate`');
    }
  });

  test('regions come from the structure of the defaults', () async {
    final LibraryModel lib = await readSpecs(specs);
    final ComponentModel button = lib.components.firstWhere((ComponentModel c) => c.name == 'Button');
    final Map<String, List<Region>> r = computeRegions(button);
    expect(<String>[for (final Region x in r['backgroundColor']!) x.name],
        <String>['plainAnyState', 'tintedEnabled', 'tintedDisabled', 'filledEnabled', 'filledDisabled']);
    expect(<String>[for (final Region x in r['mouseCursor']!) x.name], <String>['enabled', 'disabled']);
    expect(<String>[for (final Region x in r['padding']!) x.name], <String>['anyState'],
        reason: 'three size rules with one label are one region');
    final ComponentModel sw = lib.components.firstWhere((ComponentModel c) => c.name == 'Switch');
    expect(<String>[for (final Region x in computeRegions(sw)['trackColor']!) x.name], <String>['unselected', 'selected']);
  });

  test('the full-coverage check lists fields the defaults leave unset', () async {
    final LibraryModel lib = await readSpecs(specs);
    final List<String> gaps = <String>[for (final ComponentModel c in lib.components) ...coverageGaps(c)];
    expect(gaps.map((String g) => g.split(':').first),
        containsAll(<String>['Button.backgroundColor', 'Button.side', 'Switch.thumbImage', 'Switch.thumbIcon']));
  });

  test('the token facade follows the design doc shape', () async {
    final LibraryModel lib = await readSpecs(specs);
    final String f = emitFacade(lib, specRelative: 'specs/cupertino/cupertino.dart');
    expect(f, contains('abstract interface class CupertinoToken<T extends Object> implements Token<T> {'));
    expect(f, contains('enum _CupertinoTokens<T extends Object> with GroupTokenMixin<T> implements CupertinoToken<T> {'));
    expect(f, contains('final T? Function(T? a, T? b, double t)? lerp;'));
    expect(f, contains("const TokenGroup cupertinoTokenGroup = TokenGroup('Cupertino', _CupertinoTokens.values);"));
    expect(f, contains('final class CupertinoTokenRule extends TokenSourceRule {'));
    expect(f, contains('const CupertinoTokenRule.derive({'));
    expect(f, contains('CupertinoTokenColorSource? primaryColor,'));
    expect(f, contains('CupertinoTokenSource<TextStyle>? textStyle,'));
    expect(f, isNot(contains('GroupToken<')), reason: 'no data-class group token');
    expect(f, isNot(contains('TokenRule.group')));
  });
}
