
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../providers.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';

/// Další sekce nastavení přidávané funkcemi aplikace.
final settingsExtraSections = <Widget Function(BuildContext, WidgetRef)>[];

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

            ListTile(
              title: const Text('Nápověda a zásady'),
              subtitle: const Text('Nápověda, soukromí a informace o aplikaci'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HelpAndPoliciesScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                'Videlon je nezávislá aplikace s otevřeným zdrojovým kódem. '
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

class HelpAndPoliciesScreen extends StatelessWidget {
  const HelpAndPoliciesScreen({super.key});

  void _showInfo(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Zavřít'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nápověda a zásady'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(
                Icons.help_outline,
                color: Colors.white,
              ),
              title: const Text('Nápověda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                context,
                'Nápověda',
                'Vítej ve Videlonu! Návody a další informace '
                    'o používání aplikace připravujeme.',
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.feedback_outlined,
                color: Colors.white,
              ),
              title: const Text('Odeslat zpětnou vazbu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                context,
                'Zpětná vazba',
                'Tato funkce se právě připravuje. '
                    'Brzy zde bude možné posílat návrhy, '
                    'připomínky a hlásit problémy s aplikací Videlon.',
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: Colors.white,
              ),
              title: const Text('Zásady a soukromí'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                context,
                'Zásady a soukromí',
                'Informace o zásadách a ochraně soukromí '
                    'aplikace Videlon budou doplněny.',
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.info_outline,
                color: Colors.white,
              ),
              title: const Text('Informace o Videlonu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Videlon'),
                  content: const Text(
                    'Videlon je nezávislá aplikace s otevřeným '
                    'zdrojovým kódem. Není vytvořena společností '
                    'YouTube ani Google a není s nimi spojena.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        showLicensePage(
                          context: context,
                          applicationName: 'Videlon',
                        );
                      },
                      child: const Text('Licence open source'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Zavřít'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
