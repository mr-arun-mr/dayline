import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/db/database.dart';
import 'src/db/debug_seed.dart';

/// Placeholder entry point. The Today screen lands in step 2 — for now this
/// only proves the database opens on a real device and, in debug builds,
/// seeds the sample day.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DaylineDatabase();
  if (kDebugMode) await DebugSeed.populate(db);
  runApp(DaylineApp(database: db));
}

class DaylineApp extends StatelessWidget {
  const DaylineApp({required this.database, super.key});

  final DaylineDatabase database;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dayline',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3B82F6)),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF3B82F6),
      brightness: Brightness.dark,
    ),
    home: const Scaffold(
      body: Center(child: Text('Dayline — step 1: data layer only')),
    ),
  );
}
