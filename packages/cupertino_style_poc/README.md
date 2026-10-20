# Cupertino Rule-Based Styling Prototype

This repository is a working prototype for a rule-based styling and theming system in Flutter's Cupertino library. It accompanies the design proposal in [`quick-version.md`](quick-version.md), which outlines the motivation, core design skeleton, and FAQ. Detailed design documents will be added under a `docs/` directory at the repository root as the proposal evolves.

To give the prototype a concrete visual baseline for pixel-level regression testing, the `Button` and `Switch` widgets in this repository borrow the current visual specifications of `CupertinoButton` and `CupertinoSwitch` from `cupertino_ui`. The widgets intentionally omit the `Cupertino` prefix because this proposal targets the upcoming Liquid Glass component library (`cupertino`) rather than retrofitting legacy `Cupertino*` widgets in place.

## Reading the Code

The package implementation lives under `lib/src/` and is split into four layers.

The core rule engine in `lib/src/engine/` (`engine.dart`, `composite.dart`, `groups.dart`, and `cache.dart`) defines conditions (`Condition`), style payloads (`Style`), late-evaluated derivations (`Derive` with `FieldRef` and `TokenRef`), and token groups (`TokenGroup`). It knows nothing about Flutter widgets or Cupertino types; it evaluates a flat chain of rules against a state map, resolving properties per field on a last-write-wins basis and evaluating `derive` references after the entire chain finishes.

The Flutter widget binding in `lib/src/widgets.dart` connects the rule engine to the widget tree. `StyleTheme` sits at the root of the application and holds global token groups and component rules, while `StyleScope` appends local rule overrides for a subtree. Internally, `StyleNode` and `ChannelLink` form a persistent linked list of rules partitioned by component type (`RuleChannels`) and cached per `(StyleNode, ResolvedEnvironment)`. Updating rules for one component type notifies only widgets subscribed to that channel, and `StyleTheme.captureAll` preserves scoped rules across modal routes such as dialogs and action sheets.

The Cupertino adapter in `lib/src/cupertino_adapter.dart` (along with the generated-style facade in `lib/src/cupertino_adapter.facade.g.dart`) bridges Cupertino's environment model into the rule engine. It defines the three environment dimensions (`brightness`, `highContrast`, and `interfaceLevel`), maps `CupertinoThemeData` into a `TokenGroup` (`cupertinoTokenGroup`), and provides `cupertinoEnvSplitter`. Whenever a rule or constructor parameter contains a `CupertinoDynamicColor` or `EnvAlpha`, the splitter expands that rule at chain-construction time into environment-conditioned plain-color sub-rules. By the time a widget resolves its style, no unexpanded `CupertinoDynamicColor` remains, eliminating manual `CupertinoDynamicColor.resolveFrom` calls inside widget implementations. This file also defines a sample custom token group (`Brand` / `brandGroup`) and the helper that expands map-backed `WidgetStateProperty.fromMap` values into rules.

The prototype components live in `lib/src/button.dart` and `lib/src/switch.dart`, paired with their hand-written codegen counterparts `lib/src/button.g.dart` and `lib/src/switch.g.dart` (marked `SHOULD BE GENERATED`). Each `.dart` file expresses the component's built-in appearance table as a `const` list of rules (`buttonDefaults` and `switchDefaults`), translates flat constructor parameters (`color`, `foregroundColor`, `activeTrackColor`, etc.) into call-site rules placed before `states:`, and builds the widget from the resolved `ButtonStyle` or `SwitchStyle`. Each `.g.dart` file defines the typed `When`, `Style`, `Derive`, and `Rule` classes for that component, along with pre-composed region constants (`ButtonRegions`, `SwitchRegions`).

## Exploring the Interactive Demo

The `example/` directory contains an interactive app (`example/lib/main.dart`) with a top control bar for switching between Light and Dark mode, Standard and High Contrast, and custom `Brand` token palettes (`teal` and `purple`). Below the control bar, four sections demonstrate the core mechanics of the proposal:

1. **Call site**: Passes dynamic colors and `WidgetStateProperty.fromMap` values directly to `Button` and `Switch` constructors (including properties where legacy `cupertino_ui` fails to resolve dynamic colors), and tweaks only the pressed state on a single button via `states:`.
2. **Global theme + local scope + dialog**: Combines app-wide `StyleTheme` rules (`Brand` token derivation and a combined dark + pressed rule) with a local `StyleScope` override that changes only the background color while preserving the theme's corner radius and dark-pressed foreground, plus a dialog launched via `StyleTheme.captureAll` that inherits the caller's scope chain.
3. **Derive (`FieldRef` & `TokenRef`)**: Shows icon and text colors automatically following the final resolved `foregroundColor` across themes and call sites, alongside a button where a plain rule intentionally breaks that follow relationship for the icon only.
4. **Channel isolation**: Displays live widget build counters for `Button` and `Switch` inside a `StyleScope` while you mutate `ButtonRule` vs. `SwitchRule` entries independently, showing that changing one component's rules rebuilds only widgets of that component type.

## Reading the Tests

The test suite under `test/` and `example/test/` verifies both behavioural equivalence with `cupertino_ui` and the new capabilities described in the proposal:

- `test/quick_version_snippets_test.dart` translates every code snippet and FAQ claim in [`quick-version.md`](quick-version.md) into executable assertions across all 8 environments and all button/switch states.
- `test/compare_original_test.dart` renders the prototype `Button` and `Switch` alongside the original `cupertino_ui` widgets and compares their captured pixels across 288 default button cases (3 appearances × 3 sizes × 4 interaction states × 8 environments), 160 default switch cases (2 values × 2 enabled states × 5 interactions × 8 environments), and flat constructor parameter overrides.
- `test/original_bugs_test.dart` reproduces the 10 unexpanded `CupertinoDynamicColor` bugs in the original `CupertinoButton` and `CupertinoSwitch` implementations and verifies that the rule-based widgets resolve every slot to the expected dark/high-contrast/elevated variant.
- `test/original_checkbox_bugs_test.dart` confirms on the original `CupertinoCheckbox` that user-supplied dynamic colors passed to `fillColor` (checked and unchecked), `checkColor`, `activeColor`, and `focusColor` render with their light-mode variant in dark mode.
- `test/dynamic_color_test.dart` tests `cupertinoEnvSplitter` directly: deduplicating identical variants, intersecting with existing `When` conditions, handling sub-property colors (`textStyle.color`, `iconTheme.color`), and caching expanded chains.
- `test/widgets_test.dart` covers `StyleTheme` and `StyleScope` mechanics: rule ordering, per-channel rebuild isolation, `StyleTheme.captureAll` across pushed routes, `CupertinoApp` bridge integration, and `WidgetStateProperty.fromMap` expansion (including rejecting opaque `resolveWith` closures).
- `test/regions_test.dart` checks the pre-composed `ButtonRegions` and `SwitchRegions` constants against the underlying `ButtonWhen` and `SwitchWhen` constraints.
- `example/test/demo_test.dart` tests all four sections of the interactive example app.

## Running Tests and the Example App

Run the package test suite, static analysis, and the interactive demo with Flutter:

```sh
flutter analyze
flutter test
(cd example && flutter test)
(cd example && flutter run -d macos) # or -d chrome
```
