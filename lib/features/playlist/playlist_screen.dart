import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../innertube/models.dart';
import '../../providers.dart';
import '../../ui/navigation.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/video_menu.dart';
import '../../ui/widgets/video_tiles.dart';

/// Hlavička playlistu z YouTube nebo místního playlistu.
class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader({
    super.key,
    required this.title,
    this.thumbnail,
    this.owner,
    this.onOwner,
    this.meta = const [],
    required this.onPlayAll,
    required this.onShuffle,
    this.actions = const [],
    this.icon,
  });

  final String title;
  final String? thumbnail;
  final String? owner;
  final VoidCallback? onOwner;
  final List<String> meta;
  final VoidCallback? onPlayAll;
  final VoidCallback? onShuffle;
  final List<Widget> actions;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.yt;
    return Stack(
      children: [
        if (thumbnail != null)
          Positioned.fill(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: ImageFiltered(
                imageFilter: ColorFilter.mode(
                  c.background.withValues(alpha: 0.35),
                  BlendMode.srcOver,
                ),
                child: YtImage(thumbnail, fit: BoxFit.cover),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: MediaQuery.sizeOf(context).width * 0.75,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: thumbnail != null
                          ? YtImage(thumbnail)
                          : ColoredBox(
                              color: c.chip,
                              child: Icon(
                                icon ?? Symbols.playlist_play,
                                size: 56,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              if (owner != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onOwner,
                  child: Text(
                    'Autor: $owner',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta.join(' · '),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onPlayAll,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.subscribe,
                        foregroundColor: c.onSubscribe,
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Symbols.play_arrow, fill: 1),
                      label: const Text(
                        'Přehrát vše',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onShuffle,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.chip,
                        foregroundColor: c.textPrimary,
                        minimumSize: const Size(0, 40),
                      ),
                      icon: const Icon(Symbols.shuffle),
                      label: const Text(
                        'Náhodné přehrávání',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: context.yt.chip,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, fill: filled ? 1 : 0),
          ),
        ),
      );
}

void _playList(
  BuildContext context,
  WidgetRef ref,
  List<VideoItem> videos, {
  bool shuffle = false,
}) {
  final list = videos.where((v) => !v.isShort).toList();
  if (list.isEmpty) return;
  if (shuffle) list.shuffle();
  playVideo(context, ref, list.first, queue: list);
}

/// Playlist z YouTube.
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(playlistProvider(playlistId));
    final videos = ref.watch(playlistVideosProvider(playlistId));
    final saved =
        ref.watch(isPlaylistSavedProvider(playlistId)).value ?? false;
    final items = videos.value?.items.whereType<VideoItem>().toList() ??
        const <VideoItem>[];
    final p = page.value;

    Future<void> play({bool shuffle = false}) async {
      final all =
          await ref.read(playlistVideosProvider(playlistId).notifier).all();
      if (context.mounted) {
        _playList(context, ref, all, shuffle: shuffle);
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: page.hasError
            ? ErrorView(
                error: page.error!,
                onRetry: () => ref.invalidate(playlistProvider(playlistId)),
              )
            : p == null
                ? const LoadingView()
                : LoadMoreListener(
                    onLoadMore: () => ref
                        .read(playlistVideosProvider(playlistId).notifier)
                        .loadMore(),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: PlaylistHeader(
                            title: p.title,
                            thumbnail: p.thumbnail,
                            owner: p.owner,
                            onOwner: p.ownerId == null
                                ? null
                                : () => openChannel(
                                      context,
                                      ref,
                                      p.ownerId!,
                                    ),
                            meta: p.metadata,
                            onPlayAll: items.isEmpty ? null : play,
                            onShuffle: items.isEmpty
                                ? null
                                : () => play(shuffle: true),
                            actions: [
                              _RoundAction(
                                icon: Symbols.library_add,
                                filled: saved,
                                onTap: () async {
                                  await ref
                                      .read(libraryProvider)
                                      .setPlaylistSaved(p.asItem, !saved);
                                  if (context.mounted) {
                                    showSnack(
                                      context,
                                      saved
                                          ? 'Odebráno z knihovny'
                                          : 'Uloženo do knihovny',
                                    );
                                  }
                                },
                              ),
                              _RoundAction(
                                icon: Symbols.share,
                                onTap: () => SharePlus.instance.share(
                                  ShareParams(
                                    text:
                                        'https://www.youtube.com/playlist?list=$playlistId',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverList.builder(
                          itemCount: items.length,
                          itemBuilder: (context, i) => VideoRow(
                            items[i],
                            onTap: () => playVideo(
                              context,
                              ref,
                              items[i],
                              queue: items,
                              index: i,
                            ),
                          ),
                        ),
                        if (videos.isLoading ||
                            (videos.value?.loadingMore ?? false))
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: LoadingView(),
                            ),
                          ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 24),
                        ),
                        const SliverBottomInset(),
                      ],
                    ),
                  ),
      ),
    );
  }
}

/// Přehrát později, oblíbená videa nebo vlastní playlist.
class LocalPlaylistScreen extends ConsumerWidget {
  const LocalPlaylistScreen({super.key, required this.id});

  final int id;

  static const liked = -1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = id == liked;
    final playlist =
        isLiked ? null : ref.watch(localPlaylistProvider(id)).value;
    final videos = (isLiked
                ? ref.watch(likedVideosProvider)
                : ref.watch(localPlaylistVideosProvider(id)))
            .value ??
        const <VideoItem>[];
    final title = isLiked ? 'Oblíbená videa' : playlist?.name ?? '';
    final userMade =
        !isLiked && playlist != null && !playlist.isWatchLater;
    final lib = ref.read(libraryProvider);

    void remove(VideoItem v) {
      unawaited(
        isLiked
            ? lib.setLiked(v, false)
            : lib.removeFromPlaylist(id, v.id),
      );
      showSnack(context, 'Odebráno z playlistu $title');
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
        actions: [
          if (userMade)
            PopupMenuButton<String>(
              icon: const Icon(Symbols.more_vert),
              onSelected: (a) async {
                if (a == 'rename') {
                  final name = await promptText(
                    context,
                    title: 'Přejmenovat playlist',
                    initial: playlist.name,
                  );
                  if (name != null && name.trim().isNotEmpty) {
                    await lib.renamePlaylist(id, name.trim());
                  }
                } else if (a == 'delete') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialog) => AlertDialog(
                      title: const Text('Smazat playlist?'),
                      content: Text(
                        'Playlist „${playlist.name}“ bude trvale smazán.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Zrušit'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Smazat'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await lib.deletePlaylist(id);
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Přejmenovat'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Smazat playlist'),
                ),
              ],
            ),
        ],
      ),
      body: MaxContentWidth(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PlaylistHeader(
                title: title,
                thumbnail: videos.firstOrNull?.thumbnailOrDefault,
                icon: isLiked ? Symbols.thumb_up : Symbols.schedule,
                meta: [
                  if (userMade) 'Soukromý playlist' else 'Playlist',
                  '${videos.length} ${videos.length == 1 ? 'video' : videos.length >= 2 && videos.length <= 4 ? 'videa' : 'videí'}',
                ],
                onPlayAll: videos.isEmpty
                    ? null
                    : () => _playList(context, ref, videos),
                onShuffle: videos.isEmpty
                    ? null
                    : () => _playList(
                          context,
                          ref,
                          videos,
                          shuffle: true,
                        ),
              ),
            ),
            if (videos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  icon: isLiked ? Symbols.thumb_up : Symbols.video_library,
                  title: 'V tomto playlistu zatím nejsou žádná videa',
                  message: isLiked
                      ? 'Videa, která označíš jako oblíbená, se zobrazí zde.'
                      : 'Videa můžeš přidávat pomocí nabídky ⋮.',
                ),
              )
            else if (userMade || playlist?.isWatchLater == true)
              SliverReorderableList(
                itemCount: videos.length,
                onReorderItem: (from, to) =>
                    lib.movePlaylistItem(id, from, to),
                itemBuilder: (context, i) =>
                    ReorderableDelayedDragStartListener(
                  key: ValueKey(videos[i].id),
                  index: i,
                  child: VideoRow(
                    videos[i],
                    onTap: () => playVideo(
                      context,
                      ref,
                      videos[i],
                      queue: videos,
                      index: i,
                    ),
                    onRemove: () => remove(videos[i]),
                    removeLabel: 'Odebrat z playlistu $title',
                  ),
                ),
              )
            else
              SliverList.builder(
                itemCount: videos.length,
                itemBuilder: (context, i) => VideoRow(
                  videos[i],
                  onTap: () => playVideo(
                    context,
                    ref,
                    videos[i],
                    queue: videos,
                    index: i,
                  ),
                  onRemove: () => remove(videos[i]),
                  removeLabel: 'Odebrat z playlistu $title',
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            const SliverBottomInset(),
          ],
        ),
      ),
    );
  }
}

/// Samostatný přehled playlistů v knihovně.
class PlaylistLibraryScreen extends ConsumerWidget {
  const PlaylistLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.yt;
    final liked = ref.watch(likedVideosProvider).value ?? const <VideoItem>[];

    // Typ seznamu se odvodí přímo z localPlaylistsProvider.
    final playlists = ref.watch(localPlaylistsProvider).value ?? [];

    final saved =
        ref.watch(savedPlaylistsProvider).value ?? const <PlaylistItem>[];

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      String? thumbnail,
    }) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: thumbnail != null
                      ? YtImage(thumbnail, fit: BoxFit.cover)
                      : ColoredBox(
                          color: c.chip,
                          child: Icon(
                            icon,
                            color: c.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Symbols.chevron_right,
                color: c.textSecondary,
              ),
            ],
          ),
        ),
      );
    }

    final watchLater = playlists.where(
      (p) => p.playlist.isWatchLater,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlisty'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Text(
                'Tvoje playlisty',
                style: YtText.sectionTitle,
              ),
            ),
            row(
              icon: Symbols.thumb_up,
              title: 'Oblíbená videa',
              subtitle: '${liked.length} videí',
              thumbnail: liked.firstOrNull?.thumbnailOrDefault,
              onTap: () => context.push(
                '${branchPrefix(context)}/local/${LocalPlaylistScreen.liked}',
              ),
            ),
            for (final p in watchLater)
              row(
                icon: Symbols.schedule,
                title: 'Přehrát později',
                subtitle: '${p.count} videí',
                thumbnail: p.thumbnail,
                onTap: () => openLocalPlaylist(
                  context,
                  ref,
                  p.playlist.id,
                ),
              ),
            for (final p in playlists.where(
              (p) => !p.playlist.isWatchLater,
            ))
              row(
                icon: Symbols.playlist_play,
                title: p.playlist.name,
                subtitle: 'Soukromý · ${p.count} videí',
                thumbnail: p.thumbnail,
                onTap: () => openLocalPlaylist(
                  context,
                  ref,
                  p.playlist.id,
                ),
              ),
            if (saved.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Text(
                  'Uložené playlisty',
                  style: YtText.sectionTitle,
                ),
              ),
              for (final s in saved)
                row(
                  icon: Symbols.playlist_play,
                  title: s.title,
                  subtitle: s.channelName ?? 'Playlist',
                  thumbnail: s.thumbnail,
                  onTap: () => openPlaylist(context, ref, s.id),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
