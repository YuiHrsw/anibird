import 'package:flutter/material.dart';

import '../../state/settings_store.dart';
import 'settings_widgets.dart';

class BangumiSettingsSection extends StatelessWidget {
  const BangumiSettingsSection({
    super.key,
    required this.store,
  });

  final SettingsStore store;

  Future<void> _startOauthLogin(BuildContext context) async {
    await store.startBangumiOAuthLogin();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已打开浏览器，请完成 Bangumi 授权。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: store,
      builder: (context, state, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bangumi 固定接入参数已内置在项目配置中，这里只保留登录态与授权操作。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            BangumiProfileCard(
              profile: state.bangumiProfile,
              error: state.bangumiProfileError,
              isLoading: state.isLoadingBangumiProfile,
              authError: state.bangumiAuthError,
              isAuthorizing: state.isBangumiAuthorizing,
              onLogin: state.isSaving
                  ? null
                  : () => _startOauthLogin(context),
              onLogout: state.isSaving || state.isBangumiAuthorizing
                  ? null
                  : store.logoutBangumi,
            ),
          ],
        );
      },
    );
  }
}
