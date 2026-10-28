
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Místo, kde jsou zveřejňována vydání (viz .github/workflows/release.yml a docs/updates.md).
const releasesRepo = 'SanuSanal/YouPipe';
const releasesPageUrl = 'https://github.com/$releasesRepo/releases/latest';

/// Informace o nainstalované aplikaci získané od platformy.
class AppInfo {
  const AppInfo({required this.versionName, required this.versionCode, required this.abis, this.device});

  factory AppInfo.fromMap(Map<Object?, Object?> m) => AppInfo(
    versionName: m['versionName'] as String? ?? '0.0.0',
    versionCode: m['versionCode'] as int? ?? 0,
    abis: [for (final a in m['abis'] as List<Object?>? ?? const []) a as String],
    device: m['device'] as String?,
  );

  final String versionName;
  final int versionCode;

  /// „Výrobce Model, Android x (SDK n)“, pro hlášení chyb.
  final String? device;

  /// Podporované ABI seřazené od nejpreferovanějšího (Build.SUPPORTED_ABIS).
  final List<String> abis;
}

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, required this.size, this.sha256});

  factory ReleaseAsset.fromJson(Map<String, dynamic> j) => ReleaseAsset(
    name: j['name'] as String,
    url: j['browser_download_url'] as String,
    size: j['size'] as int? ?? 0,
    sha256: parseSha256Digest(j['digest'] as String?),
  );

  final String name;
  final String url;
  final int size;

  /// SHA-256 v podobě malých hexadecimálních znaků, vypočítaný GitHubem při nahrání,
  /// nebo null, pokud GitHub tento údaj neposkytuje.
  final String? sha256;
}

class ReleaseInfo {
  const ReleaseInfo({required this.tag, required this.notes, required this.pageUrl, required this.assets});

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) => ReleaseInfo(
    tag: j['tag_name'] as String,
    notes: j['body'] as String? ?? '',
    pageUrl: j['html_url'] as String? ?? releasesPageUrl,
    assets: [for (final a in j['assets'] as List? ?? const []) ReleaseAsset.fromJson(a as Map<String, dynamic>)],
  );

  final String tag;

  /// Text poznámek k vydání ve formátu Markdown (vytváří ho proces vydávání nové verze).
  final String notes;
  final String pageUrl;
  final List<ReleaseAsset> assets;

  /// Verze bez úvodního znaku „v“.
  String get version => tag.startsWith('v') ? tag.substring(1) : tag;
}

/// Dostupná aktualizace novější než nainstalovaná verze,
/// s APK vybraným pro tento telefon.
class AvailableUpdate {
  const AvailableUpdate({required this.release, required this.apk});

  final ReleaseInfo release;
  final ReleaseAsset apk;

  String get version => release.version;
}

/// Zpracuje verzi „1.2.3“ nebo „v1.2.3“.
/// Vše za znakem „+“ nebo „-“ se ignoruje. Pokud nejde o verzi, vrátí null.
List<int>? parseVersion(String s) {
  final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(s.trim());
  if (m == null) return null;
  return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
}

/// Vrátí true, pokud je [candidate] novější verzí než [installed].
bool isNewerVersion(String candidate, String installed) {
  final a = parseVersion(candidate);
  final b = parseVersion(installed);
  if (a == null) return false;
  if (b == null) return true;
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Vybere APK pro první ABI telefonu, pro které vydání obsahuje soubor.
/// Názvy souborů končí na „-<abi>.apk“.
ReleaseAsset? pickApk(List<ReleaseAsset> assets, List<String> abis) {
  for (final abi in abis) {
    for (final a in assets) {
      if (a.name.endsWith('-$abi.apk')) return a;
    }
  }
  return null;
}

/// Zpracuje kontrolní součet SHA-256 z údaje GitHubu („sha256:<hex>“).
/// Pokud chybí nebo má jiný formát, vrátí null.
String? parseSha256Digest(String? digest) {
  final m = RegExp(r'^sha256:([0-9a-fA-F]{64})$').firstMatch(digest ?? '');
  return m?.group(1)!.toLowerCase();
}

/// Převede poznámky k vydání na krátký prostý text pro okno aktualizace.
/// Zvládá také starší poznámky generované GitHubem („What's Changed“,
/// „by @user in“ a odkaz na pull request).
String cleanReleaseNotes(String markdown) {
  final lines = <String>[];
  for (var line in markdown.replaceAll('\r\n', '\n').split('\n')) {
    // Přeskočí informaci o výběru APK (aplikace vybere soubor sama) a odkaz na seznam změn.
    if (line.startsWith('**Which APK?**') || line.startsWith('**Full Changelog**')) continue;
    line = line
        .replaceFirst(RegExp(r'^#+\s*'), '')
        .replaceFirst(RegExp(r'^\s*[*-]\s+'), '• ')
        .replaceFirst(RegExp(r' by @\S+ in https://\S+$'), '')
        .replaceAll('**', '')
        .trimRight();
    // Okno aktualizace má vlastní nadpis „Co je nového“.
    if (line == "What's new" || line == "What's Changed") continue;
    if (line.isEmpty && (lines.isEmpty || lines.last.isEmpty)) continue;
    lines.add(line);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

class UpdateException implements Exception {
  UpdateException(this.code, this.message);

  /// NETWORK, NO_APK, HASH_MISMATCH, CANCELLED, SIGNATURE_MISMATCH, DOWNGRADE, INSTALL_FAILED
  final String code;
  final String message;

  @override
  String toString() => 'UpdateException($code): $message';
}

/// Kontroluje dostupnost novější verze na GitHub Releases,
/// stáhne APK pro tento telefon a spustí instalaci.
class Updater {
  Updater({Dio? dio})
    : _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 30)));

  static const _channel = MethodChannel('youpipe/updater');

  final Dio _dio;
  AppInfo? _appInfo;

  Future<AppInfo> appInfo() async =>
      _appInfo ??= AppInfo.fromMap(await _channel.invokeMapMethod<Object?, Object?>('appInfo') ?? const {});

  /// Vrátí nejnovější vydání, pokud je novější než nainstalovaná verze
  /// a obsahuje APK kompatibilní s tímto telefonem.
  Future<AvailableUpdate?> check() async {
    final info = await appInfo();
    final Response<Map<String, dynamic>> res;
    try {
      res = await _dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$releasesRepo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
    } on DioException catch (e) {
      throw UpdateException('NETWORK', e.message ?? e.type.name);
    }
    final release = ReleaseInfo.fromJson(res.data!);
    if (!isNewerVersion(release.version, info.versionName)) return null;
    final apk = pickApk(release.assets, info.abis);
    if (apk == null) throw UpdateException('NO_APK', 'No APK for ${info.abis.join(', ')} in ${release.tag}');
    return AvailableUpdate(release: release, apk: apk);
  }

  Future<Directory> _dir() async => Directory('${(await getTemporaryDirectory()).path}/updates');

  /// Stáhne aktualizační APK a ověří ho pomocí kontrolního součtu SHA-256 od GitHubu.
  /// Vrátí cestu k souboru.
  Future<String> download(
    AvailableUpdate update, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final path = '${dir.path}/${update.apk.name}';
    try {
      await _dio.download(update.apk.url, path, onReceiveProgress: onProgress, cancelToken: cancelToken);
      final expected = update.apk.sha256;
      if (expected != null) {
        final actual = await compute(_sha256Of, path);
        if (actual != expected) throw UpdateException('HASH_MISMATCH', 'The download is damaged');
      }
      return path;
    } on DioException catch (e) {
      await _deleteQuietly(path);
      if (CancelToken.isCancel(e)) throw UpdateException('CANCELLED', 'Download cancelled');
      throw UpdateException('NETWORK', e.message ?? e.type.name);
    } catch (_) {
      await _deleteQuietly(path);
      rethrow;
    }
  }

  /// Předá APK instalačnímu programu Androidu, který požádá uživatele o potvrzení.
  /// Po úspěšné instalaci se aplikace nahradí novou verzí.
  Future<void> install(String path) async {
    try {
      await _channel.invokeMethod<void>('install', {'path': path});
    } on PlatformException catch (e) {
      throw UpdateException(e.code, e.message ?? e.code);
    }
  }

  Future<void> openUrl(String url) => _channel.invokeMethod<void>('openUrl', {'url': url});

  /// Odstraní stažená APK, která už nejsou potřeba po aktualizaci nebo po opuštění procesu aktualizace.
  Future<void> cleanup() async {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<String> _sha256Of(String path) async => (await sha256.bind(File(path).openRead()).first).toString();

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Soubor už neexistuje.
    }
  }
}
