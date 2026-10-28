
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../innertube/models.dart';
import '../util/format.dart';
import 'db/app_database.dart';

/// Video nahrané na odebíraném kanálu, načtené z jeho RSS kanálu.
class FeedVideo {
  const FeedVideo(this.video, this.publishedAt, this.views);

  final VideoItem video;
  final DateTime publishedAt;
  final int? views;
}

/// Seznam videí z odběrů bez přihlášeného účtu (docs/data.md):
/// RSS kanál každého odebíraného kanálu `feeds/videos.xml?channel_id=`
/// (jeho 15 nejnovějších videí), uložený v mezipaměti `FeedVideos`.
class SubscriptionsFeed {
  SubscriptionsFeed(this.db, {Dio? dio}) : _dio = dio ?? Dio(BaseOptions(receiveTimeout: const Duration(seconds: 20)));

  final AppDatabase db;
  final Dio _dio;

  /// Obnovení probíhá nejvýše jednou za tento interval, pokud není vynuceno.
  static const minInterval = Duration(minutes: 30);
  DateTime? _lastRefresh;
  Future<void>? _running;

  final refreshing = ValueNotifier(false);

  Future<void> refresh({bool force = false}) {
    if (!force && _lastRefresh != null && DateTime.now().difference(_lastRefresh!) < minInterval) {
      return Future.value();
    }
    return _running ??= _refresh().whenComplete(() {
      _running = null;
    });
  }

  Future<void> _refresh() async {
    refreshing.value = true;
    try {
      final subs = await db.select(db.subscriptions).get();
      // Zpracovávat šest kanálů současně: rychle a bez zbytečného zatěžování YouTube.
      var next = 0;
      Future<void> worker() async {
        while (next < subs.length) {
          final s = subs[next++];
          try {
            await _fetch(s.channelId, s.name);
          } catch (e) {
            debugPrint('YouPipe: Načtení RSS kanálu ${s.channelId} se nezdařilo: $e');
          }
        }
      }

      await Future.wait([for (var i = 0; i < 6; i++) worker()]);
      // Zachovat pouze videa z posledních 60 dní.
      await (db.delete(
        db.feedVideos,
      )..where((f) => f.publishedAt.isSmallerThanValue(DateTime.now().subtract(const Duration(days: 60))))).go();
      _lastRefresh = DateTime.now();
    } finally {
      refreshing.value = false;
    }
  }

  Future<void> _fetch(String channelId, String channelName) async {
    final res = await _dio.get<String>(
      'https://www.youtube.com/feeds/videos.xml',
      queryParameters: {'channel_id': channelId},
      options: Options(responseType: ResponseType.plain),
    );
    final entries = parseRss(res.data ?? '', channelId: channelId, channelName: channelName);
    await db.batch((b) {
      for (final e in entries) {
        b.insert(db.feedVideos, e, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Vrátí seznam videí od nejnovějších po nejstarší
  /// včetně avatarů kanálů z tabulky `Subscriptions`.
  Stream<List<FeedVideo>> watch({int limit = 300}) {
    final q =
        db.select(db.feedVideos).join([
            innerJoin(db.subscriptions, db.subscriptions.channelId.equalsExp(db.feedVideos.channelId)),
          ])
          ..orderBy([OrderingTerm.desc(db.feedVideos.publishedAt)])
          ..limit(limit);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          () {
            final f = r.readTable(db.feedVideos);
            final s = r.readTable(db.subscriptions);
            return FeedVideo(
              VideoItem(
                id: f.videoId,
                title: f.title,
                channelName: s.name,
                channelId: f.channelId,
                channelAvatar: s.avatar,
                thumbnail: f.thumbnail,
                viewsText: f.views == null ? null : viewsLabel(f.views!),
                publishedText: timeAgo(f.publishedAt),
                isShort: f.isShort,
              ),
              f.publishedAt,
              f.views,
            );
          }(),
      ],
    );
  }
}

/// Převede Atom RSS kanálu na záznamy `FeedVideos`.
List<FeedVideosCompanion> parseRss(String xml, {required String channelId, required String channelName}) {
  final doc = XmlDocument.parse(xml);
  return [
    for (final e in doc.findAllElements('entry'))
      if (e.getElement('yt:videoId')?.innerText case final id?)
        FeedVideosCompanion.insert(
          videoId: id,
          channelId: channelId,
          channelName: e.getElement('author')?.getElement('name')?.innerText ?? channelName,
          title: e.getElement('title')?.innerText ?? '',
          publishedAt: DateTime.tryParse(e.getElement('published')?.innerText ?? '') ?? DateTime.now(),
          thumbnail: Value(
            e.getElement('media:group')?.getElement('media:thumbnail')?.getAttribute('url') ??
                'https://i.ytimg.com/vi/$id/hqdefault.jpg',
          ),
          views: Value(
            int.tryParse(
              e
                      .getElement('media:group')
                      ?.getElement('media:community')
                      ?.getElement('media:statistics')
                      ?.getAttribute('views') ??
                  '',
            ),
          ),
          isShort: Value(e.getElement('link')?.getAttribute('href')?.contains('/shorts/') ?? false),
        ),
  ];
}
