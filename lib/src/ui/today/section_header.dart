import 'package:flutter/material.dart';

import '../theme.dart';

/// The small label above each group of rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.label,
    this.count,
    this.trailing,
    this.emphasis = false,
    super.key,
  });

  final String label;
  final int? count;
  final Widget? trailing;

  /// Overdue gets the error colour; everything else is quiet.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour =
        emphasis ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        18,
        DaylineTheme.gutter,
        6,
      ),
      child: Row(
        children: [
          Text(
            count == null ? label.toUpperCase() : '${label.toUpperCase()}  $count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colour,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}
