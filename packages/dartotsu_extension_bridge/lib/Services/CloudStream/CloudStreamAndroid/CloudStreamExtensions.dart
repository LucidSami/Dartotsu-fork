import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../Extensions/DownloadablePlugin.dart';
import '../../../Extensions/ExtensionBridge.dart';
import '../../../Logger.dart';
import '../../../NetworkClient.dart';
import '../../../Settings/KvStore.dart';
import '../../../dartotsu_extension_bridge.dart';
import '../../Network.dart';
import '../../Shared/TachiyomiRepo.dart';
import '../CloudStreamSourceMethods.dart';
import 'Models/CloudStreamSource.dart';

class CloudStreamExtensions extends Extension {
  @override
  String get id => 'cloudstream';

  @override
  String get name => 'CloudStream';

  @override
  String get icon =>
      "packages/dartotsu_extension_bridge/assets/images/cloudstream.png";

  @override
  bool get supportsNovel => false;

  @override
  bool get supportsManga => false;

  @override
  (Type, SourceMethods Function(Source)) get sourceMethodFactories => (
    CSource,
    (source) => CloudStreamSourceMethods(
      source as CSource,
      MethodChannelBridge(platform),
    ),
  );

  @override
  DownloadablePlugin plugin = CloudStreamPlugin();

  static const platform = MethodChannel('cloudstreamExtensionBridge');
  final _client = MClient.init();

  final _context = DartotsuExtensionBridge.context;

  Future<Directory> _getPluginDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, 'cloudstream_plugins'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  Future<bool> onInitialize() async {
    if (Platform.isAndroid) {
      plugin.installed.value = true; // Built-in on Android
    } else {
      plugin.installed.value = await plugin.isInstalled();
      if (!plugin.installed.value) return false;
    }

    try {
      await platform.invokeMethod('initialize');
    } catch (_) {}

    await loadPersistedPlugins();

    try {
      await BridgeChannels.init();
    } catch (_) {}
    if (_context.network != null) {
      try {
        await platform.invokeMethod(
          'initClient',
          jsonEncode({
            'dns': _context.network?.dns,
            'proxy': _context.network?.proxy,
            'userAgent': _context.network?.userAgent,
          }),
        );
      } catch (_) {
        // initClient may not be implemented on all native backends
      }
    }
    return true;
  }

  Future<void> loadPersistedPlugins() async {
    try {
      final dir = await _getPluginDirectory();
      if (await dir.exists()) {
        final allFiles = dir.listSync().whereType<File>();
        for (final file in allFiles) {
          if (file.path.contains('.old_') || file.path.endsWith('.tmp')) {
            try {
              await file.delete();
            } catch (_) {}
          }
        }

        final files = allFiles.where((f) => f.path.endsWith('.cs3'));
        for (final file in files) {
          try {
            await platform.invokeMethod('loadPlugin', {'path': file.path});
            Logger.log("Loaded persisted CloudStream plugin: ${file.path}");
          } catch (e) {
            Logger.log("Failed to load persisted CloudStream plugin ${file.path}: $e");
          }
        }
      }
    } catch (e) {
      Logger.log("Error loading persisted CloudStream plugins: $e");
    }
  }

  @override
  Future<void> fetchInstalledAnimeExtensions() async {
    await super.fetchInstalledAnimeExtensions();
    try {
      final dynamic result = await platform.invokeMethod('getRegisteredProviders');
      if (result == null) return;

      List<dynamic> rawList;
      if (result is String) {
        if (result.isEmpty) return;
        rawList = jsonDecode(result);
      } else if (result is List) {
        rawList = result;
      } else {
        return;
      }

      final List<Source> sources = [];
      for (final e in rawList) {
        final map = Map<String, dynamic>.from(e as Map);
        final internalName = (map['internalName'] ?? map['name'] ?? '').toString();
        final norm = internalName.toLowerCase();

        var metaStr = getVal<String>('cs_meta_$norm');
        if (metaStr == null || metaStr.isEmpty) {
          metaStr = getVal<String>('cs_meta_$internalName');
        }

        Map<String, dynamic>? meta;
        if (metaStr != null && metaStr.isNotEmpty) {
          try {
            meta = jsonDecode(metaStr);
          } catch (_) {}
        }

        sources.add(CSource(
          id: (map['name'] ?? map['id'] ?? internalName).toString().toLowerCase(),
          name: map['name'] ?? internalName,
          baseUrl: map['url'] ?? map['baseUrl'] ?? '',
          lang: meta?['language'] ?? map['language'] ?? map['lang'] ?? 'all',
          iconUrl: meta?['iconUrl'] ?? map['iconUrl'] ?? '',
          version: meta?['version'] ?? map['version']?.toString() ?? '1.0.0',
          versionLast: meta?['versionLast'] ?? map['versionLast']?.toString() ?? '1.0.0',
          itemType: ItemType.anime,
          internalName: internalName,
          pluginUrl: meta?['pluginUrl'] ?? map['plugin'] ?? '',
          repo: meta?['repo'] ?? map['repo'] ?? '',
          hasUpdate: false,
          managerId: 'cloudstream',
        ));
      }

      anime.installed.value = sources;
    } catch (e) {
      Logger.log("Error fetching installed CloudStream extensions: $e");
    }
  }

  @override
  Future<void> fetchAnimeExtensions() async {
    await super.fetchAnimeExtensions();
    anime.available.value = await fetchExtensions(ItemType.anime);
  }

  @override
  Stream<double> addRepo(String repoUrl, ItemType type) {
    return progressStream((_) => _addRepoImpl(repoUrl, type));
  }

  Future<void> _addRepoImpl(String repoUrl, ItemType type) async {
    var inputUrl = repoUrl.trim();
    if (inputUrl.contains('github.com') && inputUrl.contains('/blob/')) {
      inputUrl = inputUrl
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/blob/', '/');
    } else if (inputUrl.contains('github.com') && inputUrl.contains('/tree/')) {
      inputUrl = inputUrl
          .replaceFirst('github.com', 'raw.githubusercontent.com')
          .replaceFirst('/tree/', '/');
    }

    if (!inputUrl.startsWith('http://') && !inputUrl.startsWith('https://')) {
      inputUrl = 'https://$inputUrl';
    }

    final uri = Uri.tryParse(inputUrl);
    if (uri == null || !uri.hasScheme) {
      throw Exception("Invalid repo URL");
    }

    final repos = loadRepos(type);

    if (repos.any((r) => r.url == inputUrl)) {
      return;
    }

    final res = await _client
        .get(Uri.parse(inputUrl))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception("Repo returned ${res.statusCode}");
    }

    final decoded = jsonDecode(res.body);

    if (decoded is Map<String, dynamic>) {
      final pluginLists = decoded["pluginLists"];

      if (pluginLists is List) {
        for (final subRepo in pluginLists.cast<String>()) {
          try {
            await _addRepoImpl(subRepo, type);
          } catch (e) {
            Logger.log("Failed to add $subRepo: $e");
          }
        }
        return;
      }

      throw Exception("Invalid CloudStream repository");
    }

    if (decoded is! List) {
      throw Exception("Invalid CloudStream repository");
    }

    final parsed = await compute(_parseExtensions, (res.body, repoUrl, type));
    final repo = Repo(
      name: repoNameFromUrl(repoUrl),
      url: repoUrl,
      extensions: parsed.length.toString(),
    );

    final updatedRepos = [...repos, repo];
    saveRepos(updatedRepos, type);
    state(type).repos.value = updatedRepos;
    await selectRepo(repo, type);
  }

  // Repo JSON `name` fields are publisher-controlled and used directly as a
  // filesystem path component below - path.join() does not collapse ".."
  // segments (the OS resolves them at open time), so an unsanitized name
  // containing "/" or "\" could write/delete outside the extensions
  // directory. Applied identically at install (write) and uninstall
  // (match) so both agree on the resulting on-disk basename.
  String _safeFileBaseName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[\\/]'), '_').trim();
    if (sanitized.isEmpty || RegExp(r'^\.+$').hasMatch(sanitized)) {
      return 'extension';
    }
    return sanitized;
  }

  final Map<String, Stream<double>> _installsInFlight = {};

  @override
  Stream<double> installSource(Source source) {
    final id = (source as CSource).id;

    // See the matching guard in Aniyomi/Tsundoku/IReader's installSource -
    // without this, a double-tap (or install racing an update for the same
    // source) runs two independent download+write sequences concurrently
    // against the same target file. The stream is broadcast, so a
    // concurrent caller shares the same in-flight operation and progress.
    if (id != null) {
      final inFlight = _installsInFlight[id];
      if (inFlight != null) return inFlight;
    }

    final stream = progressStream((report) async {
      try {
        await _installSourceImpl(source, report);
      } finally {
        if (id != null) _installsInFlight.remove(id);
      }
    });

    if (id != null) {
      _installsInFlight[id] = stream;
    }

    return stream;
  }

  Future<void> _installSourceImpl(
    Source source,
    void Function(double) report,
  ) async {
    final s = source as CSource;
    final type = source.itemType ?? ItemType.anime;

    if (s.pluginUrl == null || s.pluginUrl!.isEmpty) {
      throw Exception("Plugin URL is required for installation.");
    }

    final dir = await _getPluginDirectory();
    final filename = "${_safeFileBaseName(s.internalName ?? s.name ?? s.id ?? 'extension')}.cs3";
    final file = File(path.join(dir.path, filename));
    final tempFile = File(path.join(dir.path, "$filename.tmp"));

    final progressId = s.id;
    if (progressId != null) {
      state(type).installProgress[progressId] = 0.0;
    }

    try {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      await downloadPackageFile(
        _client,
        s.pluginUrl!,
        file.path,
        onProgress: (received, total) {
          if (total != null && total > 0) {
            final fraction = received / total;
            if (progressId != null) {
              state(type).installProgress[progressId] = fraction;
            }
            report(fraction);
          }
        },
      );

      final dynamic res = await platform.invokeMethod(
        'loadPlugin',
        {'path': file.path},
      );
      final bool success = (res is bool) ? res : true;

      if (success) {
        Logger.log("Successfully loaded CloudStream plugin: ${s.name}");

        final metaToSave = {
          'iconUrl': s.iconUrl,
          'language': s.lang,
          'version': s.version,
          'versionLast': s.versionLast,
          'pluginUrl': s.pluginUrl,
          'repo': s.repo,
        };
        final encodedMeta = jsonEncode(metaToSave);
        final norm = (s.internalName ?? s.name ?? '').toLowerCase();
        setVal('cs_meta_$norm', encodedMeta);
        setVal('cs_meta_${s.internalName ?? s.name}', encodedMeta);

        await fetchInstalledAnimeExtensions();

        final avail = state(type).available;
        avail.value = avail.value.where((e) => e.id != s.id).toList();

        final raw = state(type).rawAvailable.value;
        detectUpdates(raw, type);
      } else {
        throw Exception("Bridge failed to load plugin");
      }
    } catch (e) {
      Logger.log("Error installing CloudStream source ${s.name}: $e");
      rethrow;
    } finally {
      if (progressId != null) {
        state(type).installProgress.remove(progressId);
      }
    }
  }

  @override
  Future<void> uninstallSource(Source source) async {
    final s = source as CSource;
    final type = source.itemType ?? ItemType.anime;

    try {
      final dir = await _getPluginDirectory();
      final expectedBaseName = (s.internalName ?? s.name ?? s.id ?? '').toLowerCase();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final baseName = path.basenameWithoutExtension(entity.path).toLowerCase();
          if (baseName == expectedBaseName || baseName.contains(expectedBaseName)) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }

      try {
        await platform.invokeMethod('deletePlugin', {
          'internalName': s.internalName ?? s.name ?? '',
        });
      } catch (_) {}

      final norm = (s.internalName ?? s.name ?? '').toLowerCase();
      try {
        setVal('cs_meta_$norm', '');
        setVal('cs_meta_${s.internalName ?? s.name}', '');
      } catch (_) {}

      await fetchInstalledAnimeExtensions();

      final raw = state(type).rawAvailable.value;
      final installedIds = state(type).installed.value.map((e) => e.id).toSet();

      state(type).available.value = List.unmodifiable(
        raw.where((e) => !installedIds.contains(e.id)),
      );

      detectUpdates(raw, type);
    } catch (e) {
      Logger.log("Error uninstalling CloudStream source: $e");
    }
  }

  @override
  Stream<double> updateSource(Source source) => installSource(source);

  @override
  Set<String> schemes = {"cloudstreamrepo"};

  @override
  Future<void> handleSchemes(Uri uri) async {
    final urlWithoutScheme = uri.toString().replaceFirst(
      'cloudstreamrepo://',
      '',
    );

    await addRepo(
      urlWithoutScheme.startsWith('http')
          ? urlWithoutScheme
          : 'https://$urlWithoutScheme',
      ItemType.anime,
    ).drain<void>();
  }

  @override
  Future<List<Source>> fetchRepo(Repo repo, ItemType type) async {
    final indexUrl = repo.url;
    final res = await _client
        .get(Uri.parse(indexUrl))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      var extensions = await compute(_parseExtensions, (
        res.body,
        indexUrl,
        type,
      ));
      await updateRepoExtensionCount(repo, type, extensions.length);

      return extensions;
    }
    return [];
  }

  @override
  void detectUpdates(List<Source> available, ItemType type) {
    final installed = state(type).installed.value.cast<CSource>();

    final repoMap = {
      for (var s in available.cast<CSource>()) s.id?.toLowerCase(): s,
    };
    final repoByName = {
      for (var s in available.cast<CSource>()) if (s.name != null && s.name!.isNotEmpty) s.name!.toLowerCase(): s,
    };

    var changed = false;

    for (var i = 0; i < installed.length; i++) {
      final inst = installed[i];
      final repo = repoMap[inst.id?.toLowerCase()] ??
          (inst.name != null ? repoByName[inst.name!.toLowerCase()] : null);

      if (repo == null) continue;

      if (compareVersions(repo.version ?? "0", inst.version ?? "0") > 0) {
        installed[i] = inst
          ..hasUpdate = true
          ..pluginUrl = repo.pluginUrl
          ..versionLast = repo.version;
        changed = true;
      } else if (inst.hasUpdate == true) {
        installed[i] = inst..hasUpdate = false;
        changed = true;
      }
      if (repo.iconUrl != inst.iconUrl) {
        installed[i] = inst..iconUrl = repo.iconUrl;
        changed = true;
      }
    }

    if (changed) {
      state(type).installed.value = List.unmodifiable(installed);
    }
  }

  static List<Source> _parseExtensions(
    (String body, String repoUrl, ItemType itemType) args,
  ) {
    final (body, repoUrl, _) = args;

    final decoded = jsonDecode(body) as List;

    return decoded
        .map<Source>((e) {
          final json = e as Map<String, dynamic>;

          return CSource(
            id: (json["name"] ?? json["internalName"]).toString().toLowerCase(),
            name: json["name"],
            baseUrl: json["url"],
            lang: json["language"],
            iconUrl: json["iconUrl"],
            isNsfw: json["isNsfw"] ?? false,
            version: json["version"]?.toString(),
            versionLast: json["version"]?.toString(),
            itemType: ItemType.anime,
            repo: repoUrl,
            internalName: json["internalName"] ?? json["name"],
            pluginUrl: json["url"],
            managerId: 'cloudstream',
          );
        })
        .toList(growable: false);
  }
}

class CloudStreamPlugin extends DownloadablePlugin {
  @override
  String get name => "cloudStreamAndroid";

  @override
  String get fileName => "cloudStreamAndroid-plugin.apk";
}
