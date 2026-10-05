import 'package:dartotsu_extension_bridge/Models/Source.dart';
import 'package:dartotsu_extension_bridge/Services/LnReader/LnReaderSourceMethods.dart';
import 'package:dartotsu_extension_bridge/Services/LnReader/Models/Source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('test royalroad plugin in LnReaderSourceMethods', () async {
    const url = 'https://raw.githubusercontent.com/lnreader/lnreader-plugins/plugins/v3.0.0/.js/src/plugins/english/royalroad.js';
    final res = await http.get(Uri.parse(url));
    expect(res.statusCode, 200);

    final source = LSource(
      id: 'royalroad',
      name: 'Royal Road',
      baseUrl: 'https://www.royalroad.com/',
      lang: 'English',
      version: '1.0.0',
      itemType: ItemType.novel,
      sourceCode: res.body,
    );

    final methods = LnReaderSourceMethods(source);
    try {
      print('Calling getPopular...');
      final popular = await methods.getPopular(1);
      print('Popular count: ${popular.list.length}');
      if (popular.list.isNotEmpty) {
        print('First novel: ${popular.list.first.title} - ${popular.list.first.url}');
      }

      print('Calling search...');
      final searchRes = await methods.search('slime', 1, []);
      print('Search count: ${searchRes.list.length}');
      if (searchRes.list.isNotEmpty) {
        print('First search novel: ${searchRes.list.first.title} - ${searchRes.list.first.url}');
        print('Calling getDetail...');
        final detail = await methods.getDetail(searchRes.list.first);
        print('Detail chapters count: ${detail.episodes?.length}');
      }
    } catch (e, st) {
      print('FAILED: $e\n$st');
      rethrow;
    }
  });
}
