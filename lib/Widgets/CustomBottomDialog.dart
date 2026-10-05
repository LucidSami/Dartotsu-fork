import 'package:dartotsu/Theme/ThemeManager.dart';
import 'package:flutter/material.dart';

class CustomBottomDialog extends StatefulWidget {
  final List<Widget> viewList;
  final String? title;
  final String? checkText;
  final bool checkChecked;
  final void Function(bool)? checkCallback;
  final String? negativeText;
  final VoidCallback? negativeCallback;
  final String? positiveText;
  final VoidCallback? positiveCallback;
  final void Function()? onClose;
  const CustomBottomDialog({
    super.key,
    this.viewList = const [],
    this.title,
    this.checkText,
    this.checkChecked = false,
    this.checkCallback,
    this.negativeText,
    this.negativeCallback,
    this.positiveText,
    this.positiveCallback,
    this.onClose,
  });

  @override
  State<CustomBottomDialog> createState() => _CustomBottomDialogState();
}

class _CustomBottomDialogState extends State<CustomBottomDialog> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();
    isChecked = widget.checkChecked;
  }

  @override
  void dispose() {
    super.dispose();
    widget.onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - viewInsets.bottom;
    final maxHeight = availableHeight * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ThemedContainer(
          context: context,
          border: Border.all(width: 0),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
          padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: CustomScrollView(
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if (widget.title != null)
                      SliverToBoxAdapter(
                        child: Center(
                          child: Text(
                            widget.title!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20.0,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: false,
                        (context, index) {
                          return widget.viewList[index];
                        },
                        childCount: widget.viewList.length,
                      ),
                    ),
                    if (widget.checkText != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 4.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                onChanged: (checked) {
                                  setState(() {
                                    isChecked = checked ?? false;
                                  });
                                  widget.checkCallback?.call(checked ?? false);
                                },
                                activeColor: theme.primary,
                              ),
                              Text(
                                widget.checkText!,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Buttons
                    if (widget.negativeText != null ||
                        widget.positiveText != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 8.0),
                          child: Row(
                            children: [
                              if (widget.negativeText != null) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: widget.negativeCallback,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                      ),
                                      side: BorderSide(color: theme.primary),
                                    ),
                                    child: Text(
                                      widget.negativeText!,
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                              ],
                              if (widget.positiveText != null) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: widget.positiveCallback,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                      ),
                                      side: BorderSide(color: theme.primary),
                                    ),
                                    child: Text(
                                      widget.positiveText!,
                                      style: TextStyle(
                                        color: theme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showCustomBottomDialog(BuildContext context, Widget dialog) {
  showModalBottomSheet(
    enableDrag: true,
    isScrollControlled: true,
    context: context,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
    ),
    builder: (context) => dialog,
  );
}
