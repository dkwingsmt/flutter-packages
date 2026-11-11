# 5. Walkthrough

[← Previous: 4. Design](04-core-derivation.md) | [Back to Roadmap](00-intro.md) | [Next: 6. Technical details →](06-design-details-and-codegen.md)

---

Section 4 derived the building blocks of the new model in six steps. This section presents a compact end-to-end code example showing how the global theme, local scopes, custom tokens, and widget call sites work together across all four layers, followed by an index of source files and tests in the companion prototype repository (PoC).

## 5.1 Complete example

Assuming the app has defined the `MyBrand` custom token group from Section 4 Step 4 (`accent`, `success`, `textPrimary`, `textMuted`, `radius`), the following widget tree ties all core mechanisms together (using `cupertino_ui`'s `Button`; for how multiple button widgets in `material_ui` share rules and scoped appearance subclasses, see [Section 6.4](06-design-details-and-codegen.md)):

```dart
StyleTheme(
  groups: [MyBrand.group],
  rules: [
    // 1. Global custom token rules (with brightness branches and dynamic cross-token derivation)
    const MyBrandRule(accent: teal700, success: green700, textPrimary: ink, radius: 12),
    const MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, success: green300, textPrimary: paper),
    MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6)),

    // 2. Global button rules: mixing region constructors, .when multi-dimensional conditions, and .derive
    ...const <ButtonRule>[
      // Region constructor: only change filled enabled background; default disabled grey is preserved
      .backgroundColor(filledEnabled: CupertinoColors.systemIndigo),
      // Cross-field & cross-token derivation: tinted button follows MyBrand.accent, icon color follows final foregroundColor
      .when(appearance: {.tinted}, disabled: false, style: .derive(
        foregroundColor: .fromCustomToken(MyBrand.accent),
        backgroundColor: .opacity(.fromCustomToken(MyBrand.accent), 0.15),
        iconStyle: .parts(color: .fromField(.foregroundColor)),
      )),
      // Interaction state + environment dimension: bright yellow foreground when pressed in dark mode
      .when(pressed: true, brightness: .dark, style: .values(foregroundColor: Color(0xFFFFD60A))),
    ],

    // 3. Composite widget slot: only style the confirm button inside DatePicker green with radius 8
    const DatePickerRule.always(style: .values(
      confirmButton: [
        .backgroundColor(filledEnabled: CupertinoColors.systemGreen),
        .when(disabled: false, style: .values(borderRadius: .all(.circular(8)))),
      ],
    )),
  ],
  child: CupertinoApp(
    home: Builder(builder: (BuildContext context) {
      return Column(children: [
        // A. Ordinary widget reading a non-null custom token directly
        Text('Paid', style: TextStyle(color: MyBrand.success.of(context))),

        // B. Call site: flat parameter (mapped to enabled region) + per-instance rules: tweak
        // Because derivations evaluate after chain merging, passing white foregroundColor automatically turns the icon white too
        Button.tinted(
          foregroundColor: CupertinoColors.white,
          rules: const [
            .when(pressed: true, style: .values(textStyle: TextStyle(fontWeight: FontWeight.bold))),
          ],
          onPressed: save,
          child: const Text('Save'),
        ),

        // C. Local StyleScope incremental override: only change accent and filled button background in the promo area;
        // outer dark-pressed rule, Switch theme, and other tokens remain intact, with 0 Switch rebuilds in the subtree
        StyleScope(
          rules: const [
            MyBrandRule(accent: CupertinoColors.systemOrange),
            ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
          ],
          child: const CheckoutPanel(),
        ),
      ]);
    }),
  ),
);
```

## 5.2 Prototype index

The prototype repository in this directory implements the engine and the `cupertino_ui` `Button` and `Switch` components. You can cross-reference the following source files while reading the remaining sections. The repository is split into two packages: the widget prototype in `packages/cupertino_style_poc/` (paths below are relative to that directory) and the code generator in `packages/style_codegen/`.

- **Rule engine and dynamic color expansion (`lib/src/engine/`, `lib/src/cupertino_adapter.dart`)**
  - Condition matching, pure-order merging, `.fromField`/`.fromToken` symbolic resolution, and cycle detection: `lib/src/engine/engine.dart`
  - Chain-build 8-slot `CupertinoDynamicColor` expansion (`CupertinoEnvSplitter`) and unexpanded container debug checks: `lib/src/cupertino_adapter.dart`
- **Tree distribution and channel caching (`lib/src/engine/widgets.dart`, `lib/src/engine/cache.dart`)**
  - `StyleTheme` / `StyleScope`, `InheritedModel` persistent per-channel linked lists (`ChannelLink`), cross-route `InheritedTheme.capture` snapshot separation, and `debugSources` provenance (`widgets.dart`); two-stage caches `SymbolicCache` + `BoundCache` (`cache.dart`).
- **Widget implementations and generated boilerplate (`lib/src/button.dart`, `lib/src/switch.dart`, `lib/src/*.g.dart`)**
  - Declarative default rule tables for `Button` (13 default rules) and `Switch` (5 default rules), flat-parameter-to-region mappings, and generated `XStyle`, `XRule`, `XWhen`, and region definitions.
- **Code generator (`packages/style_codegen/`)**
  - Component specs live under `specs/cupertino/` and generator logic under `lib/src/` (region partitioning in `regions.dart`); run `dart run style_codegen:generate` in that directory to regenerate `*.g.dart`, or pass `--check` to verify generated outputs are up to date.
- **Interactive demo and regression test suites (`example/`, `test/`)**
  - `example/lib/main.dart` & `example/test/demo_test.dart`: End-to-end app demonstrating light/dark and high-contrast toggles, custom `Brand` token switching, verification that local `StyleScope` only rebuilds affected widgets, and cross-route dialog capture.
  - `test/compare_original_test.dart`: Pixel-by-pixel RGBA comparison across 448 default appearance cases and 304 flat-parameter cases.
  - `test/original_bugs_test.dart`: Reproduces and verifies fixes for 10 legacy bugs where original `CupertinoSwitch` / `CupertinoButton` failed to resolve dynamic colors in dark mode.
  - `test/dynamic_color_test.dart`, `test/regions_test.dart`, `test/widgets_test.dart`: Tests for dynamic color expansion, mutual exclusivity and exhaustiveness of rule regions, and cache hit behavior.

---

[← Previous: 4. Design](04-core-derivation.md) | [Back to Roadmap](00-intro.md) | [Next: 6. Technical details →](06-design-details-and-codegen.md)
