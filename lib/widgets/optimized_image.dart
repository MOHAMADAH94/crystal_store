import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Widget محسّن لتحميل الصور مع cache قوي
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final bool useShimmer;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.placeholderColor,
    this.useShimmer = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      // إعدادات cache محسّنة - زيادة الدقة للصور
      memCacheWidth: width != null ? (width! * 2).toInt() : 2000, // ضعف الحجم للدقة العالية
      memCacheHeight: height != null ? (height! * 2).toInt() : 2000, // ضعف الحجم للدقة العالية
      maxWidthDiskCache: 2000, // الحد الأقصى لعرض الصورة في cache - زيادة الدقة
      maxHeightDiskCache: 2000, // الحد الأقصى لارتفاع الصورة في cache - زيادة الدقة
      // إعدادات التحميل
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      // Placeholder محسّن
      placeholder: (context, url) {
        if (placeholder != null) return placeholder!;
        
        if (useShimmer) {
          return Shimmer.fromColors(
            baseColor: placeholderColor ?? Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              width: width,
              height: height,
              color: placeholderColor ?? Colors.grey[300],
            ),
          );
        }
        
        return Container(
          width: width,
          height: height,
          color: placeholderColor ?? Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      // Error widget محسّن
      errorWidget: (context, url, error) {
        if (errorWidget != null) return errorWidget!;
        
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(
            Icons.image_not_supported_rounded,
            color: Colors.grey,
            size: 40,
          ),
        );
      },
    );

    // تطبيق border radius إذا كان موجوداً
    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Widget محسّن للصور الدائرية
class OptimizedCircleImage extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const OptimizedCircleImage({
    super.key,
    required this.imageUrl,
    required this.radius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedImage(
      imageUrl: imageUrl,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius),
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
