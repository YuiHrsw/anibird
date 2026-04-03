import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../app/app_scope.dart';
import '../../../backend/models/chat_message.dart';
import '../../../backend/models/subject.dart';
import '../../state/chat_store.dart';
import '../../widgets/app_network_image.dart';
import '../subject_detail_page.dart';

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
                  if (messages.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('欢迎使用智能助手'),
                        ),
                      ),
                    )
                  else ...[
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

class _ChatMessageItem extends StatefulWidget {
  const _ChatMessageItem({super.key, required this.message});

  final ChatMessage message;

  @override
  State<_ChatMessageItem> createState() => _ChatMessageItemState();
}

class _ChatMessageItemState extends State<_ChatMessageItem> {
  bool _showOlderTimeline = false;
  int _lastTimelineCount = 0;

  @override
  void initState() {
    super.initState();
    _lastTimelineCount = widget.message.contents.length;
  }

  @override
  void didUpdateWidget(covariant _ChatMessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCount = widget.message.contents.length;
    if (nextCount != _lastTimelineCount) {
      _lastTimelineCount = nextCount;
      if (nextCount > 1) {
        _showOlderTimeline = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == ChatRole.user;
    final contents = message.contents;
    final olderContents =
        contents.length > 1 ? contents.sublist(0, contents.length - 1) : const <ChatContentItem>[];
    final latestContent = contents.isNotEmpty ? contents.last : null;
    final messageBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser && olderContents.isNotEmpty)
          _CollapsedTimelineSection(
            itemCount: olderContents.length,
            isExpanded: _showOlderTimeline,
            onToggle: () {
              setState(() {
                _showOlderTimeline = !_showOlderTimeline;
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in olderContents.asMap().entries) ...[
                  _ContentItemView(index: entry.key + 1, item: entry.value),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        if (!isUser && latestContent != null) ...[
          _ContentItemView(
            index: contents.length,
            item: latestContent,
          ),
          const SizedBox(height: 8),
        ],
        if (isUser && latestContent != null)
          _MessageBubble(
            isUser: isUser,
            content: latestContent.content ?? '',
            isMarkdown: false,
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isUser)
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: messageBody,
            ),
          )
        else
          messageBody,
        if (!message.isLoading && message.recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          _RecommendationStrip(subjects: message.recommendations),
        ],
      ],
    );
  }
}

class _CollapsedTimelineSection extends StatelessWidget {
  const _CollapsedTimelineSection({
    required this.itemCount,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final int itemCount;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '折叠的流程消息（$itemCount）',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 8),
            child,
          ],
        ],
      ),
    );
  }
}

class _ContentItemView extends StatelessWidget {
  const _ContentItemView({required this.index, required this.item});

  final int index;
  final ChatContentItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      ChatContentItemType.text => _AssistantBubble(
        content: item.content ?? '',
      ),
      ChatContentItemType.toolCall => _ToolCallBubble(index: index, item: item),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isUser ? colorScheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: isMarkdown
            ? MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(
                  Theme.of(context),
                ).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? colorScheme.onPrimaryContainer : null,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : SelectableText(
                content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(
          p: Theme.of(context).textTheme.bodyMedium,
          codeblockDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          blockquoteDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ToolCallBubble extends StatelessWidget {
  const _ToolCallBubble({required this.index, required this.item});

  final int index;
  final ChatContentItem item;

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
  final ChatContentItem item;

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
  const _RecommendationPanel({
    required this.subject,
    required this.width,
  });

  final Subject subject;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: _RecommendationPoster(subject: subject),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subject.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '评分 ${subject.score.toStringAsFixed(1)} · Rank ${subject.rank == 0 ? '-' : subject.rank}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationStrip extends StatelessWidget {
  const _RecommendationStrip({required this.subjects});

  static const double _itemWidth = 112;
  static const double _itemGap = 12;

  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    const itemHeight = _itemWidth / 0.75 + 48;
    return SizedBox(
      width: double.infinity,
      height: itemHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _RecommendationPanel(
          subject: subjects[index],
          width: _itemWidth,
        ),
        separatorBuilder: (context, index) => const SizedBox(width: _itemGap),
        itemCount: subjects.length,
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
      return const AppNetworkImage(imageUrl: '');
    }
    return AppNetworkImage(imageUrl: subject.image, fit: BoxFit.cover);
  }
}

class _StructuredPanel extends StatelessWidget {
  const _StructuredPanel({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SelectableText(
        content,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
