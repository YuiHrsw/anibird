import 'package:flutter/material.dart';

import 'app_scope.dart';
import '../ui/pages/home_page.dart';

class AnibirdApp extends StatelessWidget {
  const AnibirdApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: dependencies,
      child: MaterialApp(
        title: 'Anibird',
        debugShowCheckedModeBanner: false,
        theme: _getThemeData(
          ColorScheme.fromSeed(
            seedColor: Colors.pink,
            brightness: Brightness.light,
          ),
        ),
        home: const HomePage(),
      ),
    );
  }

  ThemeData _getThemeData(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
      ),
    );
  }
}
