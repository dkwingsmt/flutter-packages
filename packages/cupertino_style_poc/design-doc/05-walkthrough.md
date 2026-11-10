# 5. End-to-End Code Walkthrough (Before vs. After)

[← Previous: 4. Core Design Derivation](04-core-derivation.md) | [Back to Index](00-intro.md) | [Next: 6. Detailed Mechanics and Code Generation →](06-design-details-and-codegen.md)

---

This section walks through five representative scenarios: call-site flat parameters paired with `rules:`, global themes and local `StyleScope` overrides (including region constructors), cross-field derivations and custom `TokenGroup`s, composite component slots, and shared rules across Material's multiple button widgets.

Note: Scenarios 1 through 4 use the new `Button` component in `cupertino_ui` (with generated class names `ButtonStyle`, `ButtonRule`, and `ButtonWhen`). The code in Scenarios 1 through 3 matches the actual API implemented in the sibling prototype repository; `DatePicker` in Scenario 4 and the Material buttons in Scenario 5 have not been merged into that prototype yet and illustrate the target API design.

---

## Scenario 1: Component Call Site — Flat Parameters and Single-Instance State Tweaks

**Requirement**: Create a `filled` button with a system red background and a light grey disabled background. When `pressed`, change its foreground color to bright yellow and make the text bold.

### Before

Legacy `CupertinoButton` only offers flat parameters like `color` and `disabledColor`. It cannot change foreground color or text style by state, forcing you to wrap it in a custom `StatefulWidget` that listens to gestures. Even with Material's `FilledButton` and the declarative `WidgetStateProperty.fromMap`, you still have to fall back to `ButtonStyle` and wrap each property in its own map. Not only do you repeat the `WidgetState.pressed` condition across multiple properties, you also have to carefully place `WidgetState.disabled` before `WidgetState.any` when configuring `backgroundColor` (if you only write `{WidgetState.any: Colors.red}` or flip the order, the red color overwrites the disabled state):

```dart
FilledButton(
  style: const ButtonStyle(
    backgroundColor: WidgetStateProperty<Color?>.fromMap(<WidgetStatesConstraint, Color?>{
      WidgetState.disabled: Color(0xFFE0E0E0), // Must come before any, or disabled state gets overwritten
      WidgetState.any: Colors.red,
    }),
    foregroundColor: WidgetStateProperty<Color?>.fromMap(<WidgetStatesConstraint, Color?>{
      WidgetState.pressed: Colors.yellow,
    }),
    textStyle: WidgetStateProperty<TextStyle?>.fromMap(<WidgetStatesConstraint, TextStyle?>{
      WidgetState.pressed: TextStyle(fontWeight: FontWeight.bold),
    }),
  ),
  onPressed: save,
  child: const Text('Save'),
)
```

### After

Pass maintainer-curated flat parameters (`color` and `disabledColor`) directly for common properties. Internally, the component maps them to their corresponding state regions via generated region constructors, so passing `color` alone never clobbers the default disabled state. To append a multi-property tweak when pressed on this specific instance, add a single `.when(pressed: true, ...)` rule in `rules:`:

```dart
Button(
  appearance: ButtonAppearance.filled,
  color: CupertinoColors.systemRed,
  disabledColor: CupertinoColors.systemGrey4,
  rules: const [
    .when(
      pressed: true,
      style: .values(
        foregroundColor: CupertinoColors.systemYellow,
        textStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  ],
  onPressed: save,
  child: const Text('Save'),
)
```

---

## Scenario 2: Global Theme and Local Overrides — Region Constructors, Multi-Dimensional Conditions, and Per-Channel Isolation

**Requirements**:
1. In the global theme, set the enabled background of `tinted` buttons to teal (keeping the default disabled state), set the border radius of all non-disabled buttons to `12`, and set the foreground color to gold when pressed in dark mode; at the same time, set the selected track color of all `Switch` widgets to teal.
2. Inside the `CheckoutPanel` subtree, change only the enabled background of `filled` buttons to orange while keeping all other global settings intact.

### Problems with the Old Approach

- `cupertino_ui` has no component-level themes for buttons or switches; you have to build custom wrapper widgets.
- In Material, buttons with different appearances require separate configurations across `filledButtonTheme` and `textButtonTheme`. Worse, combinations of interaction states and environment dimensions like "dark mode + pressed" cannot be expressed with `WidgetStateProperty.fromMap` (because `WidgetState` does not include brightness or component appearance dimensions), forcing you back to a `resolveWith` closure that reads both `Theme.of(context).brightness` and `states` inside the callback.
- Wrapping `CheckoutPanel` in a local `FilledButtonTheme` not only wipes out any fields not copied onto the new `FilledButtonThemeData`, it also **atomically replaces** the outer `WidgetStateMap` with the inner `WidgetStateMap` even when both sides use `WidgetStateProperty.fromMap` on the same field (two `fromMap` instances do not merge their individual state entries).

### After

Both global `StyleTheme` and local `StyleScope` accept the same list of rules. Use region constructors (`ButtonRule.backgroundColor(tintedEnabled: ...)`, `SwitchRule.trackColor(selected: ...)`) when changing literal values for a single field within default state regions, and use `.when(...)` for multi-field rules or cross-dimension combinations:

```dart
StyleTheme(
  rules: const [
    ...<ButtonRule>[
      // Region constructor: only change the tinted enabled background; default disabled state stays intact
      .backgroundColor(tintedEnabled: CupertinoColors.systemTeal),
      // Change border radius across all non-disabled buttons
      .when(disabled: false, style: .values(borderRadius: 12)),
      // Declare interaction state and environment dimension in the same condition
      .when(pressed: true, brightness: .dark, style: .values(foregroundColor: Color(0xFFFFD60A))),
    ],
    ...<SwitchRule>[
      .trackColor(selected: CupertinoColors.systemTeal),
    ],
  ],
  child: CupertinoApp(
    home: StyleScope(
      // Appended after outer rules: only change the filled enabled background;
      // outer border radius, dark-pressed gold, and tinted teal all remain intact automatically.
      // Because this Scope only touches the button channel, Switches in the subtree do not rebuild.
      rules: const [
        ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
      ],
      child: const CheckoutPanel(),
    ),
  ),
)
```

---

## Scenario 3: Cross-Field Derivations and Custom `TokenGroup`s (Replacing `ThemeExtension`)

**Requirements**:
1. The app defines a set of custom brand and layout tokens (brand color `accent`, success color `success`, primary text color `textPrimary`, secondary text color `textMuted` that is always 60% opacity of `textPrimary`, corner radius `radius`, and a nested custom semantic color group `info<SemanticGroup>`), configures preset rules for light, dark, and high-contrast modes, reads non-null values directly in ordinary widgets, and overrides `accent` and `textPrimary` locally in a promotional subtree.
2. The theme declares that enabled `tinted` buttons take `MyBrand.accent` for their foreground color, 15% opacity of `MyBrand.accent` for their background color, a corner radius computed from `MyBrand.radius`, and an icon color that always follows the button's final resolved foreground color.

### Before (Existing `ThemeExtension` + Component Theme)

```dart
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  BrandColors({
    required this.accent,
    required this.success,
    required this.textPrimary,
    Color? textMuted,
    required this.radius,
  }) : textMuted = textMuted ?? textPrimary.withValues(alpha: 0.6);

  final Color accent;
  final Color success;
  final Color textPrimary;
  final Color textMuted;
  final double radius;

  @override
  BrandColors copyWith({Color? accent, Color? success, Color? textPrimary, Color? textMuted, double? radius}) =>
      BrandColors(
        accent: accent ?? this.accent,
        success: success ?? this.success,
        textPrimary: textPrimary ?? this.textPrimary,
        // Trap: if you only call copyWith(textPrimary: brown), this.textMuted is non-null and keeps 60% of the old textPrimary!
        textMuted: textMuted ?? this.textMuted,
        radius: radius ?? this.radius,
      );

  @override
  BrandColors lerp(covariant BrandColors? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      radius: lerpDouble(radius, other.radius, t)!,
    );
  }
}

// Component themes cannot declaratively reference extensions; you have to copy values in by hand when constructing ThemeData
ThemeData buildTheme(BrandColors brand) => ThemeData(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.accent,
          iconColor: brand.accent, // Hard-coded to brand.accent; icon color will not follow if a call site overrides foregroundColor
          backgroundColor: brand.accent.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(brand.radius)),
        ),
      ),
      extensions: [brand],
    );
```

### Problems with the Old Approach

- **Heavy boilerplate, and component themes cannot declaratively bind to `ThemeExtension`s or sibling fields**: Hand-writing a `ThemeExtension` takes an average of ~12.8 lines of `copyWith` / `lerp` boilerplate per field. Component themes cannot reference `BrandColors` fields directly (so overriding `BrandColors` locally does not update buttons), nor can they declare that "icon color always follows the button's final resolved `foregroundColor`" (if a call site passes a white `foregroundColor`, the hard-coded `iconColor` in the theme falls out of sync with the text color).
- **Derived values inside extensions silently go stale after `copyWith`, and `copyWith(extensions:)` replaces the entire map**: Because `textMuted` is precomputed in the constructor, calling `copyWith(textPrimary: brown)` sees a non-null `this.textMuted` and never recomputes it. Furthermore, calling `ThemeData.copyWith(extensions: ...)` in a subtree replaces the entire extension map, dropping any other extensions that are not explicitly passed again.

### After

Define the token enum `MyBrand` (with a built-in `of(context)` read entry point and static `MyBrand.group` constant) along with the write-side rule class `MyBrandRule`:

```dart
// 1. Token enum: standard types use the built-in interpolation table automatically; nested custom classes pass their static lerp function
enum MyBrand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  success<Color>(),
  textPrimary<Color>(),
  textMuted<Color>(),
  radius<double>(),
  info<SemanticGroup>(lerp: SemanticGroup.lerp);

  const MyBrand({this.lerp});
  @override
  final T? Function(T? a, T? b, double t)? lerp;

  static const TokenGroup group = TokenGroup('MyBrand', values);
}

// 2. Write-side rule class (value-only TokenValueRule): each token only needs one nullable constructor parameter and one map entry
final class const MyBrandRule({
  super.when,
  final Color? accent,
  final Color? success,
  final Color? textPrimary,
  final Color? textMuted,
  final double? radius,
  final SemanticGroup? info,
}) extends TokenValueRule {
  @override
  Map<Token<Object>, Object> get values => {
        MyBrand.accent: ?accent,
        MyBrand.success: ?success,
        MyBrand.textPrimary: ?textPrimary,
        MyBrand.textMuted: ?textMuted,
        MyBrand.radius: ?radius,
        MyBrand.info: ?info,
      };

  static const List<Rule> teal = [
    MyBrandRule(accent: teal700, success: green700, textPrimary: ink, radius: 12, info: infoLight),
    MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, success: green300, textPrimary: paper, info: infoDark),
    MyBrandRule(when: TokenWhen(highContrast: true), accent: teal900, textPrimary: black),
  ];
}

BorderRadius brandRadius(ButtonView s) => BorderRadius.circular(s.customToken(MyBrand.radius));
```

Next, register `MyBrand.group` in `StyleTheme`, spread the presets and default derivation rules, and reference them in button rules (use `.fromCustomToken(...)` / `s.customToken(...)` for custom app tokens and `.fromToken(...)` for built-in library tokens):

```dart
StyleTheme(
  groups: [MyBrand.group],
  rules: [
    ...MyBrandRule.teal,
    // Cross-token derivation: textMuted always takes 60% opacity of the currently resolved textPrimary (automatically recomputed in dark mode or local overrides)
    MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6)),
    ...const <ButtonRule>[
      .when(appearance: {.tinted}, disabled: false, style: .derive(
        foregroundColor: .fromCustomToken(MyBrand.accent),
        backgroundColor: .opacity(.fromCustomToken(MyBrand.accent), 0.15),
        borderRadius: .computed(brandRadius),
        // Icon color follows the button's final resolved foreground color
        iconTheme: .parts(color: .fromField(.foregroundColor)),
      )),
    ],
  ],
  child: Builder(builder: (BuildContext context) {
    // Read outside components: the mixin provides .of(context) directly, returning a non-null value
    final Color ok = MyBrand.success.of(context);
    return Column(children: [
      Text('Paid', style: TextStyle(color: ok)),
      // Call site only passes foregroundColor; because derivations evaluate after the entire rule chain merges,
      // this button's icon color automatically becomes white as well.
      Button.tinted(
        foregroundColor: CupertinoColors.white,
        onPressed: () {},
        child: const Text('White text, white icon'),
      ),
      // Local override in promotional section: only change accent and textPrimary, keeping all other tokens and extension groups intact;
      // button foreground and background in the subtree automatically turn orange, and textMuted recomputes to brown × 0.6.
      StyleScope(
        rules: const [MyBrandRule(accent: CupertinoColors.systemOrange, textPrimary: brown)],
        child: Button.tinted(onPressed: () {}, child: const Text('Scoped orange')),
      ),
    ]);
  }),
)
```

Note: If a token group has many cross-token derivations, `MyBrandRule` can instead extend `TokenSourceRule` (whose parameters accept `TokenColorSource?` / `TokenSource<T>?`), allowing both default derivations and literal presets to be written uniformly as `const MyBrandRule(...)` (see [Section 4, Step 4](04-core-derivation.md) and [Section 6.2](06-design-details-and-codegen.md)).

---

## Scenario 4: Sub-Component Slots on Composite Components

**Requirement**: Customize the background color and corner radius of the bottom confirm button across all `DatePicker`s without affecting the cancel button or other ordinary buttons on the page.

### Problems with the Old Approach

Legacy `CupertinoDatePicker` offers no sub-widget styling at all. In Material, `DatePickerThemeData` provides `confirmButtonStyle: ButtonStyle?`, but it takes a single flat `ButtonStyle` object—you cannot use region constructors for safe per-state tweaks, and if a local `DatePickerTheme` specifies `confirmButtonStyle` again, the inner `ButtonStyle` fields overwrite the outer `WidgetStateProperty` on the same fields instead of stacking by condition.

### After

The parent component's style class exposes a strongly typed slot field `confirmButton: List<ButtonRule>?`, and the parent component applies that rule list to the confirm button subtree via a local `StyleScope`:

```dart
StyleTheme(
  rules: const [
    DatePickerRule.always(style: .values(
      confirmButton: [
        .backgroundColor(filledEnabled: CupertinoColors.systemGreen),
        .when(disabled: false, style: .values(borderRadius: 8)),
      ],
    )),
  ],
  child: const AppRoot(),
)
```

---

## Scenario 5: Material's Five Common Buttons — Styling All, Styling One, or Styling a Subset

**Requirements**: In a Material theme, (1) change the corner radius across all common buttons; (2) change the border and enabled foreground color of `OutlinedButton` only; and (3) change the enabled foreground color of both `OutlinedButton` and `TextButton` together.

### Problems with the Old Approach

`ElevatedButton`, `FilledButton`, `OutlinedButton`, and `TextButton` each have their own separate theme channel (`FilledButton.tonal` shares `FilledButton`'s channel), so changing the corner radius across all buttons requires repeating `shape` across four separate `XButtonThemeData` classes.

### After

Material's five common buttons keep their existing widget classes, but because they share an identical field structure and many default values, they share a single rule type `CommonButtonRule` at the style layer (distinguished by the `appearance` dimension; see Sections 6.4 and 8.2). Use `CommonButtonRule` when styling all five buttons at once; use a generated appearance-scoped subclass (such as `OutlinedButtonRule`, whose region constructors only list regions for that appearance without appearance prefixes on parameter names) when styling a single button type; and use a conditional rule with an `appearance` set when styling a subset of appearances together:

```dart
StyleTheme(
  rules: [
    ...<CommonButtonRule>[
      // (1) Unconstrained appearance: applies to all five button types
      .always(style: .values(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      // (3) Style two appearances together: specify an appearance set
      .when(appearance: {.outlined, .text}, disabled: false,
          style: .values(foregroundColor: brand)),
    ],
    ...<OutlinedButtonRule>[
      // (2) Applies only to OutlinedButton; unspecified disabled region keeps its default value
      .side(idle: BorderSide(color: brand), focused: BorderSide(color: brandStrong)),
      .foregroundColor(enabled: brand),
    ],
  ],
  child: ...,
)
```

Note: Because `foregroundColor` shares the same default state partitioning across all five appearances (one value for enabled and `onSurface` × 0.38 for disabled), calling `CommonButtonRule.foregroundColor(enabled: brand)` on the superclass does not constrain appearance and updates all five button types at once. To update only one appearance, call `OutlinedButtonRule.foregroundColor(enabled: brand)` on the corresponding subclass. On an individual widget instance, the parameter type narrows directly to the corresponding subclass (for example, `OutlinedButton(rules: ...)` takes `List<OutlinedButtonRule>`), so you never repeat the appearance.

---

[← Previous: 4. Core Design Derivation](04-core-derivation.md) | [Back to Index](00-intro.md) | [Next: 6. Detailed Mechanics and Code Generation →](06-design-details-and-codegen.md)
