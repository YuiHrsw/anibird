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
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _reactExpandedByMessageId = <String, bool>{};
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
    _chatStore = AppScope.of(context).chatStore;
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
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1D3C57), Color(0xFF315A78)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anibird Agent',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '可以让它推荐番剧、解释看点，也可以展开查看每一次工具调用拿到了什么。',
                            style: TextStyle(color: Colors.white70),
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
                          child: Text('先试试“推荐一些治愈日常番”或“介绍一下《葬送的芙莉莲》为什么值得看”。'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.separated(
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _ChatMessageItem(
                            key: ValueKey(message.id),
                            message: message,
                            reactExpanded:
                                _reactExpandedByMessageId[message.id] ?? false,
                            onReactExpandedChanged: (expanded) {
                              setState(() {
                                _reactExpandedByMessageId[message.id] = expanded;
                              });
                            },
                          );
                        },
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
  const _ChatMessageItem({
    super.key,
    required this.message,
    required this.reactExpanded,
    required this.onReactExpandedChanged,
  });

  final ChatMessage message;
  final bool reactExpanded;
  final ValueChanged<bool> onReactExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && message.steps.isNotEmpty) ...[
                  _ReactPanel(
                    message: message,
                    expanded: reactExpanded,
                    onExpandedChanged: onReactExpandedChanged,
                  ),
                  const SizedBox(height: 8),
                ],
                Card(
                  color: isUser ? const Color(0xFFD9F0F5) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isUser)
                          SelectableText(message.content)
                        else
                          MarkdownBody(
                            data: message.content,
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
                          ),
                        if (message.statusText != null &&
                            message.statusText!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F1F3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.isLoading) ...[
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    message.statusText!,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!message.isLoading && message.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RecommendationStrip(subjects: message.recommendations),
          ],
        ],
      ),
    );
  }
}

class _ReactPanel extends StatelessWidget {
  const _ReactPanel({
    required this.message,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final ChatMessage message;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final stepCount = message.steps.length;
    final statusLabel = message.isLoading ? '思考中' : '已完成';
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF7FAFB),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -3),
          initiallyExpanded: expanded,
          onExpansionChanged: onExpandedChanged,
          title: Text(
            'ReAct 过程 · $stepCount 步 · $statusLabel',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: Text(
            _reactPanelSubtitle(message),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            for (final entry in message.steps.asMap().entries)
              Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key == message.steps.length - 1 ? 0 : 8,
                ),
                child: _AgentStepTile(
                  index: entry.key + 1,
                  step: entry.value,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _reactPanelSubtitle(ChatMessage message) {
  final latestStep = message.steps.last;
  final thought = latestStep.thought.trim();
  if (thought.isNotEmpty) {
    return thought;
  }
  return '最近动作：${latestStep.action}';
}

class _AgentStepTile extends StatelessWidget {
  const _AgentStepTile({required this.index, required this.step});

  final int index;
  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thought = step.thought.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => _AgentStepSheet(index: index, step: step),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD9E4E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('步骤 $index', style: theme.textTheme.labelLarge),
                  const SizedBox(width: 8),
                  _StepStatusBadge(status: step.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF476273),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.open_in_full, size: 14, color: Color(0xFF476273)),
                ],
              ),
              if (thought.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  thought,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepStatusBadge extends StatelessWidget {
  const _StepStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'started' => ('进行中', const Color(0xFF315A78)),
      'completed' => ('完成', const Color(0xFF3B7A57)),
      'failed' => ('失败', const Color(0xFFB55745)),
      'rejected' => ('拒绝', const Color(0xFF8A6A1F)),
      _ => (status, const Color(0xFF5F6F7A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
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

class _AgentStepSheet extends StatelessWidget {
  const _AgentStepSheet({required this.index, required this.step});

  final int index;
  final AgentStep step;

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
                    '步骤 $index · ${step.action}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  _StepStatusBadge(status: step.status),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    if (step.thought.trim().isNotEmpty) ...[
                      Text('Thought', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      SelectableText(step.thought),
                      const SizedBox(height: 16),
                    ],
                    if (step.actionInputJson != null &&
                        step.actionInputJson!.isNotEmpty) ...[
                      Text('Action', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _StructuredPanel(content: step.actionInputJson!),
                      const SizedBox(height: 16),
                    ],
                    if (step.observationJson != null &&
                        step.observationJson!.isNotEmpty) ...[
                      Text(
                        'Observation',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _StructuredPanel(content: step.observationJson!),
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
