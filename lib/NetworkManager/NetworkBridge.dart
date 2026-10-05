import 'dart:convert';
import 'dart:io';

import 'package:dartotsu_extension_bridge/ExtensionBridge.dart';

import 'CookieManager.dart';
import 'DnsManager.dart';

class AppBridgeNetwork implements BridgeNetwork {
  final CookieManager cookieManager;

  AppBridgeNetwork(this.cookieManager);

  @override
  String? get dns => DohProvider.cloudflare.url;

  @override
  String? get proxy => null;

  @override
  String? get userAgent => Platform.isAndroid
      ? "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
      : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

  @override
  Future<String?> getCookies(String url) async {
    final cookies = cookieManager.getValidCookies(Uri.parse(url));

    if (cookies.isEmpty) {
      return null;
    }

    return jsonEncode(cookies.map((c) => c.toJson()).toList());
  }

  @override
  Future<void> setCookies(String url, List<String> cookies) async {
    final uri = Uri.parse(url);

    final parsed = <StoredCookie>[];

    for (final header in cookies) {
      final cookie = cookieManager.parseSingleCookie(header, uri);

      if (cookie != null) {
        parsed.add(cookie);
      }
    }

    cookieManager.setCookies(parsed);
  }
}
