import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../providers.dart';
import '../../ui/widgets/common.dart';

class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  static final extraActions = <Widget Function(BuildContext, WidgetRef)>[];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('VIDELON DEBUG: ChannelsScreen build');

    final subscriptions = ref.watch(subscriptionsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Diagnostika odběrů'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Symbols.arrow_back),
        ),
      ),
      body: MaxContentWidth(
        child: subscriptions.when(
          loading: () {
            debugPrint('VIDELON DEBUG: subscriptions loading');
            return const Center(
              child: Text(
                'DIAGNOSTIKA: Načítání odběrů…',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
            );
          },
          error: (error, stackTrace) {
            debugPrint('VIDELON DEBUG: subscriptions error: $error');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'DIAGNOSTIKA: CHYBA\n$error',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          },
          data: (subs) {
            debugPrint(
              'VIDELON DEBUG: subscriptions data: ${subs.length}',
            );

            if (subs.isEmpty) {
              return const Center(
                child: Text(
                  'DIAGNOSTIKA: Seznam odběrů je prázdný.',
                  style: TextStyle(color: Colors.black, fontSize: 18),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'DIAGNOSTIKA OK\nNačteno odběrů: ${subs.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: subs.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: Avatar(
                        subs[i].avatar,
                        size: 40,
                        name: subs[i].name,
                      ),
                      title: Text(
                        subs[i].name,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
