import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../backend/models/subject.dart';
import '../state/discovery_store.dart';
import '../widgets/subject_card.dart';
import 'subject_detail_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  late final TextEditingController _searchController;
  late final DiscoveryStore _store;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).discoveryStore;
    if (!_store.value.hasLoadedFeatured && !_store.value.isLoading) {
      _store.loadFeatured();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DiscoveryState>(
      valueListenable: _store,
      builder: (context, state, _) {
        final List<Subject> displayItems = state.keyword.isEmpty
            ? state.featured
            : state.searchResults;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E5F64), Color(0xFF6AA694)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '发现下一部想看的番',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '先用 Bangumi 榜单和搜索构建内容底座，后续聊天页会把这些能力暴露给 Agent。',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SearchBar(
                    controller: _searchController,
                    hintText: '搜索番剧、题材或关键词',
                    trailing: [
                      IconButton(
                        onPressed: () => _store.search(_searchController.text),
                        icon: const Icon(Icons.search),
                      ),
                    ],
                    onSubmitted: _store.search,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(state.error!),
              )
            else ...[
              Text(
                state.keyword.isEmpty ? '热门与高分动画' : '搜索结果',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...displayItems.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SubjectCard(
                    subject: subject,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SubjectDetailPage(subjectId: subject.id),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
