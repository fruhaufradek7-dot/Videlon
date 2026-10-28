
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/yt_theme.dart';
import 'update.dart';
import 'updater.dart';

/// „Je dostupná aktualizace“: seznam novinek a možnosti Později / Přeskočit tuto verzi / Aktualizovat.
/// Aktualizace stáhne APK pro toto zařízení, ověří ji a otevře instalační obrazovku Androidu.
/// Zavřením okna se stahování nezastaví.
Future<void> showUpdateSheet(BuildContext context, AvailableUpdate update) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (_) => SafeArea(child: _UpdateSheet(update)),
);

String _mb(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _UpdateSheet extends ConsumerWidget {
  const _UpdateSheet(this.update);

  final AvailableUpdate update;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateProvider);
    final controller = ref.read(updateProvider.notifier);
    final theme = Theme.of(context);
    final notes = cleanReleaseNotes(update.release.notes);

    final Widget actions = switch (state) {
      UpdateDownloading(:final received, :final total, :final progress) => _Progress(
        label: total > 0 ? 'Stahování… ${_mb(received)} z ${_mb(total)}' : 'Stahování…',
        value: progress,
        onCancel: controller.cancelDownload,
      ),
      UpdateInstalling() => const _Progress(label: 'Otevírám instalační program…'),
      UpdateFailed(:final error) => _Failure(
        error: error,
        onRetry: () => controller.downloadAndInstall(update),
        onOpenReleases: () => ref.read(updaterProvider).openUrl(update.release.pageUrl),
      ),
      // Přeskočit vlevo, Později a Aktualizovat vpravo. Při větším písmu se tlačítka
      // zalomí do dvou řádků, aby nepřetékala mimo obrazovku.
      _ => OverflowBar(
        alignment: MainAxisAlignment.spaceBetween,
        overflowAlignment: OverflowBarAlignment.end,
        children: [
          TextButton(
            onPressed: () async {
              await controller.skip(update);
              if (context.mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: context.yt.textSecondary),
            child: const Text('Přeskočit tuto verzi'),
          ),
          OverflowBar(
            spacing: 8,
            overflowAlignment: OverflowBarAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: context.yt.textPrimary),
                child: const Text('Později'),
              ),
              FilledButton(
                onPressed: () => controller.downloadAndInstall(update),
                style: FilledButton.styleFrom(
                  backgroundColor: context.yt.textPrimary,
                  foregroundColor: context.yt.background,
                  shape: const StadiumBorder(),
                ),
                child: const Text('Aktualizovat'),
              ),
            ],
          ),
        ],
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Je dostupná aktualizace', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Verze ${update.version} • ${_mb(update.apk.size)}', style: theme.textTheme.bodyMedium),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Co je nového', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
              child: SingleChildScrollView(child: Text(notes, style: theme.textTheme.bodyMedium)),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => ref.read(updaterProvider).openUrl(update.release.pageUrl),
              style: TextButton.styleFrom(foregroundColor: context.yt.textSecondary, padding: EdgeInsets.zero),
              child: const Text('Úplné poznámky k vydání'),
            ),
          ),
          const SizedBox(height: 8),
          actions,
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, this.value, this.onCancel});

  final String label;
  final double? value;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LinearProgressIndicator(
        value: value,
        color: YtColors.red,
        backgroundColor: context.yt.divider,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          if (onCancel != null)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: context.yt.textPrimary),
              child: const Text('Zrušit'),
            ),
        ],
      ),
    ],
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.onRetry, required this.onOpenReleases});

  final UpdateException error;
  final VoidCallback onRetry;
  final VoidCallback onOpenReleases;

  String get _message => switch (error.code) {
    'NETWORK' => 'Aktualizaci se nepodařilo stáhnout. Zkontrolujte připojení a zkuste to znovu.',
    'HASH_MISMATCH' => 'Stažený soubor je poškozený. Zkuste to znovu.',
    'SIGNATURE_MISMATCH' =>
      'Tato verze aplikace YouPipe byla nainstalována z jiného sestavení, proto ji Android nemůže aktualizovat. '
          'Odinstalujte ji a poté nainstalujte nejnovější verzi z GitHubu.',
    'DOWNGRADE' => 'Nainstalovaná verze je novější než tato aktualizace.',
    _ => 'Aktualizaci se nepodařilo nainstalovat (${error.message}).',
  };

  @override
  Widget build(BuildContext context) {
    final reinstall = error.code == 'SIGNATURE_MISMATCH' || error.code == 'DOWNGRADE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.yt.textPrimary)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: reinstall ? onOpenReleases : onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: context.yt.textPrimary,
              foregroundColor: context.yt.background,
              shape: const StadiumBorder(),
            ),
            child: Text(reinstall ? 'Otevřít GitHub' : 'Zkusit znovu'),
          ),
        ),
      ],
    );
  }
}
