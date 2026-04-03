import 'package:flutter/material.dart';

import '../../state/settings_store.dart';

class StorageSettingsSection extends StatelessWidget {
  const StorageSettingsSection({
    super.key,
    required this.state,
    required this.onClearImageCache,
    required this.onClearAllCaches,
  });

  final SettingsState state;
  final Future<void> Function() onClearImageCache;
  final Future<void> Function() onClearAllCaches;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        FilledButton.tonal(
          onPressed: state.isClearingImageCache || state.isClearingAllCaches
              ? null
              : onClearImageCache,
          child: Text(
            state.isClearingImageCache ? '清理图片缓存中...' : '清除图片缓存',
          ),
        ),
        OutlinedButton(
          onPressed: state.isClearingImageCache || state.isClearingAllCaches
              ? null
              : onClearAllCaches,
          child: Text(
            state.isClearingAllCaches ? '清理全部缓存中...' : '清除全部缓存',
          ),
        ),
      ],
    );
  }
}
