
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../innertube/auth.dart';
import '../../innertube/innertube.dart';
import '../../providers.dart';
import '../../ui/navigation.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/video_tiles.dart';

@immutable
class AuthState {
  const AuthState({this.signedIn = false, this.account});

  final bool signedIn;
  final AccountInfo? account;
}

const _cookieKey = 'yt_cookie';
const _cookies = MethodChannel('youpipe/cookies');

/// Přihlášení přes Google (docs/account.md). Přihlášení je volitelné.
/// Relace se ukládá v šifrovaném úložišti a předává se službě InnerTube.
final authProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  static const _storage = FlutterSecureStorage();

  InnerTube get _yt => ref.read(innerTubeProvider);

  @override
  Future<AuthState> build() async {
    final cookie = await _storage.read(key: _cookieKey);
    _yt.cookie = cookie;
    _hookSync();
    if (!_yt.signedIn) return const AuthState();
    try {
      return AuthState(signedIn: true, account: await _yt.accountInfo());
    } catch (e) {
      // Bez připojení nebo při problému YouTube zůstane uživatel přihlášený.
      debugPrint('YouPipe: načtení informací o účtu selhalo: $e');
      return const AuthState(signedIn: true);
    }
  }

  /// Lajky, odběry a videa Přehrát později se synchronizují s účtem.
  /// Místní knihovna zůstává hlavním zdrojem dat.
  void _hookSync() {
    ref.read(libraryProvider).remoteSync = (action, id, on) {
      if (!_yt.signedIn) return;
      final Future<void> call = switch (action) {
        'like' => _yt.like(id, liked: on),
        'subscribe' => _yt.subscribe(id, subscribe: on),
        'watchLater' => _yt.editPlaylist('WL', id, add: on),
        _ => Future.value(),
      };
      call.catchError(
        (Object e) => debugPrint(
          'YouPipe: synchronizace účtu $action selhala: $e',
        ),
      );
    };
  }

  /// Načte cookies z WebView po přechodu na youtube.com.
  /// Vrací false, pokud přihlášení ještě není dokončeno.
  Future<bool> completeSignIn() async {
    final cookie = await _cookies.invokeMethod<String>(
      'get',
      {'url': 'https://www.youtube.com'},
    );
    if (cookie == null || !isSignedInCookie(cookie)) return false;
    await _storage.write(key: _cookieKey, value: cookie);
    _yt.cookie = cookie;
    final account = await _yt.accountInfo().catchError((Object _) => null);
    state = AsyncData(AuthState(signedIn: true, account: account));
    ref.invalidate(homeProvider);
    return true;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _cookieKey);
    _yt.cookie = null;
    await _cookies.invokeMethod<bool>('clear');
    state = const AsyncData(AuthState());
    ref.invalidate(homeProvider);
  }
}

/// Oficiální přihlašovací stránka Googlu, která se po přihlášení vrátí na youtube.com.
/// Přihlašovací údaje zadává uživatel přímo na stránce Googlu.
const _loginUrl =
    'https://accounts.google.com/ServiceLogin?service=youtube&uilel=3&passive=true'
    '&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Dcs'
    '%26next%3Dhttps%253A%252F%252Fwww.youtube.com%252F&hl=cs';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(_loginUrl));
  }

  Future<void> _onPageFinished(String url) async {
    final host = Uri.tryParse(url)?.host ?? '';
    if (_finishing ||
        !(host == 'www.youtube.com' || host == 'm.youtube.com')) {
      return;
    }
    _finishing = true;
    final ok = await ref.read(authProvider.notifier).completeSignIn();
    if (!mounted) return;
    if (ok) {
      context.pop(true);
      showSnack(context, 'Přihlášení proběhlo úspěšně');
    } else {
      _finishing = false;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Přihlášení'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Symbols.close),
          ),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 2,
                    color: YtColors.red,
                  ),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      );
}

/// Hlavička sekce Vy: účet nebo výzva k přihlášení a seznamy z účtu YouTube.
Widget accountHeader(BuildContext context, WidgetRef ref) {
  final auth = ref.watch(authProvider).value ?? const AuthState();
  final c = context.yt;
  final account = auth.account;

  if (!auth.signedIn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: c.chip,
            child: Icon(Symbols.person, size: 40, color: c.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vy',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Vaše knihovna je uložena v tomto zařízení',
                  style: TextStyle(color: c.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push('/login'),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    foregroundColor: c.link,
                    side: BorderSide(color: c.divider),
                  ),
                  icon: const Icon(Symbols.account_circle),
                  label: const Text('Přihlásit se (volitelné)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void open(String browseId, String title) =>
      context.push(
        '${branchPrefix(context)}/account/$browseId?title=${Uri.encodeQueryComponent(title)}',
      );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Avatar(account?.photo, size: 72, name: account?.name),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account?.name ?? 'Přihlášený uživatel',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (account?.handle != null)
                    Text(
                      account!.handle!,
                      style: TextStyle(color: c.textSecondary),
                    ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: c.link,
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (d) => AlertDialog(
                          title: const Text('Odhlásit se?'),
                          content: const Text(
                            'Vaše knihovna v tomto zařízení zůstane zachována.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: const Text('Zrušit'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('Odhlásit se'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await ref.read(authProvider.notifier).signOut();
                      }
                    },
                    child: const Text('Odhlásit se'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('Váš účet YouTube', style: YtText.sectionTitle),
      ),
      ListTile(
        leading: const Icon(Symbols.history, weight: 300),
        title: const Text('Historie YouTube'),
        onTap: () => open('FEhistory', 'Historie YouTube'),
      ),
      ListTile(
        leading: const Icon(Symbols.video_library, weight: 300),
        title: const Text('Playlisty YouTube'),
        onTap: () => open('FEplaylist_aggregation', 'Playlisty'),
      ),
      ListTile(
        leading: const Icon(Symbols.schedule, weight: 300),
        title: const Text('Přehrát později'),
        onTap: () => openPlaylist(context, ref, 'WL'),
      ),
      ListTile(
        leading: const Icon(Symbols.thumb_up, weight: 300),
        title: const Text('Oblíbená videa'),
        onTap: () => openPlaylist(context, ref, 'LL'),
      ),
      ListTile(
        leading: const Icon(Symbols.subscriptions, weight: 300),
        title: const Text('Importovat odběry z účtu'),
        onTap: () => _importAccountSubscriptions(context, ref),
      ),
    ],
  );
}

Future<void> _importAccountSubscriptions(
  BuildContext context,
  WidgetRef ref,
) async {
  showSnack(context, 'Importuji odběry…');
  try {
    final yt = ref.read(innerTubeProvider);
    var page = await yt.subscribedChannels();
    final channels = <ChannelItem>[
      ...page.entries.allItems.whereType<ChannelItem>(),
    ];

    // Načítání dalších stránek, pokud je seznam odběrů dlouhý.
    while (page.continuation != null && channels.length < 5000) {
      page = await yt.browseContinuation(page.continuation!);
      final more = page.entries.allItems.whereType<ChannelItem>().toList();
      if (more.isEmpty) break;
      channels.addAll(more);
    }

    await ref.read(libraryProvider).importSubscriptions(channels);
    unawaited(
      ref.read(subscriptionsFeedServiceProvider).refresh(force: true),
    );

    if (context.mounted) {
      showSnack(
        context,
        channels.isEmpty
            ? 'Ve vašem účtu YouTube nejsou žádné odběry'
            : 'Importováno odběrů: ${channels.length}',
      );
    }
  } catch (e, st) {
    debugPrint('YouPipe: import odběrů z účtu selhal: $e\n$st');
    if (context.mounted) {
      showSnack(context, 'Odběry se nepodařilo importovat');
    }
  }
}

/// Seznam z účtu (historie YouTube, playlisty).
final accountFeedProvider = AsyncNotifierProvider.autoDispose
    .family<AccountFeedController, PagedList<FeedEntry>, String>(
  AccountFeedController.new,
);

class AccountFeedController extends AsyncNotifier<PagedList<FeedEntry>> {
  AccountFeedController(this.browseId);

  final String browseId;

  @override
  Future<PagedList<FeedEntry>> build() async {
    final page = await ref.read(innerTubeProvider).accountFeed(browseId);
    return PagedList(page.entries, continuation: page.continuation);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;

    state = AsyncData(
      PagedList(
        current.items,
        continuation: current.continuation,
        loadingMore: true,
      ),
    );

    try {
      final more = await ref
          .read(innerTubeProvider)
          .browseContinuation(current.continuation!);
      state = AsyncData(
        PagedList(
          [...current.items, ...more.entries],
          continuation: more.continuation,
        ),
      );
    } catch (_) {
      state = AsyncData(
        PagedList(current.items, continuation: current.continuation),
      );
    }
  }
}

class AccountFeedScreen extends ConsumerWidget {
  const AccountFeedScreen({
    super.key,
    required this.browseId,
    required this.title,
  });

  final String browseId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(accountFeedProvider(browseId));
    final entries = feed.value?.items ?? const <FeedEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: feed.hasError && entries.isEmpty
          ? ErrorView(
              error: feed.error!,
              onRetry: () => ref.invalidate(accountFeedProvider(browseId)),
            )
          : feed.isLoading && entries.isEmpty
              ? const LoadingView()
              : LoadMoreListener(
                  onLoadMore: () => ref
                      .read(accountFeedProvider(browseId).notifier)
                      .loadMore(),
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, i) => switch (entries[i]) {
                      ItemEntry(item: final VideoItem v) => VideoRow(v),
                      final e => FeedEntryView(e),
                    },
                  ),
                ),
    );
  }
}
