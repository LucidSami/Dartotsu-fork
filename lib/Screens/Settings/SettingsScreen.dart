import 'package:dartotsu/Screens/Settings/BaseSettingsScreen.dart';
import 'package:dartotsu/Screens/Settings/SettingsAccountScreen.dart';
import 'package:dartotsu/Screens/Settings/SettingsAddonScreen.dart';
import 'package:dartotsu/Screens/Settings/SettingsThemeScreen.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../Adaptor/Settings/SettingsAdaptor.dart';
import '../../DataClass/Setting.dart';
import '../../Functions/Function.dart';
import '../../Theme/LanguageSwitcher.dart';
import 'SettingsAnimeScreen.dart';
import 'SettingsCommonScreen.dart';
import 'SettingsExtensionsScreen.dart';
import 'SettingsMangaScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<StatefulWidget> createState() => SettingsScreenState();
}

class SettingsScreenState extends BaseSettingsScreen {
  @override
  String title() => getString.settings;

  @override
  Widget icon() => ClipOval(
    child: Image.asset(
      'assets/images/logo.png',
      width: 64,
      height: 64,
      fit: BoxFit.cover,
    ),
  );

  @override
  List<Widget> get settingsList {
    return [
      SettingsAdaptor(settings: _buildSettings(context)),
      const SizedBox(height: 24),
      _buildInfoSection(context),
      const SizedBox(height: 42),
    ];
  }

  List<Setting> _buildSettings(BuildContext context) {
    return [
      Setting(
        type: SettingType.normal,
        name: getString.account,
        description: getString.accountDescription,
        icon: Icons.person,
        onClick: () => navigateToPage(context, const SettingsAccountScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: getString.theme,
        description: getString.themeDescription,
        icon: Icons.palette_outlined,
        onClick: () => navigateToPage(context, const SettingsThemeScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: getString.common,
        description: getString.commonDescription,
        icon: Icons.lightbulb_outline,
        onClick: () => navigateToPage(context, const SettingsCommonScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: getString.anime,
        description: getString.animeDescription,
        icon: Icons.movie_filter_rounded,
        onClick: () => navigateToPage(context, const SettingsAnimeScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: getString.manga,
        description: getString.mangaDescription,
        icon: Icons.import_contacts,
        onClick: () => navigateToPage(context, const SettingsMangaScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: getString.extension(2),
        description: getString.extensionsDescription,
        icon: Icons.extension,
        onClick: () =>
            navigateToPage(context, const SettingsExtensionsScreen()),
        isActivity: true,
      ),
      Setting(
        type: SettingType.normal,
        name: "Addons",
        description: "Manage and configure addons for enhanced functionality.",
        icon: Icons.add_rounded,
        onClick: () => navigateToPage(context, const SettingsAddonsScreen()),
        isActivity: true,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    loadVersion();
  }

  String appVersion = '';

  Future<void> loadVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    var hash = await loadEnv("hash");
    setState(() {
      appVersion = '${packageInfo.version}+$hash';
    });
  }

  Widget _buildInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Text(
        'Version $appVersion',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.grey,
        ),
      ),
    );
  }
}
