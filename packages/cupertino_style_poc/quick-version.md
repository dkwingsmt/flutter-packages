# A Component Theming Model for Flutter (Quick Version)

> Working draft for internal team review. Class names are temporary placeholders; final naming will be decided separately. For the full derivation, engineering benchmarks, and migration plan, see the [full design document (`design-doc/00-intro.md`)](design-doc/00-intro.md).

## TL;DR

Flutter's current component theming model is built on a one-dimensional static property table, and this causes structural problems. `material_ui` puts state closures inside per-property `WidgetStateProperty` wrappers: linked properties repeat the same conditions, closures break `==`, and a local theme replaces the outer theme instead of merging with it. `cupertino_ui` has two separate per-property wrappers, one for interaction states (`WSP`) and one for environment slots (`CupertinoDynamicColor`), so a component either unrolls flat parameters for a few states, lets the nested wrapper type spread through its call chain, or relies on `implements Color`, which silently degrades.

This proposal flips the model into a two-dimensional table of `Condition (outside) × Properties (inside)`: each component has a plain-value style class `XStyle` (`null` solely means unset), and all visual variations—interaction states, component-specific variants (appearance, size, tristate), and environment dimensions (brightness, contrast)—are expressed as compile-time `const` pure-data rules `XRule(XWhen, XStyle)`. Widget constructors keep familiar flat parameters for everyday use; rules are needed only when targeting specific states or linking properties together.

`cupertino_ui` is rewriting its components for Liquid Glass and has no component themes yet, which makes it the place to land and validate the model first; `material_ui` follows later via a compatibility bridge.

---

## Problems

Even if build-time code generation were expanded to eliminate the manual synchronization bugs across the 9 boilerplate locations per property, the underlying architecture still has three structural problems that code generation cannot solve (see [Section 2 of the full design doc](design-doc/02-problems.md)):

1. **Patching multi-dimensional states onto a 1D property table causes condition duplication, broken equality, and type erasure**:
   - **Single-property limits of `WidgetStateProperty` (WSP)**: Because state hangs off individual properties rather than a style block, updating background, foreground, and border together under `disabled` or `selected` requires repeating the same state branches under every property; whenever cross-field or opacity derivations are needed, declarative `fromMap` (<2% of production usages) cannot express them, forcing a retreat to `resolveWith` closures (`==` is always `false`, triggering unnecessary subtree rebuilds and spurious interpolation animations [#89127](https://github.com/flutter/flutter/issues/89127)). Meanwhile, the fixed 8-value global `WidgetState` enum neither constrains valid states on simple widgets at compile time nor accommodates component-specific dimensions (such as `Checkbox` tristate `indeterminate`, button `filled`/`tonal` appearances, or M3E size tiers).
   - **Two-layer conflict between `CupertinoDynamicColor` (CDC) and `WSP`**: Cupertino properties often need both interaction states and 8-slot environment dimensions. Wrapping a single layer either forces unrolling flat parameters like `activeTrackColor` / `inactiveTrackColor` (which do not scale beyond a single boolean state) or drops brightness and contrast (`trackOutlineWidth: WSP<double?>`); writing `WSP<CDC>` spreads the wrapper type through the entire call chain. Making `CDC implements Color` to hide that nesting erases the compile-time type distinction—it does not generalize to non-color properties, and it silently degrades to the light-mode slot whenever `.withValues(alpha:)` or `Color.lerp` is called before resolution.
2. **Six-way semantic overloading of `null` and `lerp` fallback short-circuiting**:
   A single `null` is overloaded to mean "unset at this layer," "disable an effect (`pressedOpacity: null`)," "trigger a cross-field fallback in `build()` (`iconColor ?? foregroundColor`)," and "interpolate toward transparent black in `lerp`." During `ThemeData.lerp` transitions, `Color.lerp(null, red, 0.5)` produces a non-null translucent dark red at the midpoint, skipping `iconColor ?? foregroundColor` in `build()` and causing the icon to flash dark; moreover, the 37 hand-written fallback chains across `material_ui` `build()` methods are long and mutually contradictory.
3. **Eagerly evaluated black-box derivations and monolithic `ThemeData` overhead**:
   Token derivations are baked into static colors when constructing theme objects, so modifying a source token via `copyWith` in a subtree does not update downstream fields; accessibility text-scaled padding on buttons is tied to the private `padding == null` branch and is lost as soon as a custom `padding` is passed. Meanwhile, monolithic `ThemeData` statically references all 50+ component theme classes, blocking tree-shaking (~200 KB even in a minimal app), and any change rebuilds every widget that depends on it.

---

## Design

A component's appearance is modeled as a 2D table of `Condition (state / variant / environment) × Property`. Library defaults, the global theme (`StyleTheme`), local overrides (`StyleScope`), call-site flat parameters, and call-site `rules:` concatenate in order into a single chain where later rules win per property independently (see [Sections 4 and 5 of the full design doc](design-doc/04-core-derivation.md)).

### 1. Call sites

Most call sites only need flat parameters. Maintainers curate common properties from the generated Rule Regions and expose them as plain-value constructor parameters (so `color` maps to the enabled region without affecting `disabled`), and in `cupertino_ui` dynamic colors can be passed directly. Only when tweaking specific interaction states on an instance do you append `const` rules in `rules:` using dot shorthands:

```dart
Button(
  appearance: ButtonAppearance.filled,
  color: CupertinoColors.systemRed,         // Flat parameter: sets only the enabled region; default disabled grey stays intact
  disabledColor: CupertinoColors.systemGrey4,
  rules: const [
    // Only append the multi-property change for pressed:
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

### 2. Themes and scopes

To prevent broad hand-written conditions from overriding fine-grained default states like `disabled`, the code generator statically analyzes each component's default rule table, partitions states into mutually exclusive and exhaustive regions per field, and generates named region constructors on `XRule` (such as `ButtonRule.backgroundColor(tintedEnabled: ...)`). Use region constructors (IDE autocomplete lists the regions) when changing a single field's literal value along default state boundaries; use `.when(...)` when linking multiple fields or combining dimensions:

```dart
StyleTheme(
  rules: const [
    ...<ButtonRule>[
      // Region constructor: only change tinted enabled background; default disabled styling is preserved
      .backgroundColor(tintedEnabled: CupertinoColors.systemTeal),
      // Conditional rule: change border radius across all non-disabled buttons
      .when(disabled: false, style: .values(borderRadius: .all(.circular(12)))),
      // Dark mode + pressed: environment dimension and interaction state live in one condition, resolved in a single pass
      .when(pressed: true, brightness: .dark, style: .values(foregroundColor: Color(0xFFFFD60A))),
    ],
    ...<SwitchRule>[
      .trackColor(selected: CupertinoColors.systemTeal),
    ],
  ],
  child: CupertinoApp(
    home: StyleScope(
      // Incremental local override: only change filled enabled button background to orange;
      // outer border radius, dark-pressed gold, and tinted teal all remain intact.
      // Powered by InheritedModel per-channel notifications, this Scope only wakes the button channel (0 Switch rebuilds).
      rules: const [
        ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
      ],
      child: const CheckoutPanel(),
    ),
  ),
)
```

### 3. Derivation and tokens

When a property needs to follow a sibling field on the same component (`.fromField`), reference a global token (`.fromToken` / `.fromCustomToken`), scale opacity (`.opacity`), or patch sub-properties of `TextStyle` / `BorderSide` / `EdgeInsets` (`.parts`), switch `style:` from `.values(...)` to the symmetric `.derive(...)`. A derived rule competes in order like any other rule and is evaluated only after it wins.

Apps can also define custom `TokenGroup`s with one token enum and one write-side rule class (replacing boilerplate-heavy `ThemeExtension`s: no hand-written `copyWith` or `lerp`, adding a field takes 1 line in each of 3 places, and 99% of common types use the built-in interpolation table):

```dart
// 1. Define Token enum (serves as both key and MyBrand.x.of(context) read entry point) and write-side rule class
enum MyBrand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  textPrimary<Color>(),
  textMuted<Color>();

  const MyBrand({this.lerp});
  @override
  final T? Function(T? a, T? b, double t)? lerp;
  static const TokenGroup group = TokenGroup('MyBrand', values);
}

final class const MyBrandRule({
  super.when,
  final Color? accent,
  final Color? textPrimary,
  final Color? textMuted,
}) extends TokenValueRule {
  @override
  Map<Token<Object>, Object> get values => {
    MyBrand.accent: ?accent,
    MyBrand.textPrimary: ?textPrimary,
    MyBrand.textMuted: ?textMuted,
  };
}

// 2. Configure environment branches, cross-token derivations, and component cross-field derivations in StyleTheme:
StyleTheme(
  groups: [MyBrand.group],
  rules: [
    const MyBrandRule(accent: teal700, textPrimary: ink),
    const MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, textPrimary: paper),
    // Dynamic cross-token derivation: whichever layer overrides textPrimary, textMuted recomputes at 60% opacity
    MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6)),
    // Component rule: foreground and background reference MyBrand.accent; icon color follows final foregroundColor via .parts
    const ButtonRule.when(
      appearance: {.tinted},
      disabled: false,
      style: .derive(
        foregroundColor: .fromCustomToken(MyBrand.accent),
        backgroundColor: .opacity(.fromCustomToken(MyBrand.accent), 0.15),
        iconStyle: .parts(color: .fromField(.foregroundColor)),
      ),
    ),
  ],
  child: Builder(
    // Read non-null value directly inside an ordinary widget:
    builder: (context) => Text('Caption', style: TextStyle(color: MyBrand.textMuted.of(context))),
  ),
)
```

---

## Status

- **Timing**: Legacy Cupertino widgets are being phased out, and the new unprefixed Liquid Glass widgets (`Button`, `Switch`) are scheduled to introduce component theming in Phase 4 with no legacy component themes. Landing the new model here avoids repeating the `XThemeData` + `WSP` flaws on new widgets, before following up in `material_ui` via a compatibility bridge (see [Section 1](design-doc/01-context-and-goals.md) and [Section 8](design-doc/08-migration-plan.md)).
- **Validation**:
  1. **`material_ui` spec coverage and caching benchmark**: Rewriting the defaults of 17 core component groups (including M3E variants) as declarative rules produced 0 diffs across 2,134,974 field comparisons over all states and 6 color schemes, in 29% of the code lines of `_XDefaultsM3` (1,017 vs. 3,529). Two-stage caching (`SymbolicCache` + `BoundCache`) achieves a 100% symbolic hit rate on frames 2–60 of a 60-frame theme interpolation benchmark, cutting per-frame time to 1/3 of rebuilding rules (~205µs vs. 607µs in JIT mode).
  2. **`cupertino_ui` pixel-level parity**: The companion prototype repository implements the engine, `StyleTheme`/`StyleScope`, cross-route local chain capture, and `Button` and `Switch`, passing pixel-by-pixel RGBA comparisons across 448 default appearance cases and 304 flat-parameter cases (while fixing 10 legacy bugs where dark-mode dynamic colors were left unresolved).

---

## Trade-offs and non-goals

### Trade-offs
- **Broad hand-written conditions require attention to override scope**: Under pure order precedence, a broad `.when(...)` overwrites earlier narrower states; everyday single-property tweaks should prefer generated region constructors (`ButtonRule.backgroundColor(tintedEnabled: ...)`).
- **Conciseness relies on Dart dot shorthands**: Dot shorthands omit generated class prefixes like `ButtonStyleSpec` and `ButtonColorSource`, and developers' app code is free to use them. Code inside the framework packages is generated and spells out full class names to comply with the Flutter repo style guide, whose Rule 5 disallows dot shorthands in positional arguments such as `.fromField(.foregroundColor)` (see [Section 9.2](design-doc/09-topics-and-tradeoffs.md)).
- **Long-term coexistence with `ThemeData` in `material_ui`**: Handled via in-place `@Deprecated` `style:` parameters, bidirectional `ColorScheme`/`TextTheme` sync, and lazy `resolveWith` compatibility rules (`LegacySource`) for incremental per-family migration (see [Section 8.2](design-doc/08-migration-plan.md)).

### Non-goals
- **No theming infrastructure in `flutter/framework` (`widgets` layer)**: `WidgetStateProperty` in `widgets` stays untouched; the two packages share only the build-time code generator, checking generated outputs into each package with independent runtime engines (downstream developers never run build tools).
- **No theming retrofits for legacy `Cupertino*` widgets, and no public codegen for custom app widgets** (custom app `TokenGroup`s are lightweight hand-written classes and require no codegen).
- **Not a replacement for custom app widget composition, and no dynamic custom environment dimensions on `When`** (screen breakpoints or custom skin modes switch the rule list outside `StyleTheme` / `StyleScope`).

---

## FAQ

- **Why not just use `WSP.fromMap`, `Mix`, `Forui`, or Compose's `Styles API`?**
  `fromMap` keys are locked to the fixed `WidgetState` enum and store only static precomputed values; `Mix` targets atomic primitives and its method chains cannot be `const`; `Forui` bakes tokens into static colors at theme construction time (lacking lazy derivations and sibling-field following) and wraps `FVariants` per property; Compose `Styles API` uses runtime closures, whereas Dart's core optimization is compile-time `const`. See [Section 3](design-doc/03-requirements-and-existing-options.md) and [Section 9.1](design-doc/09-topics-and-tradeoffs.md).
- **How does passing `CupertinoDynamicColor` work in `cupertino_ui`?**
  In `cupertino_ui`, flat constructor parameters, region constructors, rule `style:` blocks, and tokens all accept `CDC` directly. During chain flattening, the engine expands its 8 environment slots into environment-conditioned plain `Color` sub-rules, so evaluation and painting only ever see plain `Color`s, and components can no longer forget to call `resolveFrom` (see [Section 4 Step 6](design-doc/04-core-derivation.md)).
- **Does generating classes per component hurt binary size?**
  Central registries and monolithic theme objects are not allowed, so unused components and their rule classes are tree-shaken by the compiler; region constructors share a single fixed-slot expansion loop, adding 0 bytes when unused across AOT / Web / Wasm and ~21 bytes per region in AOT when all regions are referenced (see [Section 6.1](design-doc/06-design-details-and-codegen.md) and [Section 7.2](design-doc/07-engineering-validation.md)).
