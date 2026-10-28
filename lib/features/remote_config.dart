
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Nastavení, která lze měnit i bez vydání nové verze aplikace (docs/remote_config.md).
/// Načítá se ze souboru `config/remote.json` ve větvi main.
/// Aktualizuje se nejvýše jednou za 12 hodin. Poslední kopie se ukládá do předvoleb,
/// aby byla dostupná i offline a při spuštění aplikace.
const remoteConfigUrl = 'https://raw.githubusercontent.com/SanuSanal/YouPipe/main/config/remote.json';

/// Nejprve okamžitě použije uloženou konfiguraci a poté ji aktualizuje na pozadí.
/// Poskytovatel se sleduje v kořenové části aplikace.
final remoteConfigProvider = Provider<void>((ref) {
  final prefs = ref.read(prefsProvider);
  void apply(String json) {
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      final version = m['webClientVersion'] as String?;
      // Přijímáme pouze správně formátované verze, aby chybný soubor nerozbil všechny požadavky.
      if (version != null && RegExp(r'^2\.\d{8}\.\d{2}\.\d{2}$').hasMatch(version)) {
        ref.read(innerTubeProvider).clientVersion = version;
      }
    } catch (e) {
      debugPrint('YouPipe: vzdálená konfigurace ignorována: $e');
    }
  }

  final cached = prefs.getString('remoteConfig');
  if (cached != null) apply(cached);
  final last = DateTime.fromMillisecondsSinceEpoch(prefs.getInt('remoteConfigAt') ?? 0);
  if (DateTime.now().difference(last) < const Duration(hours: 12)) return;
  Dio(BaseOptions(receiveTimeout: const Duration(seconds: 10)))
      .get<String>(remoteConfigUrl, options: Options(responseType: ResponseType.plain))
      .then((res) async {
        final body = res.data;
        if (body == null) return;
        apply(body);
        await prefs.setString('remoteConfig', body);
        await prefs.setInt('remoteConfigAt', DateTime.now().millisecondsSinceEpoch);
      })
      .catchError((Object e) => debugPrint('YouPipe: načtení vzdálené konfigurace selhalo: $e'));
});
