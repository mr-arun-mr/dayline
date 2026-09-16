import 'database.dart';

/// Repairs visit history an older recorder could write.
///
/// Overlapping stays — the device in two places at once — were possible until
/// an arrival was made to end whatever stay was open elsewhere, and until a
/// crossing naming several overlapping circles was made to resolve to one of
/// them. The rows are still there, and nothing that happens later touches
/// them, so they are put right on the way in: the day showed the same hours
/// twice under two names, and no amount of walking about fixes that by itself.
///
/// Cheap and idempotent — a history with no overlaps in it comes out
/// unchanged — so it can simply run on every cold start rather than needing a
/// version to hang off.
///
/// Returns how many stays it shortened.
Future<int> tidyRecordedStays(DaylineDatabase db) async {
  final trimmed = await db.placesDao.tidyOverlappingStays();
  for (final visit in trimmed) {
    // The row this stay wrote onto the day says how long it lasted, and it
    // lasted less than it used to.
    await db.eventsDao.closeVisitEvent(visit);
  }
  return trimmed.length;
}
