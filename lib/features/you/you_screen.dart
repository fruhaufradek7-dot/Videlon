
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/library_repository.dart';
import '../../innertube/models.dart';
import '../../providers.dart';
import '../../ui/navigation.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/top_bar.dart';
import '../../ui/widgets/video_menu.dart';
import '../../ui/widgets/video_tiles.dart';
import '../playlist/playlist_screen.dart';

/// Položky přidané pozdějšími funkcemi (stahování, účet).
typedef YouEntry = ({
  IconData icon,
  String label,
  void Function(BuildContext, WidgetRef) onTap
});

final youExtraEntries = <YouEntry>[];

/// Widget zobrazený nahoře na stránce Vy (záhlaví účtu po přihlášení).
Widget Function(BuildContext, WidgetRef)? youHeaderBuilder;

class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final playlists =
        ref.watch(localPlaylistsProvider).value ?? const <LocalPlaylistSummary>[];
    final liked = ref.watch(likedVideosProvider).value ?? const <VideoItem>[];
    final saved =
        ref.watch(savedPlaylistsProvider).value ?? const <PlaylistItem>[];
    final c = context.yt;

    final playlistSectionKey = GlobalKey();

    YouEntry? downloadEntry;
    for (final entry in youExtraEntries) {
      if (entry.label.toLowerCase().contains('stažen')) {
        downloadEntry = entry;
        break;
      }
    }

    void openPlaylistSection() {
      final targetContext = playlistSectionKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    }

    Widget sectionTitle(String title, VoidCallback? onViewAll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 12, 12),
          child: Row(
            children: [
              Text(title, style: YtText.sectionTitle),
              const Spacer(),
              if (onViewAll != null)
                OutlinedButton(
                  onPressed: onViewAll,
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(color: c.divider),
                    foregroundColor: c.textPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Zobrazit vše'),
                ),
            ],
          ),
        );

    Widget libraryTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return Material(
        color: c.raised,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: c.textPrimary, size: 25),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: StatusBarScrim(
        child: CustomScrollView(
          slivers: [
            YtTopBar(
              title: const Text(
                'Vy',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),

            // Profil / přihlášení
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: c.divider),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: youHeaderBuilder?.call(context, ref) ??
                      Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: c.chip,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Symbols.person,
                              size: 34,
                              color: c.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Vítej ve Videlonu',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Tvoje videa a knihovna na jednom místě',
                                  style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),

            // Knihovna
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Text(
                  'Tvoje knihovna',
                  style: YtText.sectionTitle,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  libraryTile(
                    icon: Symbols.history,
                    title: 'Historie',
                    subtitle: '${history.length} sledovaných videí',
                    onTap: () => openHistory(context, ref),
                  ),
                  libraryTile(
                    icon: Symbols.playlist_play,
                    title: 'Playlisty',
                    subtitle: 'Tvoje seznamy videí',
                    onTap: openPlaylistSection,
                  ),
                  libraryTile(
                    icon: Symbols.download,
                    title: 'Stažená videa',
                    subtitle: downloadEntry == null
                        ? 'Offline obsah'
                        : 'Stažený obsah',
                    onTap: () {
                      final entry = downloadEntry;
                      if (entry != null) {
                        entry.onTap(context, ref);
                      } else {
                        showSnack(
                          context,
                          'Stahování zatím není dostupné.',
                        );
                      }
                    },
                  ),
                  libraryTile(
                    icon: Symbols.subscriptions,
                    title: 'Odběry',
                    subtitle: 'Odebírané kanály',
                    onTap: () => openChannels(context, ref),
                  ),
                ],
              ),
            ),

            // Playlisty
            SliverToBoxAdapter(
              key: playlistSectionKey,
              child: sectionTitle('Playlisty', null),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 160 * 9 / 16 + 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _PlaylistCard(
                      title: 'Oblíbená videa',
                      subtitle: '${liked.length} videí',
                      thumbnail: liked.firstOrNull?.thumbnailOrDefault,
                      icon: Symbols.thumb_up,
                      onTap: () => context.push(
                        '${branchPrefix(context)}/local/${LocalPlaylistScreen.liked}',
                      ),
                    ),
                    for (final p in playlists)
                      _PlaylistCard(
                        title: p.playlist.name,
                        subtitle: p.playlist.isWatchLater
                            ? '${p.count} videí'
                            : 'Soukromý · ${p.count} videí',
                        thumbnail: p.thumbnail,
                        icon: p.playlist.isWatchLater
                            ? Symbols.schedule
                            : null,
                        onTap: () =>
                            openLocalPlaylist(context, ref, p.playlist.id),
                      ),
                    for (final s in saved)
                      _PlaylistCard(
                        title: s.title,
                        subtitle: s.channelName ?? 'Playlist',
                        thumbnail: s.thumbnail,
                        onTap: () => openPlaylist(context, ref, s.id),
                      ),
                  ],
                ),
              ),
            ),

            // Vytvoření playlistu
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final name = await promptText(
                      context,
                      title: 'Nový playlist',
                      hint: 'Zadejte název',
                    );
                    if (name != null && name.trim().isNotEmpty) {
                      await ref.read(libraryProvider).createPlaylist(
                            name.trim(),
                          );
                    }
                  },
                  icon: const Icon(Symbols.add),
                  label: const Text('Vytvořit playlist'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.divider),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // Další funkce přidané rozšířeními
            if (youExtraEntries.any(
              (entry) => entry.label != downloadEntry?.label,
            ))
              SliverToBoxAdapter(
                child: sectionTitle('Další funkce', null),
              ),

            SliverList(
              delegate: SliverChildListDelegate([
                for (final entry in youExtraEntries)
                  if (entry.label != downloadEntry?.label)
                    ListTile(
                      leading: Icon(entry.icon, weight: 300),
                      title: Text(entry.label),
                      onTap: () => entry.onTap(context, ref),
                    ),
              ]),
            ),

            // Nastavení
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
                child: Material(
                  color: c.raised,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => openSettings(context, ref),
                    child: Padding(
                      padding: const EdgeInsets.all(17),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.chip,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Symbols.settings,
                              color: c.textPrimary,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nastavení',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Přizpůsob si Videlon podle sebe',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Symbols.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SliverBottomInset(),
          ],
        ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.title,
    required this.subtitle,
    this.thumbnail,
    this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String? thumbnail;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                PlaylistThumb(thumbnail: thumbnail, icon: icon),
                const SizedBox(height: 8),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YtText.rowTitle,
                ),
                Text(
                  subtitle,
                  style: YtText.meta.copyWith(
                    color: context.yt.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Historie sledování od nejnovějších, seskupená podle dnů a měsíců.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final lib = ref.read(libraryProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const months = [
      'leden',
      'únor',
      'březen',
      'duben',
      'květen',
      'červen',
      'červenec',
      'srpen',
      'září',
      'říjen',
      'listopad',
      'prosinec',
    ];

    String group(DateTime t) {
      final day = DateTime(t.year, t.month, t.day);
      final d = today.difference(day).inDays;
      if (d <= 0) return 'Dnes';
      if (d == 1) return 'Včera';
      if (d < 7) return 'Tento týden';
      return t.year == now.year
          ? months[t.month - 1]
          : '${months[t.month - 1]} ${t.year}';
    }

    final rows = <Object>[];
    String? last;
    for (final h in history) {
      final g = group(h.watchedAt);
      if (g != last) rows.add(g);
      last = g;
      rows.add(h);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historie'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Vymazat celou historii sledování',
              icon: const Icon(Symbols.delete),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Vymazat historii sledování?'),
                    content: const Text(
                      'Historie sledování bude z tohoto zařízení vymazána.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(d, false),
                        child: const Text('Zrušit'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(d, true),
                        child: const Text('Vymazat historii'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await lib.clearHistory();
              },
            ),
        ],
      ),
      body: MaxContentWidth(
        child: history.isEmpty
            ? const EmptyView(
                icon: Symbols.history,
                title: 'Mějte přehled o sledovaných videích',
                message: 'Zatím zde není žádná historie sledování.',
              )
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => switch (rows[i]) {
                  final String g => Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                      child: Text(
                        g,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  final HistoryEntry h => VideoRow(
                      h.video,
                      onRemove: () {
                        unawaited(lib.removeFromHistory(h.video.id));
                        showSnack(context, 'Odebráno z historie sledování');
                      },
                      removeLabel: 'Odebrat z historie sledování',
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
      ),
    );
  }
}
