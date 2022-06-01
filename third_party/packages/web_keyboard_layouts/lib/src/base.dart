// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.

enum LayoutPlatform {
  win,
  linux,
  darwin,
}

class LayoutEntry {
  const LayoutEntry(
    this.value,
    this.withShift,
    this.withAltGr,
    this.withShiftAltGr, [
    this.mask = 0,
    this.vkey,
  ]);

  final String value;
  final String withShift;
  final String withAltGr;
  final String withShiftAltGr;
  final int mask;
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
