import '../Models/DEpisode.dart';
import '../Models/DMedia.dart';
import '../Models/Page.dart';
import '../Models/Pages.dart';
import '../Models/Source.dart';
import '../Models/SourcePreference.dart';
import '../Models/Video.dart';

abstract class SourceMethods {
  Source get source;

  Future<Pages> getPopular(int page);

  Future<Pages> getLatestUpdates(int page);

  Future<Pages> search(String query, int page, List<dynamic> filters);

  Future<DMedia> getDetail(DMedia media);

  Future<List<PageUrl>> getPageList(DEpisode episode);

  Future<List<Video>> getVideoList(DEpisode episode);

  Stream<List<Video>> getVideoListStream(DEpisode episode) => const Stream.empty();

  Future<String?> getNovelContent(DEpisode episode);

  Future<List<dynamic>> getFilterList() async => [];

  void cancelRequest(String token) {}

  Future<List<SourcePreference>> getPreference();

  Future<bool> setPreference(SourcePreference pref, dynamic value);
}
