import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../../../DataClass/SearchResults.dart';
import '../../../../Widgets/CustomBottomDialog.dart';
import '../../../../Widgets/DropdownMenu.dart';

class MalSearchFilter extends StatefulWidget {
  final SearchType type;
  final SearchResults searchResults;
  final void Function(SearchResults) onFilterChanged;

  const MalSearchFilter({
    super.key,
    required this.type,
    required this.searchResults,
    required this.onFilterChanged,
  });

  @override
  State<StatefulWidget> createState() => _MalSearchFilterState();
}

class _MalSearchFilterState extends State<MalSearchFilter> {
  late SearchResults searchResults;

  Rx<String?> format = Rx(null);
  Rx<String?> sort = Rx(null);
  Rx<String?> status = Rx(null);
  Rx<List<String>?> genres = Rx(null);

  final List<String> animeFormats = ['tv', 'movie', 'ova', 'special'];
  final List<String> mangaFormats = ['manga', 'novels', 'manhwa', 'one_shot'];
  final List<String> sortOptions = ['bypopularity', 'all', 'favorite', 'airing', 'upcoming'];

  static const List<String> malAnimeGenres = [
    'Action',
    'Adventure',
    'Avant Garde',
    'Award Winning',
    'Boys Love',
    'Comedy',
    'Drama',
    'Fantasy',
    'Girls Love',
    'Gourmet',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Suspense',
    'Ecchi',
    'Work Life',
  ];

  static const List<String> malMangaGenres = [
    'Action',
    'Adventure',
    'Avant Garde',
    'Award Winning',
    'Boys Love',
    'Comedy',
    'Drama',
    'Fantasy',
    'Girls Love',
    'Gourmet',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Suspense',
    'Ecchi',
    'Work Life',
  ];

  @override
  void initState() {
    super.initState();
    searchResults = widget.searchResults;
    format.value = searchResults.format;
    sort.value = searchResults.sort;
    status.value = searchResults.status;
    genres.value = searchResults.genres != null
        ? List<String>.from(searchResults.genres!)
        : null;
  }

  void reset() {
    searchResults = SearchResults(
      type: widget.type,
      search: searchResults.search,
    );
    format.value = null;
    sort.value = null;
    status.value = null;
    genres.value = null;
  }

  void save() {
    searchResults = searchResults
      ..format = format.value
      ..sort = sort.value
      ..status = status.value
      ..genres = (genres.value != null && genres.value!.isNotEmpty)
          ? genres.value
          : null;

    widget.onFilterChanged(searchResults);
  }

  @override
  Widget build(BuildContext context) {
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
                    _buildDropdowns(),
                    const SizedBox(height: 16),
                    _buildGenreSelector(),
                  ],
                );
              }),
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
          'MAL Filter',
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
            const SizedBox(width: 48),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdowns() {
    final formats = widget.type == SearchType.ANIME ? animeFormats : mangaFormats;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: formats,
                hintText: 'Format',
                onChanged: (value) => format.value = value,
                currentValue: format.value,
              ),
            ),
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                borderRadius: 16,
                options: sortOptions,
                hintText: 'Ranking / Sort',
                onChanged: (value) => sort.value = value,
                currentValue: sort.value,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreSelector() {
    final allGenres = widget.type == SearchType.ANIME ? malAnimeGenres : malMangaGenres;
    final selectedList = genres.value ?? [];
    final selectedCount = selectedList.length;
    final theme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Genres',
                  style: TextStyle(fontFamily: 'Poppins-SemiBold', fontSize: 16),
                ),
              ),
              if (selectedCount > 0)
                TextButton(
                  onPressed: () => genres.value = [],
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
              title: 'Genres',
              allItems: allGenres,
              selectedList: selectedList,
              onSelected: (val) => genres.value = val,
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
                  Icon(Icons.category_rounded, size: 20, color: theme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Select Genres (Dropdown menu)'
                          : '$selectedCount Genres selected',
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
                    item,
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
                    genres.value = updated;
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
        return _MalMultiSelectBottomSheet(
          title: title,
          allItems: allItems,
          initialSelected: selectedList,
          onConfirm: onSelected,
        );
      },
    );
  }
}

class _MalMultiSelectBottomSheet extends StatefulWidget {
  final String title;
  final List<String> allItems;
  final List<String> initialSelected;
  final ValueChanged<List<String>> onConfirm;

  const _MalMultiSelectBottomSheet({
    required this.title,
    required this.allItems,
    required this.initialSelected,
    required this.onConfirm,
  });

  @override
  State<_MalMultiSelectBottomSheet> createState() =>
      _MalMultiSelectBottomSheetState();
}

class _MalMultiSelectBottomSheetState
    extends State<_MalMultiSelectBottomSheet> {
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
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: theme.outlineVariant.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select ${widget.title}',
                  style: const TextStyle(
                    fontFamily: 'Poppins-Bold',
                    fontSize: 20,
                  ),
                ),
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    fontFamily: 'Poppins-SemiBold',
                    fontSize: 13,
                    color: theme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}...',
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.outlineVariant),
                ),
                filled: true,
                fillColor: theme.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selected.length == widget.allItems.length) {
                        _selected.clear();
                      } else {
                        _selected = List<String>.from(widget.allItems);
                      }
                    });
                  },
                  child: Text(
                    _selected.length == widget.allItems.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(fontFamily: 'Poppins-SemiBold', fontSize: 12),
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Poppins-SemiBold',
                        fontSize: 12,
                        color: theme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching ${widget.title.toLowerCase()}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: theme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isSelected = _selected.contains(item);
                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: theme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(
                          item,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selected.add(item);
                            } else {
                              _selected.remove(item);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onConfirm(_selected);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text('Done (${_selected.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
