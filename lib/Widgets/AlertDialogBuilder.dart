import 'dart:async';

import 'package:flutter/material.dart';

import '../Theme/ThemeManager.dart';

class AlertDialogBuilder {
  final BuildContext context;
  String? _title;
  Widget? _titleWidget;
  String? _message;
  String? _positiveButtonTitle;
  String? _negativeButtonTitle;
  String? _neutralButtonTitle;
  VoidCallback? _onPositiveButtonClick;
  VoidCallback? _onNegativeButtonClick;
  VoidCallback? _onNeutralButtonClick;
  List<String>? _items;
  List<bool>? _checkedItems;
  ValueChanged<List<bool>>? _onItemsSelected;
  int _selectedItemIndex = -1;
  ValueChanged<int>? _onItemSelected;
  List<String>? _reorderableItems;
  ValueChanged<List<String>>? _onReorderedItems;
  bool _isReorderableMultiSelectable = false;
  Widget? _customView;
  VoidCallback? _onShow;
  VoidCallback? _onAttach;
  VoidCallback? _onDismiss;
  bool _cancelable = true;
  bool _popOnFinish = true;

  AlertDialogBuilder(this.context);

  AlertDialogBuilder popOnFinish(bool popOnFinish) =>
      _with(() => _popOnFinish = popOnFinish);

  AlertDialogBuilder setCancelable(bool cancelable) =>
      _with(() => _cancelable = cancelable);

  AlertDialogBuilder setOnShowListener(VoidCallback onShow) =>
      _with(() => _onShow = onShow);

  AlertDialogBuilder setOnAttachListener(VoidCallback attach) =>
      _with(() => _onAttach = attach);

  AlertDialogBuilder setOnDismissListener(VoidCallback onDismiss) =>
      _with(() => _onDismiss = onDismiss);

  AlertDialogBuilder setTitle(String? title) => _with(() => _title = title);

  AlertDialogBuilder setTitleWidget(Widget? w) => _with(() => _titleWidget = w);

  AlertDialogBuilder setMessage(String? message) =>
      _with(() => _message = message);

  AlertDialogBuilder setCustomView(Widget customView) =>
      _with(() => _customView = customView);

  AlertDialogBuilder setPositiveButton(String? title, VoidCallback? onClick) =>
      _with(() {
        _positiveButtonTitle = title;
        _onPositiveButtonClick = onClick;
      });

  AlertDialogBuilder setNegativeButton(String? title, VoidCallback? onClick) =>
      _with(() {
        _negativeButtonTitle = title;
        _onNegativeButtonClick = onClick;
      });

  AlertDialogBuilder setNeutralButton(String? title, VoidCallback? onClick) =>
      _with(() {
        _neutralButtonTitle = title;
        _onNeutralButtonClick = onClick;
      });

  AlertDialogBuilder singleChoiceItems(List<String> items,
          int selectedItemIndex, ValueChanged<int> onItemSelected) =>
      _with(() {
        _items = items;
        _selectedItemIndex = selectedItemIndex;
        _onItemSelected = onItemSelected;
      });

  AlertDialogBuilder multiChoiceItems(List<String> items,
          List<bool>? checkedItems, ValueChanged<List<bool>> onItemsSelected) =>
      _with(() {
        _items = items;
        _checkedItems = checkedItems ?? List<bool>.filled(items.length, false);
        _onItemsSelected = onItemsSelected;
      });

  AlertDialogBuilder reorderableItems(
          List<String> items, ValueChanged<List<String>> onReorderedItems) =>
      _with(() {
        _reorderableItems = items;
        _onReorderedItems = onReorderedItems;
      });

  AlertDialogBuilder reorderableMultiSelectableItems(
          List<String> items,
          List<bool>? checkedItems,
          ValueChanged<List<String>> onReorderedItems,
          ValueChanged<List<bool>> onReorderedItemsSelected) =>
      _with(() {
        _reorderableItems = items;
        _checkedItems = checkedItems ?? List<bool>.filled(items.length, false);
        _onReorderedItems = onReorderedItems;
        _onItemsSelected = onReorderedItemsSelected;
        _isReorderableMultiSelectable = true;
      });

  Future<T?> show<T>() {
    _onAttach?.call();

    return showDialog<T>(
      context: context,
      barrierDismissible: _cancelable,
      builder: (BuildContext dialogContext) {
        final mediaQuery = MediaQuery.maybeOf(dialogContext) ?? MediaQuery.maybeOf(context);
        final screenWidth = mediaQuery?.size.width ?? 400.0;
        final screenHeight = mediaQuery?.size.height ?? 800.0;
        final viewInsetsBottom = mediaQuery?.viewInsets.bottom ?? 0.0;
        final theme = Theme.of(dialogContext).colorScheme;

        _onShow?.call();
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsetsBottom),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth * 0.8,
              ),
              child: IntrinsicWidth(
                child: ThemedContainer(
                  context: dialogContext,
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_titleWidget != null || _title != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _titleWidget ??
                              Text(
                                _title ?? '',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary,
                                ),
                              ),
                        ),
                      Flexible(
                        fit: FlexFit.loose,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: screenHeight * 0.6,
                          ),
                          child: StatefulBuilder(
                            builder:
                                (BuildContext builderContext, StateSetter setState) =>
                                    _buildContent(builderContext, setState),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: _buildActions(dialogContext),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).then((value) {
      _onDismiss?.call();
      return value;
    });
  }

  Widget _buildContent(BuildContext ctx, StateSetter setState) {
    if (_reorderableItems != null) {
      return _isReorderableMultiSelectable
          ? _buildReorderableSelectableContent(ctx, setState)
          : _buildReorderableContent(ctx, setState);
    } else if (_items != null) {
      return _onItemSelected != null
          ? _buildRadioListContent(ctx, setState)
          : _buildCheckboxListContent(ctx, setState);
    }
    return _buildDefaultContent(ctx);
  }

  Widget _buildReorderableContent(BuildContext ctx, StateSetter setState) =>
      _buildReorderableWidget(ctx, setState, (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final items = List<String>.from(_reorderableItems!);
        final item = items.removeAt(oldIndex);
        items.insert(newIndex, item);
        setState(() => _reorderableItems = items);
        _onReorderedItems?.call(items);
      });

  Widget _buildReorderableSelectableContent(BuildContext ctx, StateSetter setState) =>
      _buildReorderableWithCheckBoxWidget(ctx, setState, (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex -= 1;
        final items = List<String>.from(_reorderableItems!);
        final checkedStates = List<bool>.from(_checkedItems!);
        final item = items.removeAt(oldIndex);
        final state = checkedStates.removeAt(oldIndex);
        items.insert(newIndex, item);
        checkedStates.insert(newIndex, state);
        setState(() {
          _reorderableItems = items;
          _checkedItems = checkedStates;
        });
        _onReorderedItems?.call(items);
        _onItemsSelected?.call(checkedStates);
      });

  Widget _buildReorderableWithCheckBoxWidget(
          BuildContext ctx, StateSetter setState, void Function(int, int) onReorder) {
    final mediaQuery = MediaQuery.maybeOf(ctx) ?? MediaQuery.maybeOf(context);
    final width = (mediaQuery?.size.width ?? 400.0) * 0.7;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ReorderableListView(
              onReorder: onReorder,
              children: _reorderableItems!.asMap().entries.map((entry) {
                int index = entry.key;
                String item = entry.value;
                return CheckboxListTile(
                  key: ValueKey(item),
                  title: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: _checkedItems![index],
                  onChanged: (bool? value) {
                    setState(() {
                      _checkedItems![index] = value!;
                      _onItemsSelected?.call(_checkedItems!);
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableWidget(
          BuildContext ctx, StateSetter setState, void Function(int, int) onReorder) {
    final mediaQuery = MediaQuery.maybeOf(ctx) ?? MediaQuery.maybeOf(context);
    final width = (mediaQuery?.size.width ?? 400.0) * 0.7;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: ReorderableListView(
              onReorder: onReorder,
              children: _reorderableItems!.map((item) {
                return ListTile(
                  key: ValueKey(item),
                  title: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioListContent(BuildContext ctx, StateSetter setState) => _buildListContent(
        ctx,
        (item) => RadioListTile<int>(
          title: Text(
            item,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          value: _items!.indexOf(item),
          groupValue: _selectedItemIndex,
          onChanged: (int? value) {
            setState(() => _selectedItemIndex = value!);
            _onItemSelected?.call(value!);
            Navigator.of(ctx).pop();
          },
        ),
      );

  Widget _buildCheckboxListContent(BuildContext ctx, StateSetter setState) => _buildListContent(
        ctx,
        (item) {
          final index = _items!.indexOf(item);
          return CheckboxListTile(
            title: Text(
              item,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            value: _checkedItems![index],
            onChanged: (bool? value) {
              setState(() => _checkedItems![index] = value!);
              _onItemsSelected?.call(_checkedItems!);
            },
            controlAffinity: ListTileControlAffinity.leading,
          );
        },
      );

  Widget _buildListContent(BuildContext ctx, Widget Function(String) itemBuilder) {
    final mediaQuery = MediaQuery.maybeOf(ctx) ?? MediaQuery.maybeOf(context);
    final width = (mediaQuery?.size.width ?? 400.0) * 0.7;
    return SizedBox(
      width: width,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _items!.length,
        itemBuilder: (_, index) => itemBuilder(_items![index]),
      ),
    );
  }

  Widget _buildDefaultContent([BuildContext? ctx]) {
    final mediaQuery = (ctx != null ? MediaQuery.maybeOf(ctx) : null) ??
        MediaQuery.maybeOf(context);
    final width = (mediaQuery?.size.width ?? 400.0) * 0.7;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: width,
      ),
      child: _customView ?? Text(_message ?? ''),
    );
  }

  List<Widget> _buildActions([BuildContext? ctx]) {
    var theme = (ctx != null ? Theme.of(ctx) : Theme.of(context)).colorScheme;
    final actions = <Widget>[];
    if (_neutralButtonTitle != null) {
      actions.add(
        _buildButton(
          _neutralButtonTitle!,
          _onNeutralButtonClick,
          theme,
          ctx,
        ),
      );
    }
    if (_negativeButtonTitle != null) {
      actions.add(
        _buildButton(
          _negativeButtonTitle!,
          _onNegativeButtonClick,
          theme,
          ctx,
        ),
      );
    }
    if (_positiveButtonTitle != null) {
      actions.add(
        _buildButton(
          _positiveButtonTitle!,
          _onPositiveButtonClick,
          theme,
          ctx,
        ),
      );
    }
    return actions;
  }

  Widget _buildButton(
          String title, VoidCallback? onClick, ColorScheme theme, [BuildContext? ctx]) =>
      TextButton(
        onPressed: () {
          onClick?.call();
          if (_popOnFinish) {
            final nav = ctx != null ? Navigator.maybeOf(ctx) : Navigator.maybeOf(context);
            nav?.pop();
          }
        },
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.primary,
          ),
        ),
      );

  AlertDialogBuilder _with(VoidCallback action) {
    action();
    return this;
  }
}
