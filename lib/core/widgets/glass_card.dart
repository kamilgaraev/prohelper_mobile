import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/pro_theme.dart';

class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final double? height;
  final double? width;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool showShimmer;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.height,
    this.width,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.showShimmer = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ProHelperTheme.cardRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ProHelperTheme.glassBlurSigma,
          sigmaY: ProHelperTheme.glassBlurSigma,
        ),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: height,
            width: width,
            padding: padding,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E22).withOpacity(ProHelperTheme.glassOpacity),
              borderRadius: BorderRadius.circular(ProHelperTheme.cardRadius),
              border: Border.all(
                color: Colors.white.withOpacity(ProHelperTheme.glassBorderOpacity),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
              ),
              child: showShimmer
                  ? Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(0.1),
                      highlightColor: Colors.white.withOpacity(0.3),
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}
