import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/occurrence.dart';
import '../../model/rule_description.dart';
import '../../providers.dart';
import '../event_colors.dart';
import '../theme.dart';

/// The one thing about to happen, given room to breathe.
///
/// Larger than the rows around it and carrying a live countdown, because the
/// question this screen answers most often is "how long have I got".
class NextUpCard extends StatelessWidget {
  const NextUpCard({required this.occurrence, this.onTap, super.key});

  final Occurrence occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colour = EventColors.of(occurrence.event.colorValue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DaylineTheme.gutter,
        8,
        DaylineTheme.gutter,
        8,
      ),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'NEXT UP',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        occurrence.event.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            formatWallClock(occurrence.effectiveTimeOfDay),
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)
                                .merge(monospacedFigures),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '·',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: CountdownLabel(target: occurrence.localStart),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "in 2h 14m", counting down.
///
/// Watches the one-second tick on its own so that a ticking clock rebuilds
/// this label and nothing else on the screen.
class CountdownLabel extends ConsumerWidget {
  const CountdownLabel({required this.target, super.key});

  final DateTime target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now =
        ref.watch(secondTickProvider).value ?? ref.watch(clockProvider)();
    final theme = Theme.of(context);
    return Text(
      formatCountdown(target.difference(now)),
      style: theme.textTheme.titleMedium
          ?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          )
          .merge(monospacedFigures),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Human-sized countdown text.
///
/// Coarse far out and fine close in: nobody needs seconds three hours ahead,
/// and everybody wants them in the last minute.
String formatCountdown(Duration remaining) {
  if (remaining.isNegative) return 'now';

  final totalMinutes = remaining.inMinutes;
  if (totalMinutes < 1) return 'in ${remaining.inSeconds}s';
  if (totalMinutes < 60) return 'in ${totalMinutes}m';

  final hours = remaining.inHours;
  if (hours < 24) {
    final minutes = totalMinutes % 60;
    return minutes == 0 ? 'in ${hours}h' : 'in ${hours}h ${minutes}m';
  }

  final days = remaining.inDays;
  final restHours = hours % 24;
  return restHours == 0 ? 'in ${days}d' : 'in ${days}d ${restHours}h';
}
