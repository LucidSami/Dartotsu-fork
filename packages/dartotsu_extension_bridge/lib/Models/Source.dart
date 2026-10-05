class Source {
  String? id;
  String? name;
  String? baseUrl;
  String? lang;
  bool? isNsfw;
  String? iconUrl;
  String? version;
  String? versionLast;
  ItemType? itemType;
  String? repo;
  bool? hasUpdate;
  String? managerId;
  bool? supportsLatest;
  bool? supportsPopular;

  Source({
    this.id = '',
    this.name = '',
    this.baseUrl = '',
    this.lang = '',
    this.iconUrl = '',
    this.isNsfw = false,
    this.version = "0.0.1",
    this.versionLast = "0.0.1",
    this.itemType = ItemType.manga,
    this.repo,
    this.hasUpdate = false,
    this.managerId,
    this.supportsLatest = false,
    this.supportsPopular = false,
  });

  Source.fromJson(Map<String, dynamic> json) {
    baseUrl = json['baseUrl'];
    iconUrl = json['iconUrl'];
    id = json['id'].toString();
    itemType = ItemType.values[json['itemType'] ?? 0];
    isNsfw = json['isNsfw'];
    lang = json['lang'];
    name = json['name'];
    version = json['version'];
    versionLast = json['versionLast'];
    repo = json['repo'];
    hasUpdate = json['hasUpdate'] ?? false;
    managerId = json['managerId'];
    supportsLatest = json['supportsLatest'] ?? false;
    supportsPopular = json['supportsPopular'] ?? false;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'lang': lang,
    'iconUrl': iconUrl,
    'isNsfw': isNsfw,
    'version': version,
    'versionLast': versionLast,
    'itemType': itemType?.index ?? 0,
    'repo': repo,
    'hasUpdate': hasUpdate,
    'managerId': managerId,
    'supportsLatest': supportsLatest,
    'supportsPopular': supportsPopular,
  };
}

enum ItemType {
  manga,
  anime,
  novel;

  @override
  String toString() {
    switch (this) {
      case ItemType.manga:
        return 'Manga';
      case ItemType.anime:
        return 'Anime';
      case ItemType.novel:
        return 'Novel';
    }
  }
}
