# 10. Appendix

[← Previous: 9. Trade-offs](09-topics-and-tradeoffs.md) | [Back to Roadmap](00-intro.md)

---

This appendix collects comparisons of rejected design alternatives, empirical `ThemeExtension` survey data across 21 production projects, and edge-case trade-offs for composite partial patching and migration.

---

## A.1 Candidate API shapes for rule regions

When deciding how to expose the "Rule Regions" described in Section 4 Step 3 and Section 6.1, five candidates were evaluated:

- **Candidate A (doc comments only, no generated API)**: Zero binary size cost, but developers must still copy `XWhen` conditions by hand with no compile-time safeguard against omitting a dimension.
- **Candidate B (generate a separate constant class per stateful field, e.g., `ButtonBackgroundColorRegions.tintedEnabled`)**: Defines regions as `static const` fields of type `ButtonWhen` (requiring 94 such classes in M3). Two drawbacks: the property name must be written twice (`ButtonRule(ButtonBackgroundColorRegions.tintedEnabled, style: ButtonStyle(backgroundColor: x))`), and because every constant has the general type `ButtonWhen`, a constant from one field can be passed to another field's rule—causing silent breakage if the two fields' partitions diverge in a future spec update.
- **Candidate C / C' (one region constant class per component, e.g., `ButtonRegions.filledEnabled`)**: Reduces public classes from 94 to 17, but hits naming collisions because region names like `idle` are relative to a specific field. Spelling out full conditions to disambiguate (Candidate C) yields an average name length of 24 characters (up to 70); prefixing the field name only on collision (Candidate C') yields an average of 20 characters (up to 51) and makes names depend on historical evolution order.
- **Candidate F (attach a `StateMap` to each field)**: Because `XWhen` overrides `==`, it cannot be a key in a `const Map` and must be written as a list of key-value tuples—reverting to the rejected "Direction A" from Section 4 Step 2.
- **Candidate D (selected: generate a `const` named constructor per stateful field on `XRule`, e.g., `ButtonRule.backgroundColor(...)`)**: Returns a `ButtonRule` directly, drops straight into `rules: [...]`, writes the property name once, and scopes parameters strictly to that field's own regions at compile time.

Regarding parameter name length under Candidate D: because regions hang under a field-specific named constructor (omitting the field name prefix) and use `idle` / `enabled` to avoid negated chains like `notHoveredNotPressed`, generated parameter names average 11 characters. In the full M3 audit, the handful of names exceeding 40 characters all come from stacking multiple non-state content/variant prefixes: e.g., Material `Switch.thumbRadius` stacking two boolean content dimensions in `notHasThumbIconNotHasThumbImageIdleUnselected` (45 chars), and `IconButtonM3E` stacking `outlined` and `Material3Expressive` in `outlinedMaterial3ExpressiveFocusedUnselected` (44 chars). Standard component region parameters stay within 1–2 words.

---

## A.2 Rule organization styles

With both condition-outside `.when(...)` and field-outside `ButtonRule.backgroundColor(...)` present, three self-consistent organization styles were compared:

### Option 1: Condition-outside primary, region constructors as single-field literal shortcuts (selected)

```dart
...<ButtonRule>[
  .when(disabled: true, style: .values(
    backgroundColor: grey1, foregroundColor: grey2, iconColor: grey2, side: greySide)),
  .when(pressed: true, style: .values(backgroundColor: dark)),
  .backgroundColor(tintedEnabled: brand),
]
```

General rules put conditions on the outside (`.when` / `.always` / `.whenAny`) so multiple fields share one condition; `ButtonRule.backgroundColor(...)` is used solely for setting literal values along default state partitions on a single field.
- **Pros**: Multi-field state rules write the condition once; `ButtonStyle` blocks can be extracted as named constants; and evolving to Option 3 later only requires adding optional parameters to `.backgroundColor` without breaking changes.
- **Cons**: Two entry points exist; if a single-field `.backgroundColor(tintedEnabled: ...)` tweak later needs an extra non-default condition (such as constraining `size`), it switches to `.when(...)` (region constructor doc comments include the equivalent `.when` condition for copy-pasting).

### Option 2: Field-outside only (remove `.when` / `.always`)

```dart
...<ButtonRule>[
  .backgroundColor(tintedEnabled: brand, when: [
    (.new(disabled: true), .value(grey1)),
    (.new(pressed: true), .value(dark)),
  ]),
  .foregroundColor(when: [(.new(disabled: true), .value(grey2))]),
  .iconColor(when: [(.new(disabled: true), .value(grey2))]),
  .side(when: [(.new(disabled: true), .value(greySide))]),
]
```

All rules are authored per field via `ButtonRule.<field>(...)`, taking an extra `when: [(.new(...), valueOrSource), ...]` tuple list for arbitrary conditions and derivations.
- **Pros**: Only one field-first entry point across the entire system; all customizations for a given field sit in one place.
- **Cons**: Multi-property state or variant changes must repeat the same condition under every field; related properties cannot be bundled into a reusable `ButtonStyle`; and tuple lists read worse than `.when(...)`.

### Option 3: Hybrid (keep `.when` / `.always`, and also add `when:` and derivation support to `ButtonRule.<field>`)

- **Pros**: Supports both single-field and multi-field authoring without switching entry points when adding custom conditions.
- **Cons**: Creates two equivalent ways to write every single-field conditional rule, making team style consistency harder and obscuring cross-field override order when mixed.

---

## A.3 `ThemeExtension` survey and rejected token APIs

An audit of 91 `ThemeExtension` subclasses (1,149 fields) across 21 production Flutter projects (`Color` 79% / 910, `double` 80, `TextStyle` 68, `String` asset paths 48, `ShapeBorder`/`BorderRadius` 11, semantic groups 8, `BoxShadow` 2) informed the rejection of two early Token API candidates:

### 1. Omitting whole-group data classes (`MyBrandData` / `groupOf`)

An early design required users to define a non-nullable data class `MyBrandData` alongside the enum (paired with `StyleTheme.groupOf<MyBrandData>` and `MyBrand.group.set(data)`). Production data showed this layer was counterproductive:
- **Real-world presets are rule lists, not static literal objects**: Roughly 60/91 extensions vary by brightness (7 by high contrast), and many include derivations (49 alias getters, 32 opacity variants, 37 `ColorScheme` references, 10 fallback getters). Expressing presets as a static rule list (`MyBrandRule.teal`) unifies base values, environment branches (`TokenWhen(brightness: .dark)`), and cross-token derivations (`.setFrom`) in one list; a required-field data object cannot hold derivations and would overwrite earlier derivation rules when expanded.
- **`CustomPainter` does not need a whole-group data class**: Across all 21 projects, only 17 files passed extension values to a `CustomPainter`: 15 (88%) already read and passed individual fields (median 2 values), while the only 2 (12%) passing the whole `ThemeExtension` read just 7% (4/56) and 3–6% (1/16) of its fields and both had broken `shouldRepaint` implementations. Grouping multiple resolved tokens for a painter with automatic value-equality `shouldRepaint` is solved with zero boilerplate using a native Dart Record at the `build` boundary:
  ```dart
  typedef RingColors = ({Color done, Color track});
  final RingColors colors = (done: MyBrand.success.of(context), track: MyBrand.textMuted.of(context));
  final double inset = MyBrand.radius.of(context) / 2;
  // RingPainter.shouldRepaint(RingPainter old) => old.colors != colors || old.progress != progress;
  ```
- **Type conversions belong at consumption sites or in `.computed`**: 14 getters in the audit merely wrapped a `double` in `BorderRadius.circular(r)`. Keeping `radius<double>()` as a single numeric token and converting at consumption sites or via `.computed` avoids maintaining duplicate tokens.

### 2. Omitting `maybeOf` / `…OrNull`

Only 2 of the 21 projects defined `…OrNull` helpers, and inspecting every call site showed neither was a genuine "optional token" use case:
1. **Unit tests or preview harnesses mounting incomplete themes**: In the first project, production `MaterialApp` always registered the extension, and it was missing only in bare `ThemeData()` widget tests; accommodating those tests with `…OrNull` forced 30 production widget files (112+ read sites) to carry dead `tokens?.x ?? colorScheme.y` fallback branches. In the new model, `MyBrand.accent.of(context)` always returns non-null `T`, and tests mount the app's `StyleTheme` via a shared `pumpApp` helper (failing fast with a clear `RuleError` if omitted).
2. **Using extension presence as a feature flag for a design refresh (`v1` vs. `v2`)**: In the second project, 26 production files (41 sites) checked `brandTokensOrNull(context) != null` to branch between legacy colors and a new brand refresh, scattering feature-flag logic across every widget. In the new model, the feature flag is read once when mounting `StyleTheme` / `StyleScope`, attaching a compatibility rule list (`MyBrandRule(accent: .fromToken(.primaryColor))`) on unmigrated pages so all widgets unconditionally call `MyBrand.accent.of(context)`.

---

## A.4 Alternatives for `.parts` and `EdgeInsetsGeometry`

1. **Why reject nullable mirror classes (such as `BorderSideStyle`)**:
   Adding a nullable-field mirror class `BorderSideStyle` to make `BorderSide` Mergeable inside `.values(...)` was rejected because it intrudes on `flutter/painting`'s public type hierarchy, creates error-prone near-duplicate class names (`BorderSide` resets omitted `width` to `1.0`, whereas `BorderSideStyle` carries over earlier rules), and cannot work for abstract base classes like `EdgeInsetsGeometry`. Keeping native Flutter types unchanged and providing `.parts(...)` on Patchable source subclasses is non-intrusive and uniform.
2. **Why reject `.inherited((prev) => ...)` callbacks and delta accumulators**:
   To preserve rule idempotency ($f(f(v)) = f(v)$), reading the result of earlier rules on the same field is restricted to projection replacement (`.parts`). Allowing arbitrary `prev + 2.0` deltas or `.inherited` callbacks makes it easy to write non-idempotent rules (which break if a scope above `Navigator` is replayed during route capture), degrades caching from per-winning-rule to per-chain-slice, and significantly complicates static exhaustiveness and provenance checks.
3. **`EdgeInsetsGeometry` internal models and Option A vs. Option B**:
   In `material_ui`, 21 theme files type `padding` as the abstract `EdgeInsetsGeometry` (only 4 use concrete `EdgeInsets`, and ~11% of production button `padding` usages pass `EdgeInsetsDirectional`). All component getters on `EdgeInsetsGeometry` (`_top`, `_start`, etc.) are package-private in `flutter/painting`, backed by three internal subclasses: `EdgeInsets`, `EdgeInsetsDirectional`, and `_MixedEdgeInsets`.
   - **Option A (zero framework changes)**: Only concrete `EdgeInsets` supports `.parts`; `EdgeInsetsGeometry` remains Atomic (whole-value replacement only).
   - **Option B (add a static projection helper in `flutter/painting`)**: Branches across the three internal models inside `painting` and exposes only the four direction-agnostic parameters `.parts(top:, bottom:, vertical:, horizontal:)` on `EdgeInsetsGeometry` (setting `horizontal` sets both left/right and zeroes out `start`/`end` on mixed instances; `left`/`right`/`start`/`end` are omitted to avoid counter-intuitive mixed directional accumulation).

---

## A.5 `material_ui` migration data

### 1. Button and dialog families

Evaluating the three criteria from Section 8.2 across M3 defaults and production codebases:
- **5 common buttons (`CommonButton`)**: In M3 defaults, 11 fields are identical across all 5 appearances (`shape`, `textStyle`, `minimumSize`, `maximumSize`, `iconSize`, `mouseCursor`, `visualDensity`, `tapTargetSize`, `splashFactory`, `surfaceTintColor`, plus disabled foreground and icon colors); `padding` shares the same text-scaling stops (only `TextButton` uses base horizontal padding 12 instead of 24); differences are confined to `backgroundColor`, `foregroundColor`, `elevation`/`shadowColor`, and `side`. Across 17 production button theme families, `shape` is identical in 8/17 (plus 2 excepting only `TextButton`), `textStyle` in 6/6, `padding` in 5/8, and `minimumSize` in 4/6, with 6/16 families copy-pasting identical literals across separate button themes (which collapses into a single `CommonButtonRule`).
- **Dialog family (kept separate)**: Auditing 6 dialog theme families showed minimal sharing on `shape` (1/6), `elevation` (1/6), and `shadowColor` (3/6), so `Dialog` widgets remain separate.

### 2. Truth-table sampling for `resolveWith`

Auditing 122 `WidgetStateProperty.resolveWith` closures in production code showed that 34% depend only on `states` and return constants, 66% depend only on values fixed at `build` time (local variables or theme colors), and under 1% read mutable external state.

Because 99%+ of closures act as pure functions from a finite state set to a value within a single `build`, Truth-Table Sampling was evaluated as an alternative to lazy compatibility rules in Section 8.2:
- **Mechanism**: At chain build time, iterate over all 32–64 reachable state combinations on the component, call `property.resolve(states)` once per combination to sample the full truth table, and merge equal non-null outputs into ordinary declarative `XRule(XWhen(...))` instances.
- **Pros**: Converts black-box closures into transparent declarative rules that participate in `debugSources` and static shadowing checks, and restores value equality (`==`) even when a caller allocates a fresh inline closure on every `build`.
- **Why rejected for runtime release builds**:
  1. **Rebuild sampling overhead**: A lazy compatibility rule (`LegacySource`) invokes the closure only 1–2 times per `build` for the component's current state, whereas truth-table sampling must invoke the closure 32–64 times and run Boolean cube merging every time a widget rebuilds with a new inline closure.
  2. **Limited release-mode payoff**: Restoring `==` on sampled closures only helps if `ThemeData` rebuilds with new closures, which already triggers dependent rebuilds in legacy Flutter anyway; for call-site closures, lazy evaluation only affects that single instance. Static shadowing and `debugSources` matter only in Debug mode (where on-demand sampling can still be offered as a diagnostic utility without taxing release builds).

---

[← Previous: 9. Trade-offs](09-topics-and-tradeoffs.md) | [Back to Roadmap](00-intro.md)
