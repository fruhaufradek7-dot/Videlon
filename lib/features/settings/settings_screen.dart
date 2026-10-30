
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/sponsorblock/sponsorblock.dart';
import '../../providers.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';

/// Další sekce nastavení přidávané funkcemi aplikace.
/// Ponecháno kvůli kompatibilitě s ostatními částmi aplikace.
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

void _openSettingsPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _category(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return ListTile(
      leading: Icon(icon, color: context.yt.textPrimary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openSettingsPage(context, page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.yt;

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
            _sectionHeader(context, 'Předvolby'),
            _category(
              context,
              icon: Icons.settings_outlined,
              title: 'Obecné',
              subtitle: 'Vzhled, oblast obsahu a obraz v obraze',
              page: const GeneralSettingsScreen(),
            ),
            _category(
              context,
              icon: Icons.play_circle_outline,
              title: 'Přehrávání',
              subtitle: 'Pokračování v přehrávání',
              page: const PlaybackSettingsScreen(),
            ),
            _category(
              context,
              icon: Icons.hd_outlined,
              title: 'Kvalita videa',
              subtitle: 'Výchozí kvalita přehrávání',
              page: const VideoQualitySettingsScreen(),
            ),
            _category(
              context,
              icon: Icons.history,
              title: 'Správa historie',
              subtitle: 'Historie sledování a vyhledávání',
              page: const HistorySettingsScreen(),
            ),
            _category(
              context,
              icon: Icons.system_update_outlined,
              title: 'Aktualizace',
              subtitle: 'Verze aplikace a nové aktualizace',
              page: const UpdatesSettingsScreen(),
            ),

            const Divider(),
            _sectionHeader(context, 'Další možnosti'),
            _category(
              context,
              icon: Icons.fast_forward_outlined,
              title: 'SponsorBlock',
              subtitle: 'Přeskakování sponzorů a dalších částí videí',
              page: const SponsorBlockSettingsScreen(),
            ),

            const Divider(),
            _sectionHeader(context, 'Aplikace'),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Nápověda'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSettingsPage(
                context,
                const HelpDetailScreen(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Odeslat zpětnou vazbu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSettingsPage(
                context,
                const FeedbackDetailScreen(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Zásady a soukromí'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSettingsPage(
                context,
                const PrivacyDetailScreen(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Informace o Videlonu'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openSettingsPage(
                context,
                const VidelonInfoScreen(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Text(
                'Videlon 1.0.1',
                textAlign: TextAlign.center,
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

Widget _sectionHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.yt.textSecondary,
      ),
    ),
  );
}

Future<T?> _pickOption<T>(
  BuildContext context,
  String title,
  Map<T, String> options,
  T selected,
) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: Text(title),
      children: [
        for (final entry in options.entries)
          ChoiceTile(
            title: entry.value,
            selected: entry.key == selected,
            onTap: () => Navigator.pop(dialogContext, entry.key),
          ),
      ],
    ),
  );
}

// OBECNÉ

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Obecné'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            ListTile(
              title: const Text('Vzhled'),
              subtitle: Text(switch (s.themeMode) {
                ThemeMode.system => 'Podle systému',
                ThemeMode.dark => 'Tmavý motiv',
                ThemeMode.light => 'Světlý motiv',
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final mode = await _pickOption<ThemeMode>(
                  context,
                  'Vzhled',
                  {
                    ThemeMode.system: 'Podle systému',
                    ThemeMode.dark: 'Tmavý motiv',
                    ThemeMode.light: 'Světlý motiv',
                  },
                  s.themeMode,
                );
                if (mode != null) {
                  await ctl.update(s.copyWith(themeMode: mode));
                }
              },
            ),
            ListTile(
              title: const Text('Oblast obsahu'),
              subtitle: Text(_regions[s.gl] ?? s.gl),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final region = await _pickOption<String>(
                  context,
                  'Oblast obsahu',
                  _regions,
                  s.gl,
                );
                if (region != null) {
                  await ctl.update(s.copyWith(gl: region));
                }
              },
            ),
            SwitchListTile(
              title: const Text('Obraz v obraze'),
              subtitle: const Text(
                'Pokračovat ve sledování v malém okně po opuštění aplikace',
              ),
              value: s.pip,
              onChanged: (value) => ctl.update(s.copyWith(pip: value)),
            ),
          ],
        ),
      ),
    );
  }
}

// PŘEHRÁVÁNÍ

class PlaybackSettingsScreen extends ConsumerWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Přehrávání'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            SwitchListTile(
              title: const Text('Pokračovat tam, kde jsem skončil'),
              subtitle: const Text('Obnovit poslední pozici videa'),
              value: s.resume,
              onChanged: (value) => ctl.update(s.copyWith(resume: value)),
            ),
          ],
        ),
      ),
    );
  }
}

// KVALITA VIDEA

class VideoQualitySettingsScreen extends ConsumerWidget {
  const VideoQualitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvalita videa'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            _sectionHeader(context, 'Výchozí kvalita přehrávání'),
            for (final quality in VideoQualityPref.values)
              ChoiceTile(
                title: quality.label,
                subtitle: quality.description,
                selected: quality == s.quality,
                onTap: () => ctl.update(s.copyWith(quality: quality)),
              ),
          ],
        ),
      ),
    );
  }
}

// SPRÁVA HISTORIE

class HistorySettingsScreen extends ConsumerWidget {
  const HistorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Správa historie'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            _sectionHeader(context, 'Historie sledování'),
            SwitchListTile(
              title: const Text('Pozastavit historii sledování'),
              value: !s.saveHistory,
              onChanged: (value) =>
                  ctl.update(s.copyWith(saveHistory: !value)),
            ),
            ListTile(
              title: const Text('Vymazat historii sledování'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(libraryProvider).clearHistory();
                if (context.mounted) {
                  showSnack(context, 'Historie sledování byla vymazána');
                }
              },
            ),
            const Divider(),
            _sectionHeader(context, 'Historie vyhledávání'),
            SwitchListTile(
              title: const Text('Pozastavit historii vyhledávání'),
              value: !s.saveSearchHistory,
              onChanged: (value) =>
                  ctl.update(s.copyWith(saveSearchHistory: !value)),
            ),
            ListTile(
              title: const Text('Vymazat historii vyhledávání'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await ref.read(libraryProvider).clearSearches();
                if (context.mounted) {
                  showSnack(context, 'Historie vyhledávání byla vymazána');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// AKTUALIZACE

class UpdatesSettingsScreen extends StatelessWidget {
  const UpdatesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktualizace'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AKTUÁLNÍ VERZE',
                      style: TextStyle(
                        color: context.yt.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Videlon 1.0.1',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.system_update_outlined),
              title: Text('Kontrola aktualizací'),
              subtitle: Text(
                'Možnost kontroly nových verzí připravujeme.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SPONSORBLOCK

class SponsorBlockSettingsScreen extends ConsumerWidget {
  const SponsorBlockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SponsorBlock'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            sponsorBlockSettings(context, ref),
          ],
        ),
      ),
    );
  }
}

// APLIKACE – NÁPOVĚDA A ZÁSADY

class HelpDetailScreen extends StatelessWidget {
  const HelpDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoScreen(
      title: 'Nápověda',
      message: 'Vítej ve Videlonu! Návody a další informace '
          'o používání aplikace připravujeme.',
    );
  }
}

class FeedbackDetailScreen extends StatelessWidget {
  const FeedbackDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoScreen(
      title: 'Odeslat zpětnou vazbu',
      message: 'Tato funkce se právě připravuje. '
          'Brzy zde bude možné posílat návrhy, připomínky '
          'a hlásit problémy s aplikací Videlon.',
    );
  }
}

class PrivacyDetailScreen extends StatelessWidget {
  const PrivacyDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleInfoScreen(
      title: 'Zásady a soukromí',
      message: 'Informace o zásadách a ochraně soukromí '
          'aplikace Videlon budou doplněny.',
    );
  }
}

class _SimpleInfoScreen extends StatelessWidget {
  final String title;
  final String message;

  const _SimpleInfoScreen({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message),
        ),
      ),
    );
  }
}

// INFORMACE O VIDELONU

class VidelonInfoScreen extends StatelessWidget {
  const VidelonInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informace o Videlonu'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.play_circle_outline,
              size: 64,
              color: Colors.teal,
            ),
            const SizedBox(height: 12),
            const Text(
              'VIDELON',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Verze 1.0.1',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.yt.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Videlon je nezávislá aplikace s otevřeným '
              'zdrojovým kódem. Není vytvořena společností '
              'YouTube ani Google a není s nimi spojena.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListTile(
              title: const Text('Licence open source'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Videlon',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
