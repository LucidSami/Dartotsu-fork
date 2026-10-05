import 'package:dartotsu/Preferences/IsarDataClasses/MediaSettings/MediaSettings.dart';
import 'package:dartotsu_extension_bridge/dartotsu_extension_bridge.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../DataClass/Media.dart';
import '../../../../../Functions/Function.dart';
import '../../../../../Widgets/CustomBottomDialog.dart';
import '../../../../../Widgets/DropdownMenu.dart';
import '../../../../Extensions/ExtensionSettings/SourcePreferenceScreen.dart';
import '../../../../Settings/language.dart';

class SourceSelector extends StatefulWidget {
  final Source? currentSource;
  final Function(Source source) onSourceChange;
  final Media mediaData;
  final List<Source> sourceList;
  final void Function() reload;
  final void Function(String managerId)? onProviderChange;

  const SourceSelector({
    super.key,
    this.currentSource,
    required this.onSourceChange,
    required this.mediaData,
    required this.sourceList,
    required this.reload,
    this.onProviderChange,
  });

  @override
  State<StatefulWidget> createState() => _SourceSelectorState();
}

class _SourceSelectorState extends State<SourceSelector> {
  @override
  Widget build(BuildContext context) {
    final isAnime = widget.mediaData.anime != null;
    final itemType = isAnime
        ? ItemType.anime
        : widget.mediaData.format?.toLowerCase() == 'novel'
            ? ItemType.novel
            : ItemType.manga;

    final extensionManager = Get.find<ExtensionManager>();
    final theme = Theme.of(context).colorScheme;
    var sources = widget.sourceList;

    if (sources.isEmpty) {
      return Column(
        children: [
          _buildProviderSelector(context, theme, itemType, extensionManager),
          const buildDropdownMenu(
            padding: EdgeInsets.all(0),
            currentValue: 'No sources installed',
            options: ['No sources installed'],
            prefixIcon: Icons.source,
          ),
        ],
      );
    }
    String nameAndLang(Source source) {
      bool isDuplicateName =
          sources.where((s) => s.name == source.name).length > 1;

      return isDuplicateName
          ? '${source.name!} - ${completeLanguageName(source.lang!.toLowerCase())}'
          : source.name!;
    }

    var lastUsedSource = widget.mediaData.settings.lastUsedSource;
    if (lastUsedSource == null ||
        !sources.any((e) => nameAndLang(e) == lastUsedSource)) {
      lastUsedSource = nameAndLang(sources.first);
    }

    Source source =
        sources.firstWhereOrNull((e) => nameAndLang(e) == lastUsedSource!) ??
            sources.first;

    return Column(
      children: [
        _buildProviderSelector(context, theme, itemType, extensionManager),
        Row(
          children: [
            Expanded(
              child: buildDropdownMenu(
                padding: const EdgeInsets.all(0),
                currentValue: lastUsedSource,
                options: sources.map((e) => nameAndLang(e)).toList(),
                borderColor: theme.primary,
                prefixIcon: Icons.source,
                onChanged: (name) async {
                  widget.mediaData.settings.lastUsedSource = name;
                  MediaSettings.saveMediaSettings(widget.mediaData);
                  lastUsedSource = name;
                  source = sources.firstWhereOrNull(
                          (e) => nameAndLang(e) == lastUsedSource!) ??
                      sources.first;
                  if (widget.currentSource?.id != source.id) {
                    widget.onSourceChange(source);
                  }
                },
                trailingBuilder: (item) {
                  final isSelected = item == lastUsedSource;
                  if (!isSelected) return const SizedBox();
                  return IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () {
                      widget.reload();
                      setState(() {});
                    },
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async => await loadPreferences(source),
              child: Icon(
                Icons.settings,
                size: 32,
                color: theme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderSelector(
    BuildContext context,
    ColorScheme theme,
    ItemType itemType,
    ExtensionManager extensionManager,
  ) {
    return Obx(() {
      final activeManager = extensionManager[itemType];
      final eligibleManagers = extensionManager.managers
          .where((m) => m.supports(itemType))
          .toList();

      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showProviderSelectionDialog(
                  context,
                  theme,
                  itemType,
                  activeManager,
                  eligibleManagers,
                  extensionManager,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.primary.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          activeManager.icon,
                          width: 26,
                          height: 26,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${itemType.name.capitalizeFirst} Provider",
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              activeManager.name,
                              style: TextStyle(
                                fontSize: 15,
                                color: theme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Change",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.primary,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: theme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  void _showProviderSelectionDialog(
    BuildContext context,
    ColorScheme theme,
    ItemType itemType,
    Extension activeManager,
    List<Extension> eligibleManagers,
    ExtensionManager extensionManager,
  ) {
    showCustomBottomDialog(
      context,
      CustomBottomDialog(
        title: "Select ${itemType.name.capitalizeFirst} Provider",
        positiveText: "Done",
        positiveCallback: () => Navigator.pop(context),
        viewList: [
          ...eligibleManagers.map((m) {
            final isSelected = m.id == activeManager.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? BorderSide(color: theme.primary, width: 1.5)
                      : BorderSide.none,
                ),
                tileColor: isSelected
                    ? theme.primary.withValues(alpha: 0.12)
                    : theme.surfaceContainerHighest.withValues(alpha: 0.4),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    m.icon,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                title: Text(
                  m.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? theme.primary : theme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: theme.primary)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  if (m.id != activeManager.id) {
                    if (widget.onProviderChange != null) {
                      widget.onProviderChange!(m.id);
                    } else {
                      extensionManager.switchManager(itemType, m.id);
                    }
                  }
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> loadPreferences(Source source) async {
    var preference = await source.methods.getPreference();
    if (preference.isEmpty) {
      snackString("Source doesn't have any settings");
      return;
    }
    if (mounted) {
      navigateToPage(
        context,
        SourcePreferenceScreen(source: source, preference: preference),
      );
    }
  }
}
