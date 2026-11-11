# 8. Migration

[← Previous: 7. Engineering validation](07-engineering-validation.md) | [Back to Roadmap](00-intro.md) | [Next: 9. Trade-offs →](09-topics-and-tradeoffs.md)

---

Given the different evolutionary stages of `cupertino_ui` and `material_ui`, rollout follows a two-phase strategy: land directly in `cupertino_ui`'s greenfield Liquid Glass components first, and then migrate `material_ui` incrementally using in-place `@Deprecated` parameters and a lazy compatibility rule bridge.

---

## 8.1 `cupertino_ui`

Under the Liquid Glass decision (`lg.export-alongside-legacy`), new unprefixed widgets (`Button`, `Switch`, `Slider`) export alongside legacy `CupertinoButton` and `CupertinoSwitch`, while legacy widgets are phased out without receiving component themes. The new components adopt the new model directly:
1. **Pixel-level validation completed in the prototype**: The prototype repository implements the rule engine, `StyleTheme`, `StyleScope`, code generator, and `Button` and `Switch`, passing pixel-by-pixel comparisons across 448 default appearance cases and 304 flat-parameter cases over all appearances, sizes, states, and 8 environment combinations (the only default rendering difference fixes a bug where the original focus ring failed to resolve dynamic colors).
2. **New components built directly on the generated model**: `XStyle`, `XRule`, `XWhen`, and region constructors are generated from a single source of truth; widget constructors expose flat parameters and `rules:` (new parameters do not accept `WidgetStateProperty`); and `CupertinoDynamicColor` instances expand automatically into environment sub-rules at chain build time.

---

## 8.2 `material_ui`

Migrating `material_ui` without breaking existing apps or third-party packages addresses four areas:

### Widgets sharing rules

Sharing a property bag across structurally distinct components (like legacy `ElevatedButton`, `IconButton`, and `SegmentedButton` all sharing `ButtonStyle`) is not supported, but multiple widgets representing visual tiers (`appearance`) of the same component can share a single rule set at the styling layer when three criteria hold: (1) their field sets and state dimensions match; (2) they share a high proportion of default rules; and (3) common theme customizations (like `shape`, `textStyle`, and size) target shared fields (see [Appendix A.5](10-appendix.md) for empirical audit data).

Applying these criteria across `material_ui` component families:
- **The 5 common buttons (`ElevatedButton`, `FilledButton`, `FilledButton.tonal`, `OutlinedButton`, `TextButton`) share the `CommonButton` rule types**: Widget classes stay unchanged; to avoid colliding with the legacy `ButtonStyle` class, the generator uses the M3 spec term `CommonButton` (`CommonButtonStyle`, `CommonButtonRule`, `CommonButtonWhen`) and emits scoped subclasses for each appearance (`ElevatedButtonRule`, `FilledButtonRule`, `FilledTonalButtonRule`, `OutlinedButtonRule`, `TextButtonRule`; see Section 6.4).
  > Note: Although `FilledButton.tonal` is a named constructor rather than a separate Widget class, it receives its own scoped subclass `FilledTonalButtonRule` (used as the parameter type of `FilledButton.tonal(rules:)`), while legacy `filledButtonTheme` bridges 1-to-2 into a `CommonButtonRule` targeting `appearance: {.filled, .tonal}`.
- **Other component families**: The 4 `IconButton` variants (standard / filled / tonal / outlined) share an `IconButtonRule` with `appearance`; `SegmentedButton` stays separate due to `selected` and multi-segment borders; the `Dialog` family stays separate because its variants share almost no default properties; `Chip` variants will be evaluated using the same criteria.

### Legacy `style:` parameter

**Kept in place and marked `@Deprecated`, requiring zero changes to existing call sites.**

In the new model, widget constructors take flat parameters and `rules:`, leaving the `style:` parameter name unused. Existing `ButtonStyle? style` parameters on `ElevatedButton` and other widgets remain in place as `@Deprecated`: when legacy code passes `style: ElevatedButton.styleFrom(...)` or `ButtonStyle(...)`, non-null fields on the legacy `ButtonStyle` are converted into instance rules placed ahead of flat parameters and `rules:`.

Legacy theme channels (such as `ThemeData.outlinedButtonTheme`) bridge into `OutlinedButtonRule` the same way. When migrating button default rule tables, `.fromField(.foregroundColor)` preserves legacy `styleFrom(foregroundColor:)`'s implicit derivation of `overlayColor` and `iconColor`; and whenever a legacy API passes a non-null `padding`, the bridge appends `paddingScaler: .identity()` to preserve legacy Material's behavior of disabling text-scaled padding when custom padding is set (see Section 6.2).

### Legacy themes and `resolveWith`

The bridge connects legacy `WidgetStateProperty<T>` instances into the rule chain in two ways (for a comparison against the rejected "Truth-Table Sampling" alternative, see [Appendix A.5](10-appendix.md)):

1. **`WidgetStatePropertyAll<T>` and `WidgetStateMapper<T>` (`fromMap`)**:
   Expanded across state combinations and merged into ordinary declarative rules inserted at the corresponding layer; because `fromMap` supports value equality and `const`, the expanded rules are cached across rebuilds.
2. **`WidgetStateProperty.resolveWith` closures — wrapped as compatibility rules (`LegacySource`) and evaluated lazily on demand**:
   Wrapped in place at the corresponding position in the rule chain (theme layer or call-site layer). Only when the engine resolves that field for a specific state combination and scans back to this compatibility rule does it convert the state into a `Set<WidgetState>` and invoke the closure (at most 1–2 calls per widget `build`):
   - A **non-`null` return value** wins immediately and stops the backward scan;
   - A **`null` return value** means unset in the current state, so the engine continues scanning earlier rules in the chain (matching legacy `widget.resolve(s) ?? theme.resolve(s) ?? defaults.resolve(s)` semantics and working seamlessly with `_LerpProperties` closures produced by `ButtonStyle.lerp`).

In implementation, the bridge aligns four details: (1) reproducing per-field `Set<WidgetState>` filtering rules from legacy widgets (e.g., legacy `Switch` filters out `pressed` when resolving track color); (2) ensuring `XWhen` covers all `WidgetState` dimensions passed by legacy implementations; (3) aligning interleaved fallback orders on widgets like `IconButton` and `Slider`; and (4) keeping `primary` as the default fallback for omitted optional parameters in `ColorScheme(...)` constructors while using `ColorScheme` group rules when localized `primary` overrides need downstream recomputation.

### Reading `Theme.of(context)`

Because `material_ui` upgrades `TextButton`, `Card`, `Dialog`, and other widgets in place to read `StyleTheme` / `StyleScope`, built-in composite pages like `showAboutDialog`, `LicensePage`, and `DatePickerDialog` automatically respect the new theme. For legacy app code and third-party packages calling `Theme.of(context)`:
1. **Bidirectional sync for global `ColorScheme` and `TextTheme`**: The top-level `MaterialApp` / `StyleTheme` assembles the resolved slots of the global token channel into `ColorScheme` and `TextTheme` instances and injects them into the fallback `ThemeData`, ensuring `Theme.of(context).colorScheme` and `textTheme` always return current values.
2. **Legacy `ThemeData.xxxTheme` sub-theme getters marked `@Deprecated` (forward bridge only, no reverse evaluation)**: Legacy `ThemeData(cardTheme: ...)` bridges forward into `CardRule`; however, multi-dimensional `CardRule`s written in `StyleTheme` are not reverse-evaluated back into `Theme.of(context).cardTheme` (since multi-dimensional rules and derivations cannot be losslessly collapsed into a static `CardThemeData`). External callers needing resolved component styles should use `Card.resolveStyle(context, ...)` (Section 7.6).

---

[← Previous: 7. Engineering validation](07-engineering-validation.md) | [Back to Roadmap](00-intro.md) | [Next: 9. Trade-offs →](09-topics-and-tradeoffs.md)
