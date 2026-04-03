import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_layout_scope.dart';
import 'chat/chat_page.dart';
import 'discover/discovery_page.dart';
import 'my/my_page.dart';
import 'settings/settings_page.dart';
import 'timeline/timeline_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _railBreakpoint = 600;
  static const double _topHolderHeight = 28;

  int _index = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  late final List<_TabDefinition> _tabs;

  @override
  void initState() {
    super.initState();
    _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      5,
      (index) => GlobalKey<NavigatorState>(),
    );
    _tabs = [
      _TabDefinition(
        label: '发现',
        icon: Icons.explore,
        pageBuilder: () => const DiscoveryPage(),
      ),
      _TabDefinition(
        label: '时间线',
        icon: Icons.timeline,
        pageBuilder: () => const TimelinePage(),
      ),
      _TabDefinition(
        label: '聊天',
        icon: Icons.forum,
        pageBuilder: () => const ChatPage(),
      ),
      _TabDefinition(
        label: '我的',
        icon: Icons.collections_bookmark,
        pageBuilder: () => const MyPage(),
      ),
      _TabDefinition(
        label: '设置',
        icon: Icons.settings,
        pageBuilder: () => const SettingsPage(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        return AppLayoutScope(
          useRailNavigation: useRail,
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) {
                return;
              }
              _handleBackPress();
            },
            child: Scaffold(
              body: useRail
                  ? Row(
                      children: [
                        SafeArea(
                          child: _buildNavigationRail(context),
                        ),
                        Expanded(child: _buildContentShell()),
                      ],
                    )
                  : _buildContentShell(),
              bottomNavigationBar: useRail ? null : _buildBottomNavigationBar(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContentShell() {
    return Column(
      children: [
        const SizedBox(height: _topHolderHeight),
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: _buildTabBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBody() {
    return IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          _TabNavigator(
            navigatorKey: _navigatorKeys[i],
            pageBuilder: _tabs[i].pageBuilder,
          ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: _onDestinationSelected,
      destinations: [
        for (final tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
      ],
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    final railBackgroundColor =
        theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;
    return SizedBox(
      width: 76,
      child: Theme(
        data: theme.copyWith(
          navigationRailTheme: const NavigationRailThemeData(
            minWidth: 72,
            minExtendedWidth: 72,
          ),
        ),
        child: NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          labelType: NavigationRailLabelType.all,
          useIndicator: true,
          backgroundColor: railBackgroundColor,
          leading: const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SizedBox(height: _topHolderHeight),
          ),
          destinations: [
            for (final tab in _tabs)
              NavigationRailDestination(
                icon: Icon(tab.icon),
                label: Text(tab.label),
              ),
          ],
        ),
      ),
    );
  }

  void _onDestinationSelected(int value) {
    if (value == _index) {
      _navigatorKeys[value].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _index = value;
    });
  }

  Future<void> _handleBackPress() async {
    final navigator = _navigatorKeys[_index].currentState;
    if (navigator != null && await navigator.maybePop()) {
      return;
    }
    if (_index != 0) {
      setState(() {
        _index = 0;
      });
      return;
    }
    await SystemNavigator.pop();
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({
    required this.navigatorKey,
    required this.pageBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget Function() pageBuilder;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
          builder: (_) => pageBuilder(),
          settings: settings,
        );
      },
    );
  }
}

class _TabDefinition {
  const _TabDefinition({
    required this.label,
    required this.icon,
    required this.pageBuilder,
  });

  final String label;
  final IconData icon;
  final Widget Function() pageBuilder;
}
