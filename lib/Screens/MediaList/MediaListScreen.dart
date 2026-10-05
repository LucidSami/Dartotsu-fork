import 'package:dartotsu/Theme/LanguageSwitcher.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../Services/ServiceSwitcher.dart';
import 'MediaListTabs.dart';
import 'MediaListViewModel.dart';

class MediaListScreen extends StatefulWidget {
  final bool anime;
  final int id;

  const MediaListScreen({super.key, required this.anime, required this.id});

  @override
  MediaListScreenState createState() => MediaListScreenState();
}

class MediaListScreenState extends State<MediaListScreen> {
  late final MediaListViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    final service =
        Provider.of<MediaServiceProvider>(context, listen: false).currentService;
    _viewModel = Get.put(
      MediaListViewModel(),
      tag: "${service.getName}_${widget.anime ? 'anime' : 'manga'}",
    );
    _viewModel.loadAll(
      anime: widget.anime,
      userId: widget.id,
      service: service,
      force: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final currentService =
        Provider.of<MediaServiceProvider>(context).currentService;
    final service = currentService.data;
    final displayName = service.username.value.isNotEmpty
        ? service.username.value
        : currentService.getName;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          "$displayName ${getString.list(widget.anime ? getString.anime : getString.manga)}",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
            color: theme.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        iconTheme: IconThemeData(color: theme.primary),
      ),
      body: Obx(() {
        if (_viewModel.isLoading.value) {
          return const MediaListTabs(data: {"Loading": null});
        }

        if (_viewModel.mediaList.value == null ||
            _viewModel.mediaList.value!.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _viewModel.loadAll(
              anime: widget.anime,
              userId: widget.id,
              service: currentService,
              force: true,
            ),
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _viewModel.loadAll(
            anime: widget.anime,
            userId: widget.id,
            service: currentService,
            force: true,
          ),
          child: MediaListTabs(data: _viewModel.mediaList.value!),
        );
      }),
    );
  }
}
