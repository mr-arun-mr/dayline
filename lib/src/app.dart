import 'package:flutter/material.dart';

import 'ui/theme.dart';
import 'ui/today/today_screen.dart';

class DaylineApp extends StatelessWidget {
  const DaylineApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dayline',
    debugShowCheckedModeBanner: false,
    theme: DaylineTheme.light,
    darkTheme: DaylineTheme.dark,
    // Follows the system for now; Settings gets an explicit override in step 6.
    themeMode: ThemeMode.system,
    home: const TodayScreen(),
  );
}
