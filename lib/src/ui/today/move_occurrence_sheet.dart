import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/event.dart';
import '../../model/occurrence.dart';
import '../../providers.dart';

/// Moves a single occurrence to another time, leaving the series alone.
///
/// Writes a MOVED override rather than editing the rule — the whole point is
/// that tomorrow's gym is still at seven.
Future<void> showMoveOccurrenceSheet(
  BuildContext context,
  WidgetRef ref,
  Occurrence occurrence,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(
      hour: occurrence.effectiveTimeOfDay ~/ 60,
      minute: occurrence.effectiveTimeOfDay % 60,
    ),
    helpText: 'Move to',
  );
  if (picked == null) return;

  final minutes = picked.hour * 60 + picked.minute;
  final dao = ref.read(eventsDaoProvider);

  if (minutes == occurrence.event.timeOfDay) {
    // Back to the rule's own time, so the exception is no longer an exception.
    await dao.clearOverride(occurrence.eventId, occurrence.date);
    return;
  }

  await dao.setOverride(EventOverride(
    eventId: occurrence.eventId,
    date: occurrence.date,
    type: OverrideType.moved,
    newTimeOfDay: minutes,
  ));
}
