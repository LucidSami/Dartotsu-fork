import '../../../../Models/Source.dart';

class CSource extends Source {
  String? internalName;
  String? pluginUrl;

  CSource({
    super.id,
    super.name,
    super.baseUrl,
    super.lang,
    super.isNsfw,
    super.iconUrl,
    super.version,
    super.versionLast,
    super.itemType,
    super.repo,
    super.hasUpdate,
    super.managerId,
    this.internalName,
    this.pluginUrl,
  });

  factory CSource.fromJson(Map<String, dynamic> json) {
    final language = json['language'] as String? ?? json['lang'] as String?;
    final rawVersion = json['version']?.toString() ?? json['versionLast']?.toString();
    final versionStr = (rawVersion != null && rawVersion.isNotEmpty) ? rawVersion : "1.0.0";

    return CSource(
      id:
          json['id']?.toString().toLowerCase() ??
          json['name']?.toString().toLowerCase() ??
          '',
      name: json['name'],
      baseUrl: json['baseUrl'] ?? json['url'],
      lang: (language == null || language.trim().isEmpty) ? 'all' : language,
      iconUrl: json['iconUrl'],
      isNsfw: json['isNsfw'] ?? false,
      version: versionStr,
      versionLast: json['versionLast']?.toString() ?? versionStr,
      repo: json['repo'],
      hasUpdate: json['hasUpdate'] ?? false,
      itemType: ItemType.anime,
      internalName: json['internalName'] ?? json['name'],
      pluginUrl: json['pluginUrl'] ?? json['plugin'] ?? json['url'],
      managerId: 'cloudstream',
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final map = super.toJson();
    map['internalName'] = internalName;
    map['plugin'] = pluginUrl;
    return map;
  }
}
