import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartotsu/Functions/Function.dart';
import 'package:dartotsu/Screens/Extensions/ExtensionScreen.dart';
import 'package:dartotsu/Screens/Settings/SettingsScreen.dart';
import 'package:dartotsu/Widgets/AlertDialogBuilder.dart';
import 'package:dartotsu/Widgets/CustomBottomDialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:provider/provider.dart';

import '../../Services/ServiceSwitcher.dart';
import '../../Theme/LanguageSwitcher.dart';

class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  SettingsBottomSheetState createState() => SettingsBottomSheetState();
}

class SettingsBottomSheetState extends State<SettingsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    var s = Provider.of<MediaServiceProvider>(context, listen: false)
        .currentService;

    var service = s.data;

    return CustomBottomDialog(
      viewList: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 24.0),
          child: (Row(
            children: [
              Obx(
                () {
                  return CircleAvatar(
                    radius: 26.0,
                    backgroundImage: service.avatar.value.isNotEmpty
                        ? CachedNetworkImageProvider(service.avatar.value)
                        : null,
                    backgroundColor: Colors.transparent,
                    child: service.avatar.value.isEmpty
                        ? Icon(Icons.person,
                            color: Theme.of(context).primaryColor)
                        : null,
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Obx(() {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (service.token.value.isNotEmpty) ...[
                        Text(
                          service.username.value,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () {
                            AlertDialogBuilder(context)
                              ..setTitle(getString.logout(s.getName))
                              ..setMessage(getString.confirmLogout)
                              ..setPositiveButton(getString.yes, () {
                                service.removeSavedToken();
                                Navigator.of(context).pop();
                              })
                              ..setNegativeButton(getString.no, null)
                              ..show();
                          },
                          child: Text(
                            getString.logout(""),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () => service.login(context),
                          child: Text(
                            getString.login,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Theme.of(context).colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ),

            ],
          )),
        ),
        const SizedBox(height: 24.0),
        _buildListTile(context, getString.extension(2), Icons.extension,
            const ExtensionScreen()),
        const SizedBox(height: 10.0),
        _buildListTile(context, getString.settings, Icons.settings,
            const SettingsScreen()),
      ],
    );
  }

  Widget _buildListTile(
      BuildContext context, String title, IconData icon, Widget open) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        leading: Icon(
          icon,
          color: Theme.of(context).primaryColor,
        ),
        onTap: () {
          Navigator.of(context).pop();
          navigateToPage(context, open);
        },
      ),
    );
  }
}
