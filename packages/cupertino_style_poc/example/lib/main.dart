// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Interactive demo of Button / Switch on the rule-based
// style model. Four sections:
//   1. Call site: dynamic colors and a per-state tweak with `states:`.
//   2. Global theme + local scope + dialog.
//   3. Derive: the icon follows the foreground; one plain rule breaks it.
//   4. Channel isolation: changing a button rule rebuilds only buttons.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' hide CupertinoButton, CupertinoSwitch;

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  Brightness _brightness = Brightness.light;
  bool _highContrast = false;
  bool _purpleBrand = false;

  @override
  Widget build(BuildContext context) {
    // The global theme sits outside the app, so dialogs (pushed on the
    // app's Navigator) see it live.
    return StyleTheme(
      groups: <TokenGroup<Object>>[brandGroup],
      rules: <Rule>[
        // App token group values (like a ThemeExtension).
        TokenRule.group(brandGroup, _purpleBrand ? BrandPalettes.purple : BrandPalettes.teal),
        // Button and Switch rules in one list; each goes to its channel.
        ...demoThemeRules,
      ],
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        theme: CupertinoThemeData(brightness: _brightness),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: _highContrast),
          child: child!,
        ),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(middle: Text('cupertino-style-poc')),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _ControlBar(
                  brightness: _brightness,
                  highContrast: _highContrast,
                  purpleBrand: _purpleBrand,
                  onBrightness: (Brightness b) => setState(() => _brightness = b),
                  onHighContrast: (bool v) => setState(() => _highContrast = v),
                  onBrand: (bool v) => setState(() => _purpleBrand = v),
                ),
                const CallSiteSection(),
                const ThemeScopeDialogSection(),
                const DeriveSection(),
                const IsolationSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The global rules of the demo theme (section 2 explains them).
const List<Rule> demoThemeRules = <Rule>[
  // Filled buttons: Brand colors and a smaller radius, every non-disabled
  // state. The disabled look stays the library default.
  ButtonRule(
    ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled}, disabled: false),
    style: ButtonStyle(borderRadius: BorderRadius.all(Radius.circular(8))),
    derive: ButtonDerive(backgroundColor: Brand.accent, foregroundColor: Brand.onAccent),
  ),
  // Dark + pressed: environment and interaction state in one condition.
  // A dynamic color under an environment condition contributes only its
  // slots inside the condition (here systemYellow's dark ones, normal and
  // high contrast).
  ButtonRule(
    ButtonWhen(brightness: <Brightness>{Brightness.dark}, pressed: true),
    style: ButtonStyle(foregroundColor: CupertinoColors.systemYellow),
  ),
  // Switch: the "on" track takes the Brand accent.
  SwitchRule(
    SwitchWhen(selected: true),
    derive: SwitchDerive(trackColor: Brand.accent),
  ),
];

// ---------------------------------------------------------------------------

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.brightness,
    required this.highContrast,
    required this.purpleBrand,
    required this.onBrightness,
    required this.onHighContrast,
    required this.onBrand,
  });

  final Brightness brightness;
  final bool highContrast;
  final bool purpleBrand;
  final ValueChanged<Brightness> onBrightness;
  final ValueChanged<bool> onHighContrast;
  final ValueChanged<bool> onBrand;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: <Widget>[
        CupertinoSlidingSegmentedControl<Brightness>(
          key: const Key('brightness'),
          groupValue: brightness,
          children: const <Brightness, Widget>{Brightness.light: Text('Light'), Brightness.dark: Text('Dark')},
          onValueChanged: (Brightness? b) => onBrightness(b!),
        ),
        CupertinoSlidingSegmentedControl<bool>(
          key: const Key('contrast'),
          groupValue: highContrast,
          children: const <bool, Widget>{false: Text('Normal'), true: Text('High contrast')},
          onValueChanged: (bool? v) => onHighContrast(v!),
        ),
        CupertinoSlidingSegmentedControl<bool>(
          key: const Key('brand'),
          groupValue: purpleBrand,
          children: const <bool, Widget>{false: Text('Brand: teal'), true: Text('Brand: purple')},
          onValueChanged: (bool? v) => onBrand(v!),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.note, required this.children});

  final String title;
  final String note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: base.copyWith(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(note, style: base.copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: children),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Call site.

class CallSiteSection extends StatefulWidget {
  const CallSiteSection({super.key});

  @override
  State<CallSiteSection> createState() => _CallSiteSectionState();
}

class _CallSiteSectionState extends State<CallSiteSection> {
  bool _on = true;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '1. Call site',
      note: 'Dynamic colors go straight into constructor parameters and resolve per environment. '
          'In dark mode the old Switch painted activeTrackColor and trackOutlineColor with their '
          'light variants (a black outline on a dark track), and the old Button did the same with '
          'foregroundColor and focusColor. The orange button changes only while pressed; its disabled twin '
          'and its resting look are untouched.',
      children: <Widget>[
        Button(
          key: const Key('red-button'),
          color: CupertinoColors.systemRed,
          foregroundColor: CupertinoColors.label,
          onPressed: () {},
          child: const Text('systemRed'),
        ),
        Switch(
          key: const Key('green-switch'),
          value: _on,
          activeTrackColor: CupertinoColors.systemGreen,
          trackOutlineColor: CupertinoColors.label,
          onChanged: (bool v) => setState(() => _on = v),
        ),
        Button.tinted(
          key: const Key('pressed-tweak'),
          states: const <ButtonRule>[
            ButtonRule(
              ButtonWhen(pressed: true),
              style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange, pressedOpacity: 1.0),
            ),
          ],
          onPressed: () {},
          child: const Text('Hold me'),
        ),
        const Button.tinted(
          key: Key('pressed-tweak-disabled'),
          states: <ButtonRule>[
            ButtonRule(
              ButtonWhen(pressed: true),
              style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange, pressedOpacity: 1.0),
            ),
          ],
          onPressed: null,
          child: Text('Disabled'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Theme + scope + dialog.

class ThemeScopeDialogSection extends StatelessWidget {
  const ThemeScopeDialogSection({super.key});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '2. Theme, scope, dialog',
      note: 'The theme gives filled buttons the Brand colors and an 8 px radius, makes the text yellow while '
          'pressed in dark mode, and puts the Brand accent on the switch track. The orange scope below only '
          'overrides the button background: the radius and the dark-pressed text survive, and the switch in '
          'the same scope keeps the theme look. The dialog gets the scope rules through InheritedTheme.capture.',
      children: <Widget>[
        Button.filled(key: const Key('theme-button'), onPressed: () {}, child: const Text('Theme')),
        const _StatefulSwitch(key: Key('theme-switch')),
        StyleScope(
          rules: const <Rule>[
            ButtonRule(
              ButtonWhen(disabled: false),
              style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange),
            ),
          ],
          child: Builder(
            builder: (BuildContext scoped) => Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Button.filled(key: const Key('scope-button'), onPressed: () {}, child: const Text('Scope')),
                const _StatefulSwitch(key: Key('scope-switch')),
                Button(
                  key: const Key('open-dialog'),
                  onPressed: () => openDemoDialog(scoped),
                  child: const Text('Open dialog'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// cupertino_ui's showCupertinoDialog does not capture inherited themes
/// (material_ui's showDialog does), so the caller captures them; StyleScope
/// takes part through InheritedTheme.
void openDemoDialog(BuildContext context) {
  final CapturedThemes themes =
      InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
  showCupertinoDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) => themes.wrap(
      CupertinoAlertDialog(
        title: const Text('Dialog'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Button.filled(key: const Key('dialog-button'), onPressed: () {}, child: const Text('In dialog')),
              const SizedBox(height: 8),
              const _StatefulSwitch(key: Key('dialog-switch')),
            ],
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
        ],
      ),
    ),
  );
}

class _StatefulSwitch extends StatefulWidget {
  const _StatefulSwitch({super.key});

  @override
  State<_StatefulSwitch> createState() => _StatefulSwitchState();
}

class _StatefulSwitchState extends State<_StatefulSwitch> {
  bool _on = true;

  @override
  Widget build(BuildContext context) =>
      Switch(value: _on, onChanged: (bool v) => setState(() => _on = v));
}

// ---------------------------------------------------------------------------
// 3. Derive.

class DeriveSection extends StatelessWidget {
  const DeriveSection({super.key});

  @override
  Widget build(BuildContext context) {
    const Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[Icon(CupertinoIcons.heart_fill), SizedBox(width: 6), Text('Like')],
    );
    return _Section(
      title: '3. Derive',
      note: 'Only foregroundColor is passed. By default the text and the icon follow it (a derive in the '
          'library defaults). On the right, a scope sets iconTheme.color with an ordinary rule, which wins over '
          'the default derive for the icon only.',
      children: <Widget>[
        Button(
          key: const Key('derive-follow'),
          foregroundColor: CupertinoColors.systemPink,
          onPressed: () {},
          child: label,
        ),
        StyleScope(
          rules: const <Rule>[
            ButtonRule(
              ButtonWhen(),
              style: ButtonStyle(iconTheme: IconThemeData(color: CupertinoColors.systemGrey)),
            ),
          ],
          child: Button(
            key: const Key('derive-break'),
            foregroundColor: CupertinoColors.systemPink,
            onPressed: () {},
            child: label,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Channel isolation.

/// Build counts of the two widgets below, keyed by their keys.
final Map<Key, int> isolationBuildCounts = <Key, int>{};

/// Bumped after a frame in which a counted widget built, to refresh the
/// label (a label can't be updated during the build it reports on).
final ValueNotifier<int> _countsChanged = ValueNotifier<int>(0);

const Key isolationButtonKey = Key('iso-button');
const Key isolationSwitchKey = Key('iso-switch');

void _countBuild(Widget w) {
  final Key? key = w.key;
  if (key == isolationButtonKey || key == isolationSwitchKey) {
    isolationBuildCounts[key!] = (isolationBuildCounts[key] ?? 0) + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) => _countsChanged.value++);
  }
}

class IsolationSection extends StatefulWidget {
  const IsolationSection({super.key});

  @override
  State<IsolationSection> createState() => _IsolationSectionState();
}

class _IsolationSectionState extends State<IsolationSection> {
  bool _green = false;

  @override
  void initState() {
    super.initState();
    StyleDebug.onComponentBuild = _countBuild;
  }

  @override
  void dispose() {
    if (StyleDebug.onComponentBuild == _countBuild) {
      StyleDebug.onComponentBuild = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: '4. Channel isolation',
      note: 'Both widgets sit in one StyleScope. The toggle swaps the scope\'s ButtonRule. Only the '
          'button rebuilds; the switch subscribes to its own channel and the global one, which did not change.',
      children: <Widget>[
        Button.tinted(
          key: const Key('toggle-rule'),
          onPressed: () => setState(() => _green = !_green),
          child: Text(_green ? 'Button rule: green' : 'Button rule: indigo'),
        ),
        StyleScope(
          rules: <Rule>[
            ButtonRule(
              const ButtonWhen(disabled: false),
              style: ButtonStyle(
                  backgroundColor: _green ? CupertinoColors.systemGreen : CupertinoColors.systemIndigo),
            ),
          ],
          child: const _IsolationRow(),
        ),
      ],
    );
  }
}

class _IsolationRow extends StatelessWidget {
  const _IsolationRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Button.filled(key: isolationButtonKey, onPressed: () {}, child: const Text('Button')),
        const SizedBox(width: 12),
        const _IsolationSwitch(),
        const SizedBox(width: 12),
        ValueListenableBuilder<int>(
          valueListenable: _countsChanged,
          builder: (BuildContext context, int _, Widget? _) => Text(
            'builds: button ${isolationBuildCounts[isolationButtonKey] ?? 0}, '
            'switch ${isolationBuildCounts[isolationSwitchKey] ?? 0}',
            key: const Key('build-counts'),
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _IsolationSwitch extends StatefulWidget {
  const _IsolationSwitch();

  @override
  State<_IsolationSwitch> createState() => _IsolationSwitchState();
}

class _IsolationSwitchState extends State<_IsolationSwitch> {
  bool _on = false;

  @override
  Widget build(BuildContext context) =>
      Switch(key: isolationSwitchKey, value: _on, onChanged: (bool v) => setState(() => _on = v));
}
