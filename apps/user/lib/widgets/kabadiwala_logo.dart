import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Reusable official branding logo widget for Kabadiwala Connect.
/// Provides soft rounded or circular container styling, prevents sharp corners,
/// and guarantees preserved aspect ratios without distortion.
class KabadiwalaLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isCircular;
  final BorderRadiusGeometry? borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final BoxBorder? border;
  final String? semanticLabel;

  const KabadiwalaLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.isCircular = false,
    this.borderRadius,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(4.0),
    this.elevation = 0,
    this.border,
    this.semanticLabel = 'Kabadiwala Connect Logo',
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16.0);

    final Widget imageWidget = Image.asset(
      AppConstants.logoAsset,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) {
        // Safe fallback in minimal environments if asset bundle is unavailable
        return Icon(
          Icons.recycling,
          size: (height ?? width ?? 48) * 0.65,
          color: const Color(0xFF2E7D32),
        );
      },
    );

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : effectiveBorderRadius,
        border: border,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, (0.08 * (elevation / 2)).clamp(0.0, 1.0)),
                  blurRadius: elevation * 2,
                  offset: Offset(0, elevation / 2),
                ),
              ]
            : null,
      ),
      child: isCircular
          ? ClipOval(child: imageWidget)
          : ClipRRect(
              borderRadius: effectiveBorderRadius,
              child: imageWidget,
            ),
    );
  }
}
