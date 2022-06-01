// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart' show immutable;


@immutable
class JsonContext<T> {
  JsonContext(this.current, this.path);

  final T current;
  final List<String> path;

  static JsonContext<Map<String, dynamic>> root(Map<String, dynamic> root) {
    return JsonContext<Map<String, dynamic>>(root, const <String>[]);
  }
}

typedef JsonObject = Map<String, dynamic>;
typedef JsonArray = List<dynamic>;
String _jsonTypeErrorMessage(List<String> currentPath, String nextKey, Type expectedType, Type actualType) {
  return 'Unexpected value at path ${currentPath.join('.')}.$nextKey: '
      'Expects $expectedType but got $actualType.';
}

JsonContext<T> jsonGetKey<T>(JsonContext<JsonObject> context, String key) {
  dynamic result = context.current[key];
  if (result is! T) {
    throw ArgumentError(_jsonTypeErrorMessage(context.path, key, T, result.runtimeType));
  }
  return JsonContext<T>(result, <String>[...context.path, key]);
}

JsonContext<T> jsonGetIndex<T>(JsonContext<JsonArray> context, int index) {
  dynamic result = context.current[index];
  if (result is! T) {
    throw ArgumentError(_jsonTypeErrorMessage(context.path, '$index', T, result.runtimeType));
  }
  return JsonContext<T>(result, <String>[...context.path, '$index']);
}

JsonContext<T> jsonGetPath<T>(JsonContext<dynamic> context, List<dynamic> path) {
  JsonContext<dynamic> current = context;
  void _jsonGetKeyOrIndex<M>(dynamic key, int depth) {
    assert(key is String || key is int, 'Key at $depth is a ${key.runtimeType}.');
    if (key is String) {
      current = jsonGetKey<M>(current as JsonContext<JsonObject>, key);
    } else if (key is int) {
      current = jsonGetIndex<M>(current as JsonContext<JsonArray>, key);
    } else {
      assert(false);
    }
  }
  void _jsonGetKeyOrIndexForNext(dynamic key, dynamic nextKey, int depth) {
    assert(nextKey is String || nextKey is int, 'Key at ${depth + 1} is a ${key.runtimeType}.');
    if (nextKey is String) {
      _jsonGetKeyOrIndex<JsonObject>(key, depth);
    } else if (nextKey is int) {
      _jsonGetKeyOrIndex<JsonArray>(key, depth);
    } else {
      assert(false);
    }
  }

  for (int depth = 0; depth < path.length; depth += 1) {
    if (depth != path.length - 1) {
      _jsonGetKeyOrIndexForNext(path[depth], path[depth + 1], depth);
    } else {
      _jsonGetKeyOrIndex<T>(path[depth], depth);
    }
  }
  return current as JsonContext<T>;
}

List<dynamic> jsonPathSplit(String path) {
  return path.split('.').map((String key) {
    final int? index = int.tryParse(key);
    if (index != null) {
      return index;
    } else {
      return key;
    }
  }).toList();
}
