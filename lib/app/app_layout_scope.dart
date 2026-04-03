import 'package:flutter/widgets.dart';

class AppLayoutScope extends InheritedWidget {
  const AppLayoutScope({
    super.key,
    required this.useRailNavigation,
    required super.child,
  });

  final bool useRailNavigation;

  static AppLayoutScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLayoutScope>();
  }

  static AppLayoutScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppLayoutScope not found in widget tree.');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppLayoutScope oldWidget) {
    return oldWidget.useRailNavigation != useRailNavigation;
  }
}
