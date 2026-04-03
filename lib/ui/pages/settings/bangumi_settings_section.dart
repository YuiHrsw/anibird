import 'package:flutter/material.dart';

import '../../state/settings_store.dart';
import 'settings_widgets.dart';

class BangumiSettingsSection extends StatefulWidget {
  const BangumiSettingsSection({
    super.key,
    required this.store,
  });

  final SettingsStore store;

  @override
  State<BangumiSettingsSection> createState() => _BangumiSettingsSectionState();
}

class _BangumiSettingsSectionState extends State<BangumiSettingsSection> {
  late final TextEditingController _userAgentController;
  late final TextEditingController _privateBaseUrlController;
  late final TextEditingController _oauthClientIdController;
  late final TextEditingController _oauthClientSecretController;
  late final TextEditingController _oauthRedirectUriController;
  late final TextEditingController _accessTokenController;

  @override
  void initState() {
    super.initState();
    final config = widget.store.value.config;
    _userAgentController = TextEditingController(
      text: config.bangumiUserAgent,
    );
    _privateBaseUrlController = TextEditingController(
      text: config.bangumiPrivateApiBaseUrl,
    );
    _oauthClientIdController = TextEditingController(
      text: config.bangumiOauthClientId,
    );
    _oauthClientSecretController = TextEditingController(
      text: config.bangumiOauthClientSecret,
    );
    _oauthRedirectUriController = TextEditingController(
      text: config.bangumiOauthRedirectUri,
    );
    _accessTokenController = TextEditingController(
      text: config.bangumiAccessToken,
    );
    widget.store.addListener(_handleStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_handleStoreChanged);
    _userAgentController.dispose();
    _privateBaseUrlController.dispose();
    _oauthClientIdController.dispose();
    _oauthClientSecretController.dispose();
    _oauthRedirectUriController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  void _handleStoreChanged() {
    final config = widget.store.value.config;
    _syncController(_userAgentController, config.bangumiUserAgent);
    _syncController(_privateBaseUrlController, config.bangumiPrivateApiBaseUrl);
    _syncController(_oauthClientIdController, config.bangumiOauthClientId);
    _syncController(
      _oauthClientSecretController,
      config.bangumiOauthClientSecret,
    );
    _syncController(_oauthRedirectUriController, config.bangumiOauthRedirectUri);
    _syncController(_accessTokenController, config.bangumiAccessToken);
  }

  void _syncController(TextEditingController controller, String nextValue) {
    if (controller.text == nextValue) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
      composing: TextRange.empty,
    );
  }

  Future<void> _save() async {
    final current = widget.store.value.config;
    final next = current.copyWith(
      bangumiUserAgent: _userAgentController.text,
      bangumiPrivateApiBaseUrl: _privateBaseUrlController.text,
      bangumiOauthClientId: _oauthClientIdController.text,
      bangumiOauthClientSecret: _oauthClientSecretController.text,
      bangumiOauthRedirectUri: _oauthRedirectUriController.text,
      bangumiAccessToken: _accessTokenController.text,
    );
    await widget.store.save(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('配置已保存')));
  }

  Future<void> _startOauthLogin() async {
    await _save();
    await widget.store.startBangumiOAuthLogin();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已打开浏览器，请完成 Bangumi 授权。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SettingsState>(
      valueListenable: widget.store,
      builder: (context, state, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: state.isSaving
                    ? null
                    : () async {
                        await _save();
                      },
                child: Text(state.isSaving ? '保存中...' : '保存'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-user-agent'),
              controller: _userAgentController,
              decoration: const InputDecoration(
                labelText: 'Bangumi User-Agent',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-bangumi-private-base-url'),
              controller: _privateBaseUrlController,
              decoration: const InputDecoration(
                labelText: 'Bangumi Private API Base URL',
                hintText: 'https://next.bgm.tv/p1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-bangumi-oauth-client-id'),
              controller: _oauthClientIdController,
              decoration: const InputDecoration(
                labelText: 'Bangumi OAuth Client ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-bangumi-oauth-client-secret'),
              controller: _oauthClientSecretController,
              decoration: const InputDecoration(
                labelText: 'Bangumi OAuth Client Secret',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-bangumi-oauth-redirect-uri'),
              controller: _oauthRedirectUriController,
              decoration: const InputDecoration(
                labelText: 'Bangumi OAuth Redirect URI',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('settings-bangumi-access-token'),
              controller: _accessTokenController,
              decoration: const InputDecoration(
                labelText: 'Bangumi Access Token',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            BangumiProfileCard(
              profile: state.bangumiProfile,
              error: state.bangumiProfileError,
              isLoading: state.isLoadingBangumiProfile,
              authError: state.bangumiAuthError,
              isAuthorizing: state.isBangumiAuthorizing,
              onRefresh: state.isSaving || state.isLoadingBangumiProfile
                  ? null
                  : widget.store.refreshBangumiProfile,
              onLogin: state.isSaving || state.isBangumiAuthorizing
                  ? null
                  : _startOauthLogin,
              onLogout: state.isSaving || state.isBangumiAuthorizing
                  ? null
                  : widget.store.logoutBangumi,
            ),
          ],
        );
      },
    );
  }
}
