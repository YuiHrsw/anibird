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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF137B80),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7F4),
        ),
        home: const HomePage(),
      ),
    );
  }
}
