```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../providers.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';

/// Další sekce nastavení přidávané funkcemi aplikace.
final settingsExtraSections = <Widget Function(BuildContext, WidgetRef)>[];

const _languages = {
  'en': 'Angličtina',
  'hi': 'Hindština',
  'ml': 'Malajálamština',
  'ta': 'Tamilština',
  'es': 'Španělština',
  'fr': 'Francouzština',
  'de': 'Němčina',
  'pt': 'Portugalština',
  'it': 'Italština',
  'ja': 'Japonština',
  'ko': 'Korejština',
  'ar': 'Arabština',
  'ru': 'Ruština',
};

const _regions = {
  'US': 'Spojené státy',
  'GB': 'Spojené království',
  'IE': 'Irsko',
  'IN': 'Indie',
  'CA': 'Kanada',
  'AU': 'Austrálie',
  'DE': 'Německo',
  'FR': 'Francie',
  'ES': 'Španělsko',
  'BR': 'Brazílie',
  'JP': 'Japonsko',
  'KR': 'Jižní Korea',
  'AE': 'Spojené arabské emiráty',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    final c = context.yt;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
        );

    Future<T?> pick<T>(
      String title,
      Map<T, String> options,
      T selected,
    ) =>
        showDialog<T>(
          context: context,
          builder: (d) => SimpleDialog(
            title: Text(title),
            children: [
              for (final e in options.entries)
                ChoiceTile(
                  title: e.value,
                  selected: e.key == selected,
                  onTap: () => Navigator.pop(d, e.key),
                ),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            header('Obecné'),
            ListTile(
              title: const Text('Vzhled'),
              subtitle: Text(switch (s.themeMode) {
                ThemeMode.system => 'Podle systému',
                ThemeMode.dark => 'Tmavý motiv',
                ThemeMode.light => 'Světlý motiv',
              }),
              onTap: () async {
                final m = await pick('Vzhled', {
                  ThemeMode.system: 'Podle systému',
                  ThemeMode.dark: 'Tmavý motiv',
                  ThemeMode.light: 'Světlý motiv',
                }, s.themeMode);
                if (m != null) {
                  await ctl.update(s.copyWith(themeMode: m));
                }
              },
            ),
            ListTile(
              title: const Text('Jazyk obsahu'),
              subtitle: Text(_languages[s.hl] ?? s.hl),
              onTap: () async {
                final v = await pick('Jazyk obsahu', _languages, s.hl);
                if (v != null) {
                  await ctl.update(s.copyWith(hl: v));
                }
              },
            ),
            ListTile(
              title: const Text('Oblast obsahu'),
              subtitle: Text(_regions[s.gl] ?? s.gl),
              onTap: () async {
                final v = await pick('Oblast obsahu', _regions, s.gl);
                if (v != null) {
                  await ctl.update(s.copyWith(gl: v));
                }
              },
            ),
            SwitchListTile(
              title: const Text('Obraz v obraze'),
              subtitle: const Text(
                'Pokračovat ve sledování v malém okně po opuštění aplikace',
              ),
              value: s.pip,
              onChanged: (v) => ctl.update(s.copyWith(pip: v)),
            ),
            const Divider(),

            // Automatické přehrávání se ovládá přímo v přehrávači.
            header('Přehrávání'),
            SwitchListTile(
              title: const Text('Pokračovat tam, kde jsem skončil'),
              value: s.resume,
              onChanged: (v) => ctl.update(s.copyWith(resume: v)),
            ),
            const Divider(),

            header('Předvolby kvality videa'),
            for (final q in VideoQualityPref.values)
              ChoiceTile(
                title: q.label,
                subtitle: q.description,
                selected: q == s.quality,
                onTap: () => ctl.update(s.copyWith(quality: q)),
              ),

            for (final section in settingsExtraSections)
              section(context, ref),

            const Divider(),
            header('Správa historie'),
            SwitchListTile(
              title: const Text('Pozastavit historii sledování'),
              value: !s.saveHistory,
              onChanged: (v) =>
                  ctl.update(s.copyWith(saveHistory: !v)),
            ),
            SwitchListTile(
              title: const Text('Pozastavit historii vyhledávání'),
              value: !s.saveSearchHistory,
              onChanged: (v) =>
                  ctl.update(s.copyWith(saveSearchHistory: !v)),
            ),
            ListTile(
              title: const Text('Vymazat historii sledování'),
              onTap: () async {
                await ref.read(libraryProvider).clearHistory();
                if (context.mounted) {
                  showSnack(context, 'Historie sledování byla vymazána');
                }
              },
            ),
            ListTile(
              title: const Text('Vymazat historii vyhledávání'),
              onTap: () async {
                await ref.read(libraryProvider).clearSearches();
                if (context.mounted) {
                  showSnack(context, 'Historie vyhledávání byla vymazána');
                }
              },
            ),
            const Divider(),

            header('O aplikaci'),
            ListTile(
              title: const Text('Licence open source'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'YouPipe',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                'YouPipe je nezávislá aplikace s otevřeným zdrojovým kódem. '
                'Není vytvořena společností YouTube ani Google a není s nimi spojena.',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
