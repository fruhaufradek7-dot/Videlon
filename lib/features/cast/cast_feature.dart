
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../innertube/models.dart';
import '../../player/cast.dart';
import '../../providers.dart';
import '../../ui/messenger.dart';
import '../../ui/theme/yt_theme.dart';
import '../../ui/widgets/common.dart';
import '../../util/format.dart';

/// Odesílání videa do Chromecastu a televizí DLNA (docs/cast.md).
/// Telefon předává televizi video YouTube nebo stažený soubor.
final castControllerProvider = Provider<CastController>((ref) => CastController());

final castStatusProvider = Provider<CastStatus>((ref) {
  final status = ref.watch(castControllerProvider).status;
  void changed() => ref.invalidateSelf();
  status.addListener(changed);
  ref.onDispose(() => status.removeListener(changed));
  return status.value;
});

/// Aktuální stav přehrávače na připojeném zařízení.
final remotePlayerProvider = StreamProvider<RemotePlayer>((ref) => ref.watch(castControllerProvider).player);

/// Předává aktuální video připojenému zařízení a pozastaví přehrávání v telefonu.
/// Po skončení videa pokračuje ve frontě. Po odpojení vrátí přehrávání do telefonu.
final castBridgeProvider = Provider<void>((ref) {
  final cast = ref.watch(castControllerProvider);
  String? loadedId;
  Duration lastPosition = Duration.zero;

  Future<void> loadCurrent() async {
    final now = ref.read(playbackProvider);
    final svc = ref.read(playerServiceProvider);
    if (now == null || !cast.status.value.connected) return;
    final c = svc.controller.value;
    final position = c?.value.position ?? Duration.zero;
    await c?.pause();
    if (loadedId == now.video.id) return;
    loadedId = now.video.id;
    final v = now.video;
    try {
      await cast.load(
        item: MediaItem(
          id: v.id,
          title: v.title,
          artist: v.channelName,
          artUri: Uri.parse(v.thumbnailOrDefault),
          duration: c?.value.duration,
        ),
        localPath: svc.localVideo?.call(v.id)?.path,
        position: position,
      );
    } catch (e) {
      loadedId = null;
      showGlobalSnack('Toto video se nepodařilo přehrát na televizi');
    }
  }

  ref.listen(castStatusProvider, (prev, next) {
    if (next.connected && prev?.connected != true) {
      unawaited(loadCurrent());
    } else if (!next.connected && prev?.connected == true) {
      // Návrat k telefonu na místě, kde televize skončila.
      loadedId = null;
      final c = ref.read(playerServiceProvider).controller.value;
      if (lastPosition > Duration.zero) unawaited(c?.seekTo(lastPosition));
    }
  });
  // Nové video se předá také připojenému zařízení.
  ref.listen(playbackProvider.select((p) => p?.video.id), (_, _) => unawaited(loadCurrent()));
  ref.listen(playerControllerProvider, (_, c) {
    if (c != null && cast.status.value.connected) unawaited(c.pause());
  });
  final sub = cast.player.listen((p) {
    lastPosition = p.position;
    if (p.finished && cast.status.value.connected) {
      loadedId = null;
      unawaited(ref.read(playbackProvider.notifier).next(force: false));
    }
  });
  ref.onDispose(sub.cancel);
});

/// Tlačítko pro připojení k televizi.
class CastButton extends ConsumerWidget {
  const CastButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(castStatusProvider);
    if (status.state == CastState.none) return const SizedBox.shrink();
    return IconButton(
      tooltip: status.connected ? 'Přehrává se na zařízení ${status.device ?? 'zařízení'}' : 'Přehrát na jiném zařízení',
      icon: Icon(
        status.connected ? Symbols.cast_connected : Symbols.cast,
        color: color,
        weight: 300,
        fill: status.connected ? 1 : 0,
      ),
      onPressed: () => showCastSheet(context),
    );
  }
}

Future<void> showCastSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => const _CastSheet(),
);

class _CastSheet extends ConsumerStatefulWidget {
  const _CastSheet();

  @override
  ConsumerState<_CastSheet> createState() => _CastSheetState();
}

class _CastSheetState extends ConsumerState<_CastSheet> {
  @override
  void initState() {
    super.initState();
    ref.read(castControllerProvider).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final cast = ref.watch(castControllerProvider);
    final status = ref.watch(castStatusProvider);
    final c = context.yt;
    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: cast.devices,
        builder: (context, devices, _) => ValueListenableBuilder(
          valueListenable: cast.connectedDevice,
          builder: (context, connected, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  status.connected ? 'Přehrává se na zařízení ${status.device ?? 'zařízení'}' : 'Vyberte zařízení',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
              if (status.connected && status.volumeControl)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Symbols.volume_down, color: c.textSecondary),
                      Expanded(
                        child: Slider(value: status.volume.clamp(0.0, 1.0), onChanged: cast.setVolume),
                      ),
                      Icon(Symbols.volume_up, color: c.textSecondary),
                    ],
                  ),
                ),
              for (final device in devices)
                ListTile(
                  leading: Icon(
                    device.kind == CastKind.chromecast ? Symbols.cast : Symbols.tv,
                    color: device == connected ? c.link : null,
                  ),
                  title: Text(device.name),
                  subtitle: Text(
                    device == connected
                        ? (status.connected ? 'Připojeno' : 'Připojování…')
                        : device.kind == CastKind.chromecast
                        ? 'Chromecast'
                        : 'Chytrá televize (DLNA)',
                  ),
                  onTap: device == connected
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          cast.connect(device);
                        },
                ),
              if (devices.isEmpty)
                const ListTile(
                  leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  title: Text('Vyhledávám zařízení ve vaší Wi-Fi…'),
                  subtitle: Text('Telefon i televize musí být připojené ke stejné Wi-Fi'),
                ),
              if (connected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        cast.disconnect();
                      },
                      child: const Text('Odpojit'),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ovládání přehrávání, pozastavení a posunu při přehrávání na televizi.
class CastRemote implements RemoteControls {
  CastRemote(this._cast, this._player, this.deviceName);

  final CastController _cast;
  final RemotePlayer? _player;

  @override
  final String deviceName;

  @override
  bool get playing => _player?.playing ?? false;

  @override
  Duration get position => _player?.position ?? Duration.zero;

  @override
  Duration? get duration => _player?.duration;

  @override
  Future<void> togglePlay() => playing ? _cast.pause() : _cast.play();

  @override
  Future<void> seek(Duration d) => _cast.seek(d);
}

RemoteControls? castRemoteOf(WidgetRef ref) {
  final status = ref.watch(castStatusProvider);
  if (!status.connected) return null;
  return CastRemote(
    ref.read(castControllerProvider),
    ref.watch(remotePlayerProvider).value,
    status.device ?? 'vaše televize',
  );
}

/// Obrazovka přehrávání na televizi: náhled videa, název zařízení a ovládání.
Widget castingView(BuildContext context, WidgetRef ref, RemoteControls remote, VideoItem? video) {
  final total = remote.duration?.inMilliseconds ?? 0;
  return Stack(
    fit: StackFit.expand,
    children: [
      if (video != null) YtImage(video.thumbnailOrDefault),
      ColoredBox(color: Colors.black.withValues(alpha: 0.7)),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Symbols.cast_connected, color: Colors.white, fill: 1, size: 32),
          const SizedBox(height: 8),
          Text('Přehrává se na zařízení ${remote.deviceName}', style: const TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(height: 4),
          IconButton(
            onPressed: remote.togglePlay,
            iconSize: 48,
            icon: Icon(remote.playing ? Symbols.pause : Symbols.play_arrow, fill: 1, color: Colors.white),
          ),
        ],
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 4,
        child: Row(
          children: [
            Text(
              '${formatDuration(remote.position)} / ${formatDuration(remote.duration ?? Duration.zero)}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Expanded(
              child: Slider(
                value: total <= 0 ? 0 : (remote.position.inMilliseconds / total).clamp(0, 1),
                onChanged: total <= 0 ? null : (v) => remote.seek(Duration(milliseconds: (v * total).round())),
              ),
            ),
            const CastButton(color: Colors.white),
          ],
        ),
      ),
    ],
  );
}
