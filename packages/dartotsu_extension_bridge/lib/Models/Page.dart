class PageUrl {
  String url;
  Map<String, String>? headers;

  PageUrl(this.url, {this.headers});

  factory PageUrl.fromJson(Map<String, dynamic> json) {
    // See the matching comment in Models/Video.dart: a missing url must not
    // silently become the literal string "null" via null.toString().
    final url = json['url'];
    if (url == null) {
      throw FormatException('PageUrl JSON is missing a "url" field: $json');
    }

    return PageUrl(
      url.toString().trim(),
      headers: (json['headers'] as Map?)
          ?.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  Map<String, dynamic> toJson() => {'url': url, 'headers': headers};
}
