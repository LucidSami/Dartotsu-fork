import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../Adaptor/Media/Widgets/Chips.dart';
import '../../../Adaptor/Media/Widgets/MediaSection.dart';
import '../../../DataClass/Media.dart';
import '../../../DataClass/SearchResults.dart';
import '../../../Services/Screens/BaseSearchScreen.dart';
import '../Mal.dart';
import 'Widgets/MalSearchFilter.dart';

class MalSearchScreen extends BaseSearchScreen {
  final MalController Mal;

  MalSearchScreen(this.Mal);

  @override
  List<SearchType> get searchTypes => [
    SearchType.ANIME,
    SearchType.MANGA,
  ];

  var searchResult = Rxn<List<Object>?>();

  @override
  Future<void> search() async {
    showHistory.value = false;
    searchResult.value = null;
    canLoadMore.value = true;
    loadMore.value = true;
    searchResults.value = searchResults.value..page = 1;
    var res = await Mal.query?.search(searchResults.value);
    if (res != null) {
      searchResults.value = res;
      canLoadMore.value = res.hasNextPage ?? false;
      loadMore.value = res.hasNextPage ?? false;
    }
    searchResult.value = results(res) ?? [];
  }

  List<Object>? results(SearchResults? res) {
    return res?.results;
  }

  @override
  void init({SearchResults? s}) {
    resetData();
    super.init(s: s);
  }

  void resetData() {
    searchResult.value = null;
  }

  @override
  Future<void>? loadNextPage() async {
    final nextPage = (searchResults.value.page ?? 1) + 1;
    final currentSearch = searchResults.value;
    currentSearch.page = nextPage;
    var res = await Mal.query?.search(currentSearch);
    if (res != null) {
      searchResults.value = res;
      final newItems = results(res) ?? [];
      if (newItems.isNotEmpty) {
        searchResult.value = [...searchResult.value ?? [], ...newItems];
      }
      canLoadMore.value = res.hasNextPage ?? false;
    } else {
      searchResults.value.page = nextPage - 1;
      canLoadMore.value = true;
    }
    loadMore.value = true;
  }

  @override
  List<Widget> searchWidget(BuildContext context) {
    return animeAndMangaResults(context, searchResults.value.type);
  }

  @override
  List<Widget> headerWidget(BuildContext context) {
    return animeAndMangaFilter(context, searchResults.value.type);
  }

  List<Widget> animeAndMangaFilter(BuildContext context, SearchType mediaType) {
    return [
      Obx(() {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: searchResults.value.onList ?? false,
                        onChanged: (n) {
                          var value = n == true ? true : null;
                          searchResults.value = searchResults.value
                            ..onList = value;
                          search();
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text("List Only"),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: ChipsWidget(
                    chips: searchResults.value.toChipList().map((label) {
                      return ChipData(
                        label: label.text.replaceAll("_", " "),
                        action: () {
                          searchResults.value.removeChip(label);
                          if (searchResults.value.toChipList().isEmpty &&
                              (searchResults.value.search == null ||
                                  searchResults.value.search!.isEmpty)) {
                            showHistory.value = true;
                          } else {
                            search();
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 24.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MalSearchFilter(
                        type: mediaType,
                        searchResults: searchResults.value,
                        onFilterChanged: (n) {
                          searchResults.value = n;
                          if (searchResults.value.toChipList().isEmpty &&
                              (searchResults.value.search == null ||
                                  searchResults.value.search!.isEmpty)) {
                            showHistory.value = true;
                          } else {
                            search();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        );
      }),
    ];
  }

  List<Widget> animeAndMangaResults(
    BuildContext context,
    SearchType mediaType,
  ) {
    return [
      MediaSection(
        context: context,
        type: type.value,
        title: 'Search Results',
        mediaList: searchResult.value?.whereType<Media>().toList(),
        trailingIcon: _buildTrailingIcon(context),
      ),
    ];
  }

  Widget _buildTrailingIcon(BuildContext context) {
    final icons = [Icons.view_list_sharp, Icons.grid_view_rounded];

    final theme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(icons.length, (index) {
        var value = index == 0 ? 2 : 3;
        final isSelected = value == type.value;
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: Transform(
              alignment: Alignment.center,
              transform: index == 0
                  ? Matrix4.rotationY(3.14159)
                  : Matrix4.identity(),
              child: Icon(icons[index]),
            ),
            iconSize: 24,
            color: isSelected
                ? theme.onSurface
                : theme.onSurface.withOpacity(0.33),
            onPressed: () {
              if (!isSelected) type.value = value;
            },
          ),
        );
      }),
    );
  }
}
