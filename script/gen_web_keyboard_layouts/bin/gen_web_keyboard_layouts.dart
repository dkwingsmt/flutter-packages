// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:gen_web_keyboard_layouts/main.dart';
import 'package:path/path.dart' as path;

const String kEnvGithubToken = 'GITHUB_TOKEN';

Future<void> main(List<String> rawArguments) async {
  bool enabledAssert = false;
  assert(() {
    enabledAssert = true;
    return true;
  }());
  if (!enabledAssert) {
    print('This script must be run with assert enabled. Please rerun with --enable-asserts.');
    exit(1);
  }

  final Map<String, String> env = Platform.environment;
  final String? envGithubToken = env[kEnvGithubToken];

  final ArgParser argParser = ArgParser();
  argParser.addOption(
    'github-token',
    defaultsTo: envGithubToken,
    mandatory: envGithubToken == null,
    hide: true,
    help: 'A GitHub personal access token for authentication. '
      r'Please set the environment variable $GITHUB_TOKEN '
      'instead of passing via CLI argument. '
      'This token is only used for quota controlling and does not need any '
      'scopes. Create one at '
      'https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token.',
  );
  argParser.addFlag(
    'allow-cache',
    defaultsTo: false,
    negatable: false,
    help: 'Use the cached result of the GitHub request if available. Suitable for development.',
  );
  argParser.addFlag(
    'help',
    negatable: false,
    help: 'Print help for this command.',
  );

  final ArgResults parsedArguments = argParser.parse(rawArguments);

  if (parsedArguments['help'] as bool) {
    print(argParser.usage);
    exit(0);
  }

  // The root of this package. The folder that is called
  // 'gen_web_keyboard_layouts' and contains 'pubspec.yaml'.
  final Directory packageRoot = Directory(path.dirname(Platform.script.toFilePath())).parent;

  await generate(Options(
    githubToken: parsedArguments['github-token'] as String,
    cacheRoot: path.join(packageRoot.path, '.cache'),
    dataRoot: path.join(packageRoot.path, 'data'),
    allowCache: parsedArguments['allow-cache'] as bool,
    outputRoot: path.join(packageRoot.parent.parent.path,
        'third_party', 'packages', 'web_keyboard_layouts', 'lib', 'src'),
  ));
}
