import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final bool isCompact;
  final bool isFullPage;
  final String? message;

  const LoadingIndicator({
    super.key,
    this.isCompact = false,
    this.isFullPage = false,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const brandRed = Color(0xFFEE1C4B);

    final progressIndicator = CircularProgressIndicator(
      valueColor: const AlwaysStoppedAnimation<Color>(brandRed),
      strokeWidth: isCompact ? 2.0 : 4.0,
    );

    if (isCompact) {
      return SizedBox(
        width: 20,
        height: 20,
        child: progressIndicator,
      );
    }

    if (isFullPage) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            progressIndicator,
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: TextStyle(
                  fontFamily: 'Google Sans',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(child: progressIndicator);
  }
}
