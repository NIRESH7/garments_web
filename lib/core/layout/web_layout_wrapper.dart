import 'package:flutter/material.dart';
import '../constants/layout_constants.dart';

class WebLayoutWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool centerContent;
  final Color? backgroundColor;

  const WebLayoutWrapper({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.centerContent = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    if (!isWeb) {
      return child;
    }

    return Container(
      color: backgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? LayoutConstants.maxContentWidth,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

class WebFormWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const WebFormWrapper({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    if (!isWeb) {
      return child;
    }

    return WebLayoutWrapper(
      maxWidth: 800,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title!,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (actions != null) Row(children: actions!),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class WebTableWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;

  const WebTableWrapper({
    super.key,
    required this.child,
    this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isWeb = LayoutConstants.isWeb(context);
    
    if (!isWeb) {
      return child;
    }

    return WebLayoutWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title!,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (actions != null) Row(children: actions!),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}