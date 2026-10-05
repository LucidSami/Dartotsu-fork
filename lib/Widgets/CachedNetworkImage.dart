import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Widget cachedNetworkImage({
  required String? imageUrl,
  BoxFit? fit,
  double? width,
  double? height,
  Widget Function(BuildContext, String)? placeholder,
  Widget Function(BuildContext, String, dynamic)? errorWidget,
}) {
  if (imageUrl == null || imageUrl.trim().isEmpty) {
    if (errorWidget != null && Get.context != null) {
      return SizedBox(
        width: width,
        height: height,
        child: errorWidget.call(Get.context!, "", null),
      );
    }
    return SizedBox(
      width: width,
      height: height,
    );
  }

  final int? memWidth = (width != null && width.isFinite && width > 0)
      ? (width * 2).toInt()
      : null;
  final int? memHeight = (height != null && height.isFinite && height > 0)
      ? (height * 2).toInt()
      : null;

  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit ?? BoxFit.cover,
    width: width,
    height: height,
    memCacheWidth: memWidth,
    memCacheHeight: memHeight,
    filterQuality: FilterQuality.medium,
    fadeInDuration: const Duration(milliseconds: 150),
    fadeOutDuration: const Duration(milliseconds: 100),
    placeholder: placeholder ?? (context, url) => const SizedBox.shrink(),
    errorWidget:
        errorWidget ?? (context, url, error) => const SizedBox.shrink(),
  );
}
