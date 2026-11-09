// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// COPIED from packages/style_codegen/engine/padding_scaler.dart by the generator. Do not
// edit here: edit the template and run the generator.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// How a component's padding follows the text scale: a style field next to
/// the base `padding` (the padding at a text scale of 1).
///
/// The component calls [apply] when it lays out, with the ambient
/// [TextScaler] and the font size the scale is measured on. The text scale
/// is `textScaler.scale(fontSize) / fontSize`, so a nonlinear scaler is
/// taken into account.
///
/// Both fields are plain data in a rule, so `null` keeps meaning "unset":
/// overriding `padding` keeps the scaler from the rules before, and
/// `paddingScaler: .identity()` turns the scaling off.
///
/// Material's buttons shrink the padding as the text grows
/// (`ButtonStyleButton.scaledPadding`), which is why this isn't a
/// [TextScaler]: a TextScaler is the ambient input, not a component policy.
///
/// Implementations must be immutable with value equality (rules compare
/// payloads to skip rebuilds).
@immutable
abstract class PaddingScaler {
  /// Abstract const constructor for subclasses.
  const PaddingScaler();

  /// The base padding at every text scale.
  const factory PaddingScaler.identity() = _IdentityPaddingScaler;

  /// The base padding times a factor per text scale: [factors] lists
  /// `(text scale, factor)` stops, linearly interpolated between the given
  /// scales and held beyond the first and last. Material 3's buttons are
  /// `.stops([(1, 1), (2, 0.5), (3, 0.25)])`.
  ///
  /// A list of records, not a map: a const map can't have double keys
  /// (double has no primitive equality).
  const factory PaddingScaler.stops(List<(double, double)> factors) = _StopsPaddingScaler;

  /// A fixed padding per text scale, for paddings that are not proportional
  /// to the base (Material 2's icon buttons). [paddings] lists
  /// `(text scale, padding)` stops; the base padding is the stop at 1
  /// unless 1 is given. Interpolated and held like [PaddingScaler.stops].
  const factory PaddingScaler.absolute(List<(double, EdgeInsetsGeometry)> paddings) = _AbsolutePaddingScaler;

  /// [padding] (the base) at the text scale of [textScaler] measured on
  /// [fontSize].
  EdgeInsetsGeometry apply(EdgeInsetsGeometry padding, TextScaler textScaler, double fontSize);

  /// The text scale [apply] uses.
  static double textScaleOf(TextScaler textScaler, double fontSize) => textScaler.scale(fontSize) / fontSize;
}

final class _IdentityPaddingScaler extends PaddingScaler {
  const _IdentityPaddingScaler();

  @override
  EdgeInsetsGeometry apply(EdgeInsetsGeometry padding, TextScaler textScaler, double fontSize) => padding;

  @override
  bool operator ==(Object other) => other is _IdentityPaddingScaler;

  @override
  int get hashCode => (_IdentityPaddingScaler).hashCode;

  @override
  String toString() => 'PaddingScaler.identity()';
}

/// Piecewise-linear lookup over stops (any order), held beyond the ends.
T _interpolate<T>(List<(double, T)> stops, double x, T Function(T a, T b, double t) lerp) {
  assert(stops.isNotEmpty, 'PaddingScaler: give at least one stop');
  final List<(double, T)> sorted = List<(double, T)>.of(stops)..sort(((double, T) a, (double, T) b) => a.$1.compareTo(b.$1));
  if (x <= sorted.first.$1) {
    return sorted.first.$2;
  }
  for (var i = 1; i < sorted.length; i++) {
    final (double b, T vb) = sorted[i];
    if (x < b) {
      final (double a, T va) = sorted[i - 1];
      return lerp(va, vb, (x - a) / (b - a));
    }
  }
  return sorted.last.$2;
}

final class _StopsPaddingScaler extends PaddingScaler {
  // No const assert on emptiness: a const constructor can't read a list's
  // length. Checked when applied.
  const _StopsPaddingScaler(this.factors);

  final List<(double, double)> factors;

  @override
  EdgeInsetsGeometry apply(EdgeInsetsGeometry padding, TextScaler textScaler, double fontSize) {
    final double f = _interpolate<double>(
        factors, PaddingScaler.textScaleOf(textScaler, fontSize), (double a, double b, double t) => a + (b - a) * t);
    return f == 1.0 ? padding : padding * f;
  }

  @override
  bool operator ==(Object other) => other is _StopsPaddingScaler && listEquals(other.factors, factors);

  @override
  int get hashCode => Object.hashAll(factors);

  @override
  String toString() => 'PaddingScaler.stops($factors)';
}

final class _AbsolutePaddingScaler extends PaddingScaler {
  const _AbsolutePaddingScaler(this.paddings);

  final List<(double, EdgeInsetsGeometry)> paddings;

  @override
  EdgeInsetsGeometry apply(EdgeInsetsGeometry padding, TextScaler textScaler, double fontSize) {
    final List<(double, EdgeInsetsGeometry)> stops = paddings.any(((double, EdgeInsetsGeometry) e) => e.$1 == 1.0)
        ? paddings
        : <(double, EdgeInsetsGeometry)>[(1.0, padding), ...paddings];
    return _interpolate<EdgeInsetsGeometry>(stops, PaddingScaler.textScaleOf(textScaler, fontSize),
        (EdgeInsetsGeometry a, EdgeInsetsGeometry b, double t) => EdgeInsetsGeometry.lerp(a, b, t)!);
  }

  @override
  bool operator ==(Object other) => other is _AbsolutePaddingScaler && listEquals(other.paddings, paddings);

  @override
  int get hashCode => Object.hashAll(paddings);

  @override
  String toString() => 'PaddingScaler.absolute($paddings)';
}
