import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../backend/models/subject.dart';
import '../../state/discovery_store.dart';
import '../../widgets/subject_card.dart';
import '../subject_detail_page.dart';

class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final store = context.readAppDependencies.discoveryStore;
      if (!store.value.hasLoadedFeatured && !store.value.isLoading) {
        store.loadFeatured();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.discoveryStore;
    return ValueListenableBuilder<DiscoveryState>(
      valueListenable: store,
      builder: (context, state, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final List<Subject> displayItems = state.keyword.isEmpty
            ? state.featured
            : state.searchResults;
        return RefreshIndicator(
          onRefresh: store.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索番剧、题材或关键词',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  filled: false,
                ),
                onSubmitted: store.search,
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
                  state.keyword.isEmpty ? '热门动画' : '搜索结果',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (state.keyword.isEmpty)
                  SubjectNameGrid(
                    subjects: displayItems,
                    onTap: (subject) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SubjectDetailPage(subjectId: subject.id),
                        ),
                      );
                    },
                  )
                else
                  ...displayItems.map(
                    (subject) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        children: [
                          SubjectCard(
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
                          Divider(
                            height: 1,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
