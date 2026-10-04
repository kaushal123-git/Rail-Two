import 'package:flutter/material.dart';

class LocoBranding {
  static const String appName = 'LOCO';
  static const String tagline = 'Intelligent Urban Rail Mobility';
  static const String subtitle = 'Mumbai Suburban Railway';
  static const String version = 'v2.4.0 (Production Build)';
  static const String logoAsset = 'assets/loco_logo.png';

  /// High-resolution full brand logo featuring the official train & embedded LOCO emblem
  static Widget fullLogo({double size = 120, BoxFit fit = BoxFit.contain}) {
    return Image.asset(
      logoAsset,
      width: size,
      height: size,
      fit: fit,
      semanticLabel: 'LOCO Logo',
      errorBuilder: (context, error, stackTrace) => appIcon(size: size),
    );
  }

  /// App icon mark featuring the official logo without any extra text
  static Widget appIcon({double size = 48}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        logoAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'LOCO Logo',
      ),
    );
  }

  /// Official brand logo presentation for headers and footers (solely the logo image without duplicate LOCO text)
  static Widget wordmark({
    double fontSize = 28,
    Color? color,
    bool showDot = false,
    bool showLogo = true,
  }) {
    return Image.asset(
      logoAsset,
      height: fontSize * 1.6,
      fit: BoxFit.contain,
      semanticLabel: 'LOCO Logo',
    );
  }
}
