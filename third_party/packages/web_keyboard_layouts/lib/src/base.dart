// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.

enum LayoutPlatform {
  win,
  linux,
  darwin,
}

class LayoutEntry {
  const LayoutEntry(
    this.values,
    this.vkey,
  );

  // List of four: value, withShift, withAlt, withShiftAlt.
  // Each value is either 0xYYYYYY, or 0x1000000 for a dead key.
  final List<int> values;
  final String? vkey;
}

class LayoutInfo {
  const LayoutInfo({
    required this.name,
    required this.platform,
    required this.mapping,
  });

  final String name;
  final LayoutPlatform platform;
  final Map<String, LayoutEntry> mapping;
}
