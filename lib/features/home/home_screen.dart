import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/home_feed.dart';
import '../../innertube/models.dart';
import '../../providers.dart';
import '../../ui/navigation.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/top_bar.dart';
import '../../ui/widgets/video_tiles.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  static const _refreshInterval = Duration(minutes: 30);
  static const _topTolerance = 24.0;

  final ScrollController _scrollController = ScrollController();
  Timer? _refreshTimer;
  bool _refreshPending = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleRefresh();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;

    _refreshTimer = Timer(_refreshInterval, () {
      _refreshPending = true;
      _refreshIfSafe();
    });
  }

  void _onScroll() {
    if (_refreshPending && _isAtTop) {
      _refreshIfSafe();
    }
  }

  bool get _isAtTop {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + _topTolerance;
  }

  Future<void> _refreshIfSafe() async {
    if (!_refreshPending ||
        _refreshing ||
        !_isAtTop ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
        ref.read(currentTabProvider) != 0) {
      return;
    }

    _refreshPending = false;
    _refreshing = true;
    try {
      ref.invalidate(homeShortsProvider);
      ref.invalidate(homeProvider);
      await ref.read(homeProvider.future);
      await ref.read(homeShortsProvider.future);
    } catch (_) {
      // Keep the app usable if the network is unavailable; the next interval retries.
    } finally {
      _refreshing = false;
      _scheduleRefresh();
    }
  }

  Future<void> _manualRefresh() async {
    _refreshPending = false;
    _refreshTimer?.cancel();
    _refreshing = true;
    try {
      ref.invalidate(homeShortsProvider);
      ref.invalidate(homeProvider);
      await ref.read(homeProvider.future);
      await ref.read(homeShortsProvider.future);
    } finally {
      _refreshing = false;
      _scheduleRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final chip = ref.watch(homeChipProvider);
    final shorts = ref.watch(homeShortsProvider).value ?? const <VideoItem>[];
    final hasHistory = (ref.watch(historyProvider).value ?? const []).isNotEmpty;
    final hasSubs = (ref.watch(subscriptionsProvider).value ?? const []).isNotEmpty;
    final chips = [
      for (final c in HomeChip.defaults)
        if (c.kind != HomeChipKind.subscriptions || hasSubs) c,
    ];
    final items = home.value?.items ?? const <VideoItem>[];
    // YouTube zobrazuje sekci krátkých videí za několika prvními videi.
    const shelfAt = 2;

    return Scaffold(
      body: StatusBarScrim(
        child: RefreshIndicator(
          color: context.yt.textPrimary,
          onRefresh: _manualRefresh,
          child: LoadMoreListener(
            onLoadMore: () => ref.read(homeProvider.notifier).loadMore(),
            child: Listener(
              onPointerDown: (_) => HomeController.touched = true,
              // I dálkový ovladač se počítá jako ovládání domovské obrazovky.
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: (_, _) {
                  HomeController.touched = true;
                  return KeyEventResult.ignored;
                },
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    YtTopBar(
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(YtSizes.chipHeight + 16),
                        child: ChipBar(
                          children: [
                            for (final c in chips)
                              YtChip(
                                label: c.label,
                                selected: c == chip,
                                onTap: () => ref.read(homeChipProvider.notifier).select(c),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (chip == HomeChip.all && !hasHistory && !hasSubs && home.hasValue)
                      const SliverToBoxAdapter(child: _StartCard()),
                    if (home.isLoading && items.isEmpty)
                      const SliverToBoxAdapter(child: FeedSkeleton())
                    else if (home.hasError && items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: ErrorView(error: home.error!, onRetry: () => ref.invalidate(homeProvider)),
                      )
                    else if (items.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyView(
                          icon: Symbols.search,
                          title: 'Začněte vyhledáváním',
                          message: 'Začněte sledovat videa a my vám připravíme nabídku podle vašich zájmů.',
                          action: FilledButton(
                            onPressed: () => openSearch(context, ref),
                            child: const Text('Hledat'),
                          ),
                        ),
                      )
                    else
                      SliverMainAxisGroup(
                        slivers: [
                          VideosWithShortsSliver(videos: items, shorts: shorts, phoneShelfAt: shelfAt),
                          SliverToBoxAdapter(
                            child: home.value?.loadingMore ?? false
                                ? const Padding(padding: EdgeInsets.all(24), child: LoadingView())
                                : const SizedBox(height: 24),
                          ),
                        ],
                      ),
                    const SliverBottomInset(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Zobrazuje se při první instalaci: nabídka se vytváří v tomto zařízení podle historie sledování a odběrů.
class _StartCard extends ConsumerWidget {
  const _StartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: context.yt.divider),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vaše nabídka videí v tomto zařízení',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          'YouPipe vytváří nabídku videí podle toho, co sledujete a které kanály odebíráte. '
          'Vše se ukládá do tohoto zařízení. Do té doby vám nabízíme oblíbená videa.',
          style: TextStyle(color: context.yt.textSecondary, fontSize: 13),
        ),
      ],
    ),
  );
}
