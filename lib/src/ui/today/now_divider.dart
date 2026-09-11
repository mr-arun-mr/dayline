import 'package:flutter/material.dart';

import '../theme.dart';

/// The line between what has happened and what has not.
///
/// Only drawn when looking at today — on any other day there is no "now" to
/// mark, and a line there would be a lie.
class NowDivider extends StatelessWidget {
  const NowDivider({required this.now, super.key});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DaylineTheme.gutter,
        vertical: 6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  )
                  .merge(monospacedFigures),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(left: 4),
              color: scheme.primary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
