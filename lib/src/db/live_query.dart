import 'dart:async';

/// A query that re-runs whenever the tables behind it change.
///
/// Deliberately not drift's own `.watch()`. Two reasons, both learned the hard
/// way: a watched query covers a single statement, where the reads here span
/// several tables and some Dart in between; and a subscription to drift's
/// query stream does not finish cancelling under `flutter_test`'s fake clock,
/// so any widget test touching one hangs until its ten-minute timeout.
///
/// Owning the controller also lets a burst of writes — saving an event touches
/// its table more than once — collapse into a single re-read.
Stream<T> liveQuery<T>({
  required Stream<void> updates,
  required Future<T> Function() read,
}) {
  late final StreamController<T> controller;
  StreamSubscription<void>? subscription;
  var running = false;
  var restartWanted = false;

  Future<void> emit() async {
    if (running) {
      restartWanted = true;
      return;
    }
    running = true;
    try {
      do {
        restartWanted = false;
        final value = await read();
        if (controller.isClosed) return;
        controller.add(value);
      } while (restartWanted);
    } catch (error, stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    } finally {
      running = false;
    }
  }

  controller = StreamController<T>(
    onListen: () {
      subscription = updates.listen((_) => emit());
      emit();
    },
    onCancel: () async {
      final active = subscription;
      subscription = null;
      await active?.cancel();
    },
  );
  return controller.stream;
}
