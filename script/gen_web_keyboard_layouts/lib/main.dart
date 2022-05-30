// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class Options {
  /// Build an option.
  const Options({
    required this.allowCache,
    required this.githubToken,
    required this.cacheRoot,
    required this.dataRoot,
    required this.outputRoot,
  });

  final bool allowCache;

  /// The GitHub personal access token used to make the GitHub request.
  final String githubToken;

  /// The path of the folder that store cache.
  final String cacheRoot;

  /// The path of the folder that store data files, such as templates.
  final String dataRoot;

  /// The folder to store the output Dart files.
  final String outputRoot;
}

const String githubCacheFileName = 'github-response.json';

const String githubQuery = r'''
{
  repository(owner: "microsoft", name: "vscode") {
    defaultBranchRef {
       target {
        ... on Commit {
          history(first: 1) {
            nodes {
              file(path: "src/vs/workbench/services/keybinding/browser/keyboardLayouts") {
                extension lineCount object {
                  ... on Tree {
                    entries {
                      name object {
                        ... on Blob {
                          text
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';

/// Signature for function that asynchonously returns a value.
typedef AsyncGetter<T> = Future<T> Function();

Future<String> tryCached(bool allowReadingCache, String cachePath, AsyncGetter<String> ifNotExist) async {
  final File cacheFile = File(cachePath);
  if (allowReadingCache && cacheFile.existsSync()) {
    try {
      final String result = cacheFile.readAsStringSync();
      print('Using GitHub cache.');
      return result;
    } catch (exception) {
      print('Error reading GitHub cache, rebuilding. Details: $exception');
    }
  }
  final String result = await ifNotExist();
  IOSink? sink;
  try {
    print('Requesting from GitHub...');
    Directory(path.dirname(cachePath)).createSync(recursive: true);
    sink = cacheFile.openWrite();
    cacheFile.writeAsStringSync(result);
  } catch (exception) {
    print('Error writing GitHub cache. Details: $exception');
  } finally {
    sink?.close();
  }
  return result;
}

Future<Map<String, dynamic>> fetchGithub(String githubToken, bool allowCache, String cachePath) async {
  final String response = await tryCached(allowCache, cachePath, () async {
    final String condensedQuery = githubQuery
        .replaceAll(RegExp(r'\{ +'), '{')
        .replaceAll(RegExp(r' +\}'), '}');
    final http.Response response = await http.post(
      Uri.parse('https://api.github.com/graphql'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'bearer $githubToken',
      },
      body: jsonEncode(<String, String>{
        'query': condensedQuery,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Request to GitHub failed with status code ${response.statusCode}: ${response.reasonPhrase}');
    }
    return response.body;
  });
  return jsonDecode(response) as Map<String, dynamic>;
}

Future<void> generate(Options options) async {
  final Map<String, dynamic> githubBody = await fetchGithub(
    options.githubToken,
    options.allowCache,
    path.join(options.cacheRoot, githubCacheFileName),
  );
  print('Done');
}
