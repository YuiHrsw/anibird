import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../api/my_collections_cache_repository.dart';

class AppCacheService {
  AppCacheService(
    this._myCollectionsCacheRepository, {
    Future<void> Function()? clearVolatileCaches,
  }) : _clearVolatileCaches = clearVolatileCaches;

  final MyCollectionsCacheRepository _myCollectionsCacheRepository;
  final Future<void> Function()? _clearVolatileCaches;

  Future<void> clearImageCache() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await DefaultCacheManager().emptyCache();
  }

  Future<void> clearAllCaches() async {
    await clearImageCache();
    await _myCollectionsCacheRepository.clear();
    await _clearVolatileCaches?.call();
  }
}
