import 'package:flutter/material.dart';

import '../../../backend/models/app_config.dart';
import '../../state/settings_store.dart';
import 'settings_widgets.dart';

class BangumiSettingsSection extends StatefulWidget {
  const BangumiSettingsSection({
    super.key,
    required this.state,
    required this.config,
    required this.onChanged,
    required this.onRefresh,
    required this.onLogin,
    required this.onLogout,
  });

  final SettingsState state;
  final AppConfig config;
  final ValueChanged<AppConfig> onChanged;
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLogin;
  final Future<void> Function()? onLogout;

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
    _userAgentController = TextEditingController(
      text: widget.config.bangumiUserAgent,
    );
    _privateBaseUrlController = TextEditingController(
      text: widget.config.bangumiPrivateApiBaseUrl,
    );
    _oauthClientIdController = TextEditingController(
      text: widget.config.bangumiOauthClientId,
    );
    _oauthClientSecretController = TextEditingController(
      text: widget.config.bangumiOauthClientSecret,
    );
    _oauthRedirectUriController = TextEditingController(
      text: widget.config.bangumiOauthRedirectUri,
    );
    _accessTokenController = TextEditingController(
      text: widget.config.bangumiAccessToken,
    );
  }

  @override
  void didUpdateWidget(covariant BangumiSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncController(
      _userAgentController,
      oldWidget.config.bangumiUserAgent,
      widget.config.bangumiUserAgent,
    );
    _syncController(
      _privateBaseUrlController,
      oldWidget.config.bangumiPrivateApiBaseUrl,
      widget.config.bangumiPrivateApiBaseUrl,
    );
    _syncController(
      _oauthClientIdController,
      oldWidget.config.bangumiOauthClientId,
      widget.config.bangumiOauthClientId,
    );
    _syncController(
      _oauthClientSecretController,
      oldWidget.config.bangumiOauthClientSecret,
      widget.config.bangumiOauthClientSecret,
    );
    _syncController(
      _oauthRedirectUriController,
      oldWidget.config.bangumiOauthRedirectUri,
      widget.config.bangumiOauthRedirectUri,
    );
    _syncController(
      _accessTokenController,
      oldWidget.config.bangumiAccessToken,
      widget.config.bangumiAccessToken,
    );
  }

  @override
  void dispose() {
    _userAgentController.dispose();
    _privateBaseUrlController.dispose();
    _oauthClientIdController.dispose();
    _oauthClientSecretController.dispose();
    _oauthRedirectUriController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  void _syncController(
    TextEditingController controller,
    String oldValue,
    String newValue,
  ) {
    if (oldValue != newValue && controller.text != newValue) {
      controller.text = newValue;
    }
  }

  void _emitChanged() {
    widget.onChanged(
      widget.config.copyWith(
        bangumiUserAgent: _userAgentController.text,
        bangumiPrivateApiBaseUrl: _privateBaseUrlController.text,
        bangumiOauthClientId: _oauthClientIdController.text,
        bangumiOauthClientSecret: _oauthClientSecretController.text,
        bangumiOauthRedirectUri: _oauthRedirectUriController.text,
        bangumiAccessToken: _accessTokenController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const ValueKey('settings-user-agent'),
          controller: _userAgentController,
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Bangumi User-Agent',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('settings-bangumi-private-base-url'),
          controller: _privateBaseUrlController,
          onChanged: (_) => _emitChanged(),
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
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Bangumi OAuth Client ID',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('settings-bangumi-oauth-client-secret'),
          controller: _oauthClientSecretController,
          onChanged: (_) => _emitChanged(),
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
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Bangumi OAuth Redirect URI',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('settings-bangumi-access-token'),
          controller: _accessTokenController,
          onChanged: (_) => _emitChanged(),
          decoration: const InputDecoration(
            labelText: 'Bangumi Access Token',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 20),
        BangumiProfileCard(
          profile: widget.state.bangumiProfile,
          error: widget.state.bangumiProfileError,
          isLoading: widget.state.isLoadingBangumiProfile,
          authError: widget.state.bangumiAuthError,
          isAuthorizing: widget.state.isBangumiAuthorizing,
          onRefresh: widget.onRefresh,
          onLogin: widget.onLogin,
          onLogout: widget.onLogout,
        ),
      ],
    );
  }
}
