
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, Value, innerJoin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/db/app_database.dart';
import '../../data/video_info.dart';
import '../../innertube/models.dart';
import '../../player/video_player_service.dart';
import '../../providers.dart';
import '../../ui/messenger.dart';
import '../../ui/navigation.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/video_tiles.dart';

class DownloadEntry {
  const DownloadEntry(this.video, this.row);

  final VideoItem video;
  final Download row;

  double get progress => row.sizeBytes > 0 ? (row.downloadedBytes / row.sizeBytes).clamp(0, 1) : 0;
}

/// Offline stahování: Android spouští jednotlivá stahování jako úlohy WorkManageru.
/// Tato třída synchronizuje tabulku Downloads a informuje přehrávač o místních kopiích videí.
class DownloadManager {
  DownloadManager(this._db, this._ref) {
    _sub = watchAll().listen((all) {
      _local = {
        for (final d in all)
          if (d.row.state == DownloadState.done && d.row.path != null)
            d.video.id: LocalVideo(
              d.row.path!,
              VideoInfo.offline(
                videoId: d.video.id,
                title: d.video.title,
                channelName: d.video.channelName,
                channelId: d.video.channelId,
                channelAvatar: d.video.channelAvatar,
              ),
            ),
      };
      if (all.any((d) => d.row.state == DownloadState.queued || d.row.state == DownloadState.downloading)) {
        _poll();
      }
    });
  }

  static const _channel = MethodChannel('youpipe/downloader');

  final AppDatabase _db;
  final Ref _ref;
  StreamSubscription<List<DownloadEntry>>? _sub;
  Map<String, LocalVideo> _local = const {};
  Timer? _timer;

  LocalVideo? localVideo(String videoId) => _local[videoId];

  Future<Directory> _dir() async => Directory('${(await getApplicationSupportDirectory()).path}/downloads');

  Future<void> start(VideoItem video, int height) async {
    await _db.into(_db.videos).insertOnConflictUpdate(videoToCompanion(video));
    await _db
        .into(_db.downloads)
        .insertOnConflictUpdate(
          DownloadsCompanion.insert(
            videoId: video.id,
            state: DownloadState.queued,
            height: height,
            addedAt: DateTime.now(),
          ),
        );
    final settings = _ref.read(settingsProvider);
    await _channel.invokeMethod('enqueue', {
      'videoId': video.id,
      'title': video.title,
      'dir': (await _dir()).path,
      'height': height,
      'hl': settings.hl,
      'gl': settings.gl,
    });
    _poll();
  }

  Future<void> remove(String videoId) async {
    await _channel.invokeMethod('cancel', {'videoId': videoId});
    final row = await (_db.select(_db.downloads)..where((d) => d.videoId.equals(videoId))).getSingleOrNull();
    if (row?.path != null) {
      final f = File(row!.path!);
      if (f.existsSync()) await f.delete();
    }
    await (_db.delete(_db.downloads)..where((d) => d.videoId.equals(videoId))).go();
  }

  /// Každou sekundu kontroluje průběh aktivních stahování a ukládá jejich stav do databáze.
  void _poll() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => sync());
  }

  Future<void> sync() async {
    final List<Map<Object?, Object?>> jobs;
    try {
      jobs = (await _channel.invokeListMethod<Map<Object?, Object?>>('status')) ?? const [];
    } on PlatformException {
      return;
    }
    var active = false;
    var finished = false;
    for (final j in jobs) {
      final id = j['videoId'] as String?;
      if (id == null) continue;
      final row = await (_db.select(_db.downloads)..where((d) => d.videoId.equals(id))).getSingleOrNull();
      // Úloha odstraněného stahování nebo stahování, které už bylo zaznamenáno.
      if (row == null || row.state == DownloadState.done) continue;
      final update = switch (j['state']) {
        'queued' => const DownloadsCompanion(state: Value(DownloadState.queued)),
        'downloading' => DownloadsCompanion(
          state: const Value(DownloadState.downloading),
          downloadedBytes: Value((j['downloaded'] as num?)?.toInt() ?? 0),
          sizeBytes: Value((j['total'] as num?)?.toInt() ?? 0),
        ),
        'done' => DownloadsCompanion(
          state: const Value(DownloadState.done),
          path: Value(j['path'] as String?),
          sizeBytes: Value((j['size'] as num?)?.toInt() ?? 0),
          downloadedBytes: Value((j['size'] as num?)?.toInt() ?? 0),
          height: Value((j['height'] as num?)?.toInt() ?? row.height),
        ),
        'failed' => DownloadsCompanion(state: const Value(DownloadState.failed), error: Value(j['error'] as String?)),
        _ => null,
      };
      if (update == null) continue;
      await (_db.update(_db.downloads)..where((d) => d.videoId.equals(id))).write(update);
      if (j['state'] == 'queued' || j['state'] == 'downloading') active = true;
      if (j['state'] == 'done' && row.state != DownloadState.done) {
        finished = true;
        final title = (await (_db.select(_db.videos)..where((v) => v.videoId.equals(id))).getSingleOrNull())?.title;
        showGlobalSnack('Staženo${title == null ? '' : ': $title'}');
      }
    }
    if (finished) await _channel.invokeMethod('prune');
    if (!active) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Stream<List<DownloadEntry>> watchAll() {
    final q = _db.select(_db.downloads).join([
      innerJoin(_db.videos, _db.videos.videoId.equalsExp(_db.downloads.videoId)),
    ])..orderBy([OrderingTerm.desc(_db.downloads.addedAt)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows) DownloadEntry(videoFromRow(r.readTable(_db.videos)), r.readTable(_db.downloads)),
      ],
    );
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  final m = DownloadManager(ref.watch(databaseProvider), ref);
  ref.read(playerServiceProvider).localVideo = m.localVideo;
  unawaited(m.sync());
  ref.onDispose(m.dispose);
  return m;
});

final downloadsProvider = StreamProvider<List<DownloadEntry>>((ref) => ref.watch(downloadManagerProvider).watchAll());

final downloadOfProvider = Provider.autoDispose.family<DownloadEntry?, String>(
  (ref, videoId) =>
      ref.watch(downloadsProvider.select((all) => all.value?.where((d) => d.video.id == videoId).firstOrNull)),
);

String _size(int bytes) {
  if (bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
}

String _qualityName(int h) => switch (h) {
  >= 1080 => 'Full HD',
  >= 720 => 'Vysoká',
  >= 360 => 'Střední',
  _ => 'Nízká',
};

/// Nabídka „Stáhnout“ v nabídce ⋮ nebo na stránce videa.
Future<void> startDownload(BuildContext context, WidgetRef ref, VideoItem video) async {
  final existing = ref.read(downloadOfProvider(video.id));
  if (existing != null) {
    await _showManage(context, ref, existing);
    return;
  }
  // Požádá o oprávnění k oznámením (Android 13+), aby se zobrazoval průběh.
  unawaited(const MethodChannel('youpipe/system').invokeMethod('requestNotifications'));
  final infoFuture = ref.read(videoInfoServiceProvider).get(video.id);
  final height = await showModalBottomSheet<int>(
    context: context,
    useRootNavigator: true,
    builder: (sheet) => FutureBuilder<VideoInfo>(
      future: infoFuture,
      builder: (sheet, snap) {
        final options = snap.data?.downloadOptions.where((o) => o.$1 <= 1080).toList().reversed.toList();
        return SafeArea(
          // Nabídka zabírá celou šířku i tehdy, když obsahuje jen zprávu.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Kvalita stahování', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    snap.error is VideoUnavailable
                        ? (snap.error! as VideoUnavailable).friendly
                        : 'Toto video se nepodařilo stáhnout',
                  ),
                )
              else if (options == null)
                const Padding(padding: EdgeInsets.all(24), child: LoadingView())
              else
                for (final (h, size) in options)
                  ListTile(
                    leading: const Icon(Symbols.download, weight: 300),
                    title: Text('${_qualityName(h)} (${h}p)'),
                    trailing: Text(_size(size), style: TextStyle(color: sheet.yt.textSecondary)),
                    onTap: () => Navigator.of(sheet).pop(h),
                  ),
            ],
          ),
        );
      },
    ),
  );
  if (height == null) return;
  await ref.read(downloadManagerProvider).start(video, height);
  if (context.mounted) showSnack(context, 'Stahování probíhá…', action: 'Zobrazit', onAction: () => openDownloads(context, ref));
}

Future<void> _showManage(BuildContext context, WidgetRef ref, DownloadEntry d) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  builder: (sheet) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (d.row.state == DownloadState.failed)
          ListTile(
            leading: const Icon(Symbols.refresh),
            title: const Text('Zkusit stáhnout znovu'),
            onTap: () {
              Navigator.of(sheet).pop();
              _retry(ref, d);
            },
          ),
        ListTile(
          leading: const Icon(Symbols.delete),
          title: Text(d.row.state == DownloadState.done ? 'Odstranit ze stažených' : 'Zrušit stahování'),
          onTap: () {
            Navigator.of(sheet).pop();
            ref.read(downloadManagerProvider).remove(d.video.id);
            showSnack(context, 'Odstraněno ze stažených');
          },
        ),
      ],
    ),
  ),
);

void _retry(WidgetRef ref, DownloadEntry d) => ref.read(downloadManagerProvider).start(d.video, d.row.height);

void openDownloads(BuildContext context, WidgetRef ref) {
  ref.read(playerPanelProvider.notifier).collapse();
  context.push('${branchPrefix(context)}/downloads');
}

/// Tlačítko stahování na stránce videa: „Stáhnout“, průběh nebo potvrzení uložení.
Widget downloadPill(BuildContext context, WidgetRef ref, VideoItem video) {
  final d = ref.watch(downloadOfProvider(video.id));
  final (icon, label) = switch (d?.row.state) {
    DownloadState.done => (Symbols.download_done, 'Staženo'),
    DownloadState.downloading => (Symbols.downloading, '${(d!.progress * 100).round()} %'),
    DownloadState.queued => (Symbols.schedule, 'Čeká na stažení'),
    DownloadState.failed => (Symbols.error, 'Chyba stahování'),
    null => (Symbols.download, 'Stáhnout'),
  };
  return PillButton(
    icon: icon,
    label: label,
    filledIcon: d?.row.state == DownloadState.done,
    onTap: () => startDownload(context, ref, video),
  );
}

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(downloadsProvider).value ?? const <DownloadEntry>[];
    final c = context.yt;
    final used = all.fold<int>(0, (sum, d) => sum + (d.row.state == DownloadState.done ? d.row.sizeBytes : 0));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stažená videa'),
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Symbols.arrow_back)),
      ),
      body: MaxContentWidth(
        child: all.isEmpty
            ? const EmptyView(
                icon: Symbols.download,
                title: 'Žádná stažená videa',
                message: 'Videa, která si stáhnete, se zobrazí zde a můžete je přehrávat i bez připojení k internetu.',
              )
            : ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      '${all.length} ${all.length == 1 ? 'video' : all.length >= 2 && all.length <= 4 ? 'videa' : 'videí'} · ${_size(used)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 13),
                    ),
                  ),
                  for (final d in all)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoRow(
                          d.video,
                          onTap: switch (d.row.state) {
                            DownloadState.done => null,
                            DownloadState.failed => () => _retry(ref, d),
                            _ => () => _showManage(context, ref, d),
                          },
                          trailing: MenuButton(onTap: () => _showManage(context, ref, d)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(184, 0, 16, 8),
                          child: switch (d.row.state) {
                            DownloadState.done => Row(
                              children: [
                                Icon(Symbols.download_done, size: 16, color: c.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  '${d.row.height}p · ${_size(d.row.sizeBytes)}',
                                  style: YtText.meta.copyWith(color: c.textSecondary),
                                ),
                              ],
                            ),
                            DownloadState.downloading || DownloadState.queued => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: d.row.state == DownloadState.queued ? null : d.progress,
                                  color: c.link,
                                  minHeight: 3,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d.row.state == DownloadState.queued
                                      ? 'Čeká na zahájení stahování…'
                                      : 'Stahování · ${_size(d.row.downloadedBytes)} z ${_size(d.row.sizeBytes)}',
                                  style: YtText.meta.copyWith(color: c.textSecondary),
                                ),
                              ],
                            ),
                            DownloadState.failed => InkWell(
                              onTap: () => _retry(ref, d),
                              child: Text(
                                'Stahování se nezdařilo. Klepnutím ho zopakujete.',
                                style: YtText.meta.copyWith(color: YtColors.red),
                              ),
                            ),
                          },
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
