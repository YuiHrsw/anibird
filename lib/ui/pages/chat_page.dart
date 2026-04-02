import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/app_scope.dart';
import '../../backend/models/chat_message.dart';
import '../../backend/models/subject.dart';
import '../state/chat_store.dart';
import 'subject_detail_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final TextEditingController _inputController;
  late final ChatStore _chatStore;
  bool _hasBoundStore = false;
  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasBoundStore) {
      _chatStore = AppScope.of(context).chatStore;
      _hasBoundStore = true;
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatViewState>(
      stream: _chatStore.stream,
      initialData: _chatStore.currentState,
      builder: (context, snapshot) {
        final chatState = snapshot.data ?? _chatStore.currentState;
        final messages = chatState.messages;
        final isGenerating = chatState.isGenerating;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || !_shouldAutoScroll) {
            return;
          }
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        });

        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Amadeus',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bangumi API 增强的 AI 问答助手',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (messages.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('欢迎使用 Amadeus >w<'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) => _ChatMessageItem(
                          key: ValueKey(messages[index].id),
                          message: messages[index],
                        ),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemCount: messages.length,
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        decoration: const InputDecoration(
                          hintText: '输入你的偏好或问题',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _send,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: isGenerating
                          ? _chatStore.stopGeneration
                          : () => _send(_inputController.text),
                      child: Text(isGenerating ? '停止' : '发送'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _send(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    await _chatStore.sendMessage(text);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final nextValue = _isNearBottom;
    if (nextValue != _shouldAutoScroll) {
      setState(() {
        _shouldAutoScroll = nextValue;
      });
    }
  }

  bool get _isNearBottom {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 80;
  }
}

class _ChatMessageItem extends StatelessWidget {
  const _ChatMessageItem({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final hasVisibleAssistantText = isUser || message.isError;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser && message.timeline.isNotEmpty) ...[
              for (final entry in message.timeline.asMap().entries) ...[
                _TimelineItemView(index: entry.key + 1, item: entry.value),
                const SizedBox(height: 8),
              ],
            ],
            if (hasVisibleAssistantText)
              _MessageBubble(
                isUser: isUser,
                content: message.content,
                isMarkdown: !isUser,
              ),
            if (!message.isLoading && message.recommendations.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RecommendationStrip(subjects: message.recommendations),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineItemView extends StatelessWidget {
  const _TimelineItemView({required this.index, required this.item});

  final int index;
  final ChatTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      ChatTimelineItemType.assistant => _AssistantBubble(
        content: item.content ?? '',
      ),
      ChatTimelineItemType.toolCall => _ToolCallBubble(index: index, item: item),
    };
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.isUser,
    required this.content,
    required this.isMarkdown,
  });

  final bool isUser;
  final String content;
  final bool isMarkdown;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isUser ? const Color(0xFFD9F0F5) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: isMarkdown
            ? MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium,
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFFF0F4F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: const Color(0xFFE8F1F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : SelectableText(content),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return _MessageBubble(isUser: false, content: content, isMarkdown: true);
  }
}

class _ToolCallBubble extends StatelessWidget {
  const _ToolCallBubble({required this.index, required this.item});

  final int index;
  final ChatTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _ToolDetailSheet(index: index, item: item),
        ),
        child: Text(
          '调用 ${item.action}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

class _ToolDetailSheet extends StatelessWidget {
  const _ToolDetailSheet({required this.index, required this.item});

  final int index;
  final ChatTimelineItem item;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '步骤 $index · ${item.action}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    if (item.actionInputJson != null &&
                        item.actionInputJson!.isNotEmpty) ...[
                      Text(
                        'Action',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _StructuredPanel(content: item.actionInputJson!),
                      const SizedBox(height: 16),
                    ],
                    if (item.observationJson != null &&
                        item.observationJson!.isNotEmpty) ...[
                      Text(
                        'Observation',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _StructuredPanel(content: item.observationJson!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 232,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SubjectDetailPage(subjectId: subject.id),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 128,
                width: double.infinity,
                child: _RecommendationPoster(subject: subject),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '评分 ${subject.score.toStringAsFixed(1)} · Rank ${subject.rank == 0 ? '-' : subject.rank}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Text(
                          subject.summary.isEmpty ? '暂无简介。' : subject.summary,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationStrip extends StatelessWidget {
  const _RecommendationStrip({required this.subjects});

  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SizedBox(
        height: 252,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) =>
              _RecommendationPanel(subject: subjects[index]),
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemCount: subjects.length,
        ),
      ),
    );
  }
}

class _RecommendationPoster extends StatelessWidget {
  const _RecommendationPoster({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    if (subject.image.isEmpty) {
      return Container(
        color: const Color(0xFFD8E8E1),
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Image.network(
      subject.image,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: const Color(0xFFD8E8E1),
        alignment: Alignment.center,
        child: Icon(
          Icons.movie_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _StructuredPanel extends StatelessWidget {
  const _StructuredPanel({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SelectableText(
        content,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
