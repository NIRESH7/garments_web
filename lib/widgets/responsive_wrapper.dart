import 'package:flutter/material.dart';
import '../core/constants/layout_constants.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool useConstraint;
  final double? maxWidth;
  final EdgeInsets? padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.useConstraint = true,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = LayoutConstants.isMobile(context);
    
    if (isMobile) {
      return Padding(
        padding: padding ?? const EdgeInsets.all(LayoutConstants.s16),
        child: child,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? LayoutConstants.maxContentWidth,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(LayoutConstants.s32),
          child: child,
        ),
      ),
    );
  }
}
