import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'ui/theme.dart';
import 'ui/today/today_screen.dart';

class DaylineApp extends ConsumerWidget {
  const DaylineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Dayline',
    debugShowCheckedModeBanner: false,
    theme: DaylineTheme.light,
    darkTheme: DaylineTheme.dark,
    // Follows the system until the user says otherwise in Settings.
    themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
    home: const TodayScreen(),
  );
}
