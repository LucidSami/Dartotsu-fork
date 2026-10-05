import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../../../DataClass/SearchResults.dart';
import '../../../../Widgets/CustomBottomDialog.dart';
import '../../../../Widgets/DropdownMenu.dart';
import '../../Anilist.dart';

class SearchFilter extends StatefulWidget {
  final SearchType type;
  final SearchResults searchResults;

  final void Function(SearchResults) onFilterChanged;

  const SearchFilter({
    super.key,
    required this.type,
    required this.searchResults,
    required this.onFilterChanged,
  });

  @override
  State<StatefulWidget> createState() => _SearchFilterState();
}

class _SearchFilterState extends State<SearchFilter> {
  late SearchResults searchResults;

  Rx<String?> source = Rx(null);
  Rx<String?> format = Rx(null);
  Rx<String?> status = Rx(null);
  Rx<String?> filter = Rx(null);
  Rx<String?> season = Rx(null);
  Rx<String?> country = Rx(null);

  Rx<int?> seasonYear = Rx(null);
  Rx<int?> startYear = Rx(null);

  Rx<List<String>?> tags = Rx(null);

  Rx<List<String>?> genres = Rx(null);

  @override
  void initState() {
    super.initState();
    searchResults = widget.searchResults;
    source.value = searchResults.source;
    format.value = searchResults.format;
    status.value = searchResults.status;
    filter.value = searchResults.sort;
    country.value = searchResults.countryOfOrigin;
    season.value = searchResults.season;
    seasonYear.value = searchResults.seasonYear;
    startYear.value = searchResults.startYear;
    tags.value = searchResults.tags;
    genres.value = searchResults.genres;
  }

  @override
  Widget build(BuildContext context) =>
      animeAndMangaFilter(context, widget.type);

  void reset() {
    searchResults = SearchResults(search: searchResults.search);
    source.value = null;
    format.value = null;
    status.value = null;
    season.value = null;
    seasonYear.value = null;
    startYear.value = null;
    tags.value = null;
    genres.value = null;
    filter.value = null;
    country.value = null;
  }

  void save() {
    searchResults = searchResults
      ..source = source.value
      ..format = format.value
      ..status = status.value
      ..season = season.value
      ..seasonYear = seasonYear.value
      ..startYear = startYear.value
      ..tags = tags.value
      ..genres = genres.value
      ..sort = filter.value
      ..countryOfOrigin = country.value;

    widget.onFilterChanged(searchResults);
  }

  Widget animeAndMangaFilter(BuildContext context, SearchType mediaType) {
    return ElevatedButton.icon(
      onPressed: () {
        showCustomBottomDialog(
          context,
          CustomBottomDialog(
            viewList: [
              Obx(() {
                return Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildDropdowns(mediaType),
                    const SizedBox(height: 16),
                    _buildGenreAndTags(),
                  ],
                );
              })
            ],
            positiveCallback: () {
              save();
              Navigator.pop(context);
            },
            negativeCallback: () => Navigator.pop(context),
            negativeText: 'Cancel',
            positiveText: 'Apply',
          ),
        );
      },
      icon: const Icon(Icons.filter_alt_rounded, size: 24),
      label: const Text(
        'Filter',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Poppins-SemiBold'),
      ),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          'Filter',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Poppins-SemiBold', fontSize: 24),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: reset,
              icon: const Icon(Icons.close, size: 32),
            ),
            const SizedBox(width: 32 * 2 + 16),
            Row(
              children: [
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.ac_unit, size: 32),
                  onSelected: (value) => country.value = value,
                  itemBuilder: (context) {
                    const options = {
                      null: "Global",
                      'CN': "China",
                      'JP': "Japan",
                      'KR': "Korea",
                      'TW': "Taiwan",
                    };
                    return options.entries
                        .map(
                          (e) => PopupMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins-SemiBold',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList();
                  },
                ),
                PopupMenuButton<String?>(
                  icon: const Icon(Icons.filter_list_alt, size: 32),
                  onSelected: (value) => filter.value = value,
                  itemBuilder: (context) {
                    var options = {
                      Anilist.sortBy[0]: "Score",
                      Anilist.sortBy[1]: "Popular",
                      Anilist.sortBy[2]: "Trending",
                      Anilist.sortBy[3]: "New Released",
                      Anilist.sortBy[4]: "A-Z",
                      Anilist.sortBy[5]: "Z-A",
                      Anilist.sortBy[6]: "Pure Pain",
                    };
                    return options.entries
                        .map(
                          (e) => PopupMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Poppins-SemiBold',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                        .toList();
                  },
                ),
              ],
            )
          ],
        ),
      ],
    );
  }

  Widget _buildDropdowns(SearchType mediaType) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: Anilist.source,
                hintText: 'Source',
                onChanged: (value) => source.value = value,
                currentValue: source.value,
              ),
            ),
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: mediaType == SearchType.ANIME
                    ? Anilist.animeFormats
                    : Anilist.mangaFormats,
                hintText: 'Format',
                onChanged: (value) => format.value = value,
                currentValue: format.value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: mediaType == SearchType.ANIME
                    ? Anilist.animeStatus
                    : Anilist.mangaStatus,
                hintText: 'Status',
                onChanged: (value) => status.value = value,
                currentValue: status.value,
              ),
            ),
            if (mediaType == SearchType.ANIME)
              Expanded(
                child: buildDropdownMenu(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  borderRadius: 16,
                  options: Anilist.seasons,
                  hintText: 'Season',
                  onChanged: (value) => season.value = value,
                  currentValue: season.value,
                ),
              ),
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: List.generate(
                  (DateTime.now().year + 2) - 1970,
                  (index) => (1970 + index).toString(),
                ).reversed.toList(),
                hintText: 'Year',
                onChanged: (value) {
                  if (mediaType == SearchType.ANIME) {
                    seasonYear.value = int.parse(value);
                  } else {
                    startYear.value = int.parse(value);
                  }
                },
                currentValue: mediaType == SearchType.ANIME
                    ? seasonYear.value?.toString()
                    : startYear.value?.toString(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreAndTags() {
    final allTags = Anilist.tags?[searchResults.isAdult ?? false] ?? [];
    final allGenres = Anilist.genres ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildDropdownSelector(
          title: 'Genres',
          icon: Icons.category_rounded,
          selectedList: genres.value ?? [],
          allItems: allGenres,
          onSelected: (val) => genres.value = val,
        ),
        const SizedBox(height: 16),
        _buildDropdownSelector(
          title: 'Tags',
          icon: Icons.label_rounded,
          selectedList: tags.value ?? [],
          allItems: allTags,
          onSelected: (val) => tags.value = val,
        ),
      ],
    );
  }

  Widget _buildDropdownSelector({
    required String title,
    required IconData icon,
    required List<String> selectedList,
    required List<String> allItems,
    required ValueChanged<List<String>> onSelected,
  }) {
    final theme = Theme.of(context).colorScheme;
    final selectedCount = selectedList.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(title),
              if (selectedCount > 0)
                TextButton(
                  onPressed: () => onSelected([]),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    'Clear ($selectedCount)',
                    style: TextStyle(
                      fontFamily: 'Poppins-SemiBold',
                      fontSize: 12,
                      color: theme.error,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openMultiSelectDialog(
              title: title,
              allItems: allItems,
              selectedList: selectedList,
              onSelected: onSelected,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedCount > 0
                      ? theme.primary.withValues(alpha: 0.6)
                      : theme.outlineVariant.withValues(alpha: 0.4),
                  width: selectedCount > 0 ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: theme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Select $title (Dropdown menu)'
                          : '$selectedCount $title selected',
                      style: TextStyle(
                        fontFamily: 'Poppins-SemiBold',
                        fontSize: 14,
                        color: selectedCount > 0
                            ? theme.onSurface
                            : theme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_circle_outlined,
                    size: 22,
                    color: theme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (selectedList.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: selectedList.map((item) {
                return Chip(
                  label: Text(
                    item.replaceAll("_", " "),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.onPrimaryContainer,
                    ),
                  ),
                  backgroundColor: theme.primaryContainer,
                  deleteIconColor: theme.onPrimaryContainer,
                  onDeleted: () {
                    final updated = List<String>.from(selectedList)..remove(item);
                    onSelected(updated);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _openMultiSelectDialog({
    required String title,
    required List<String> allItems,
    required List<String> selectedList,
    required ValueChanged<List<String>> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _MultiSelectBottomSheet(
          title: title,
          allItems: allItems,
          initialSelected: selectedList,
          onConfirm: onSelected,
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(
        title,
        style: const TextStyle(fontFamily: 'Poppins-SemiBold', fontSize: 16),
      ),
    );
  }
}

class _MultiSelectBottomSheet extends StatefulWidget {
  final String title;
  final List<String> allItems;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onConfirm;

  const _MultiSelectBottomSheet({
    required this.title,
    required this.allItems,
    required this.initialSelected,
    required this.onConfirm,
  });

  @override
  State<_MultiSelectBottomSheet> createState() => _MultiSelectBottomSheetState();
}

class _MultiSelectBottomSheetState extends State<_MultiSelectBottomSheet> {
  late List<String> _selected;
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final filtered = widget.allItems.where((item) {
      if (_search.isEmpty) return true;
      return item.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Container(
      height: mediaQuery.size.height * 0.82,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select ${widget.title}',
                    style: const TextStyle(
                      fontFamily: 'Poppins-SemiBold',
                      fontSize: 20,
                    ),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: Text(
                      'Clear (${_selected.length})',
                      style: TextStyle(
                        fontFamily: 'Poppins-SemiBold',
                        color: theme.error,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    widget.onConfirm(_selected);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontFamily: 'Poppins-SemiBold'),
                  ),
                ),
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: theme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _search = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _search = val),
            ),
          ),
          const Divider(height: 1),
          // Full display grid of items
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching ${widget.title.toLowerCase()}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: theme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: filtered.map((item) {
                          final isSelected = _selected.contains(item);
                          return FilterChip(
                            selected: isSelected,
                            label: Text(
                              item.replaceAll("_", " "),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? theme.onPrimaryContainer
                                    : theme.onSurface,
                              ),
                            ),
                            selectedColor: theme.primaryContainer,
                            backgroundColor: theme.surfaceContainerHigh,
                            checkmarkColor: theme.onPrimaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? theme.primary
                                    : theme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            onSelected: (checked) {
                              setState(() {
                                if (checked) {
                                  _selected.add(item);
                                } else {
                                  _selected.remove(item);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
