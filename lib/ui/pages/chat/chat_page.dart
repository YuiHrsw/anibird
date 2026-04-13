import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../app/app_layout_scope.dart';
import '../../../app/app_scope.dart';
import '../../../backend/models/chat_message.dart';
import '../../../backend/models/chat_session.dart';
import '../../../backend/models/subject.dart';
import '../../state/chat_store.dart';
import '../../widgets/app_network_image.dart';
import '../subject_detail_page.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chatStore = context.chatStore;
    return StreamBuilder<ChatViewState>(
      stream: chatStore.stream,
      initialData: chatStore.currentState,
      builder: (context, snapshot) {
        final chatState = snapshot.data ?? chatStore.currentState;
        if (!chatState.isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final isWide =
            AppLayoutScope.maybeOf(context)?.useRailNavigation ?? false;
        if (!isWide) {
          return _ChatSessionListPage(
            state: chatState,
            onSelectSession: (sessionId) {
              chatStore.selectSession(sessionId);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ChatConversationPage(
                    sessionId: sessionId,
                    store: chatStore,
                  ),
                ),
              );
            },
            onCreateAndOpen: () async {
              await chatStore.createSession();
              final sessionId = chatStore.currentState.currentSessionId;
              if (context.mounted && sessionId != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _ChatConversationPage(
                      sessionId: sessionId,
                      store: chatStore,
                    ),
                  ),
                );
              }
            },
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _SessionListPanel(
                  sessions: chatState.sessions,
                  currentSessionId: chatState.currentSessionId,
                  generatingSessionIds: chatState.generatingSessionIds,
                  onCreateSession: chatStore.createSession,
                  onSelectSession: chatStore.selectSession,
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: _ChatConversationPane(
                state: chatState,
                sessionId: chatState.currentSessionId,
                onSend: chatStore.sendMessage,
                onStop: chatStore.stopGeneration,
                onRenameSession: chatStore.renameSession,
                onDeleteSession: chatStore.deleteSession,
                showHeader: true,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionListPanel extends StatelessWidget {
  const _SessionListPanel({
    required this.sessions,
    required this.currentSessionId,
    required this.generatingSessionIds,
    required this.onCreateSession,
    required this.onSelectSession,
    this.showCreateButton = true,
    this.showSelection = true,
  });

  final List<ChatSession> sessions;
  final String? currentSessionId;
  final Set<String> generatingSessionIds;
  final Future<void> Function() onCreateSession;
  final ValueChanged<String> onSelectSession;
  final bool showCreateButton;
  final bool showSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCreateButton) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: OutlinedButton.icon(
              onPressed: onCreateSession,
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('新建会话'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: sessions.length,
            // separatorBuilder: (context, index) => Divider(
            //   height: 1,
            //   color: Theme.of(context).colorScheme.outlineVariant,
            // ),
            itemBuilder: (context, index) {
              final session = sessions[index];
              final selected = showSelection && session.id == currentSessionId;
              return _SessionListTile(
                session: session,
                selected: selected,
                isGenerating: generatingSessionIds.contains(session.id),
                onTap: () => onSelectSession(session.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SessionListTile extends StatelessWidget {
  const _SessionListTile({
    required this.session,
    required this.selected,
    required this.isGenerating,
    required this.onTap,
  });

  final ChatSession session;
  final bool selected;
  final bool isGenerating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: selected ? colorScheme.secondary.withAlpha(20) : null,
      child: InkWell(
        splashColor: Colors.transparent,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              color: selected ? colorScheme.secondary : null,
              width: 4,
              height: 80,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSessionListPage extends StatelessWidget {
  const _ChatSessionListPage({
    required this.state,
    required this.onSelectSession,
    required this.onCreateAndOpen,
  });

  final ChatViewState state;
  final ValueChanged<String> onSelectSession;
  final Future<void> Function() onCreateAndOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: onCreateAndOpen,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('新建会话'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _SessionListPanel(
              sessions: state.sessions,
              currentSessionId: state.currentSessionId,
              generatingSessionIds: state.generatingSessionIds,
              onCreateSession: onCreateAndOpen,
              onSelectSession: onSelectSession,
              showCreateButton: false,
              showSelection: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatConversationPage extends StatelessWidget {
  const _ChatConversationPage({required this.sessionId, required this.store});

  final String sessionId;
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatViewState>(
      stream: store.stream,
      initialData: store.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? store.currentState;
        ChatSession? session;
        for (final item in state.sessions) {
          if (item.id == sessionId) {
            session = item;
            break;
          }
        }
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const SizedBox.shrink();
        }

        if (state.currentSessionId != sessionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            store.selectSession(sessionId);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(session.title),
            actions: [
              _ConversationActionsButton(
                session: session,
                isGenerating: state.isSessionGenerating(session.id),
                onRenameSession: store.renameSession,
                onDeleteSession: (id) async {
                  await store.deleteSession(id);
                  if (context.mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          body: _ChatConversationPane(
            state: state.copyWith(currentSessionId: sessionId),
            sessionId: sessionId,
            onSend: store.sendMessage,
            onStop: store.stopGeneration,
            onRenameSession: store.renameSession,
            onDeleteSession: store.deleteSession,
            showHeader: false,
          ),
        );
      },
    );
  }
}

class _ChatConversationPane extends StatefulWidget {
  const _ChatConversationPane({
    required this.state,
    required this.sessionId,
    required this.onSend,
    required this.onStop,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.showHeader,
  });

  final ChatViewState state;
  final String? sessionId;
  final Future<void> Function(String text) onSend;
  final VoidCallback onStop;
  final Future<void> Function(String sessionId, String title) onRenameSession;
  final Future<void> Function(String sessionId) onDeleteSession;
  final bool showHeader;

  @override
  State<_ChatConversationPane> createState() => _ChatConversationPaneState();
}

class _ChatConversationPaneState extends State<_ChatConversationPane> {
  late final TextEditingController _inputController;
  final ScrollController _scrollController = ScrollController();
  bool _shouldAutoScroll = true;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant _ChatConversationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId) {
      _inputController.clear();
      _shouldAutoScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
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
    final session = widget.state.currentSession;
    final messages = widget.state.messages;
    final isGenerating = widget.state.isGenerating;

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
        if (widget.showHeader)
          _ConversationHeader(
            title: session?.title ?? '新对话',
            isGenerating: isGenerating,
            actions: session == null
                ? null
                : [
                    _ConversationActionsButton(
                      session: session,
                      isGenerating: isGenerating,
                      onRenameSession: widget.onRenameSession,
                      onDeleteSession: widget.onDeleteSession,
                    ),
                  ],
          ),
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
                      ? widget.onStop
                      : () => _send(_inputController.text),
                  child: Text(isGenerating ? '停止' : '发送'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _send(String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    await widget.onSend(text);
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

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.title,
    required this.isGenerating,
    this.actions,
  });

  final String title;
  final bool isGenerating;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(
      automaticallyImplyLeading: false,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
    );
    return SizedBox(height: appBar.preferredSize.height, child: appBar);
  }
}

class _ConversationActionsButton extends StatelessWidget {
  const _ConversationActionsButton({
    required this.session,
    required this.isGenerating,
    required this.onRenameSession,
    required this.onDeleteSession,
  });

  final ChatSession session;
  final bool isGenerating;
  final Future<void> Function(String sessionId, String title) onRenameSession;
  final Future<void> Function(String sessionId) onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SessionAction>(
      tooltip: '更多操作',
      onSelected: (action) async {
        switch (action) {
          case _SessionAction.rename:
            await _showRenameSessionDialog(
              context,
              session: session,
              onRenameSession: onRenameSession,
            );
            return;
          case _SessionAction.delete:
            await _showDeleteSessionDialog(
              context,
              session: session,
              onDeleteSession: onDeleteSession,
            );
            return;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<_SessionAction>(
          value: _SessionAction.rename,
          child: Text('修改标题'),
        ),
        PopupMenuItem<_SessionAction>(
          value: _SessionAction.delete,
          enabled: !isGenerating,
          child: Text(isGenerating ? '生成中不可删除' : '删除会话'),
        ),
      ],
    );
  }
}

enum _SessionAction { rename, delete }

Future<void> _showRenameSessionDialog(
  BuildContext context, {
  required ChatSession session,
  required Future<void> Function(String sessionId, String title)
  onRenameSession,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _RenameSessionDialog(initialTitle: session.title),
  );
  if (result == null) {
    return;
  }
  await onRenameSession(session.id, result);
}

Future<void> _showDeleteSessionDialog(
  BuildContext context, {
  required ChatSession session,
  required Future<void> Function(String sessionId) onDeleteSession,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('删除会话'),
        content: Text('会话“${session.title}”删除后将无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) {
    return;
  }
  await onDeleteSession(session.id);
}

class _RenameSessionDialog extends StatefulWidget {
  const _RenameSessionDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameSessionDialog> createState() => _RenameSessionDialogState();
}

class _RenameSessionDialogState extends State<_RenameSessionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('修改会话标题'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '输入会话标题'),
        onSubmitted: (value) {
          Navigator.of(context).pop(value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('保存'),
        ),
      ],
    );
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

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.role == ChatRole.user;
    final contents = message.contents;
    final visibleContents = contents
        .where((item) => !_isHiddenUiTool(item))
        .toList(growable: false);
    final finalAnswerMarkerIndex = _lastFinalAnswerMarkerIndex(contents);
    final visibleFinalContents = finalAnswerMarkerIndex == null
        ? visibleContents
        : contents
              .skip(finalAnswerMarkerIndex + 1)
              .where((item) => !_isHiddenUiTool(item))
              .toList(growable: false);
    final visibleProcessContents = finalAnswerMarkerIndex == null
        ? const <ChatContentItem>[]
        : contents
              .take(finalAnswerMarkerIndex + 1)
              .where((item) => !_isHiddenUiTool(item))
              .toList(growable: false);
    final olderContents = finalAnswerMarkerIndex == null
        ? (visibleContents.length > 1
              ? visibleContents.sublist(0, visibleContents.length - 1)
              : const <ChatContentItem>[])
        : visibleProcessContents;
    final latestContent = finalAnswerMarkerIndex == null
        ? (visibleContents.isNotEmpty ? visibleContents.last : null)
        : (visibleFinalContents.isNotEmpty ? visibleFinalContents.last : null);
    final mainVisibleContents = finalAnswerMarkerIndex == null
        ? (latestContent == null ? const <ChatContentItem>[] : [latestContent])
        : visibleFinalContents;
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
        if (!isUser)
          ...mainVisibleContents.asMap().entries.expand(
            (entry) => [
              _ContentItemView(index: entry.key + 1, item: entry.value),
              const SizedBox(height: 8),
            ],
          ),
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

  int? _lastFinalAnswerMarkerIndex(List<ChatContentItem> items) {
    for (var index = items.length - 1; index >= 0; index -= 1) {
      final item = items[index];
      if (item.type == ChatContentItemType.toolCall &&
          item.action == 'mark_final_answer_start') {
        return index;
      }
    }
    return null;
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
                    '已完成 $itemCount 步操作',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[const SizedBox(height: 8), child],
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
      ChatContentItemType.text => _AssistantBubble(content: item.content ?? ''),
      ChatContentItemType.toolCall => _ToolCallText(item: item),
    };
  }
}

bool _isHiddenUiTool(ChatContentItem item) {
  return false;
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
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
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
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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

class _ToolCallText extends StatelessWidget {
  const _ToolCallText({required this.item});

  final ChatContentItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '已调用 ${item.action}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  const _RecommendationPanel({required this.subject, required this.width});

  final Subject subject;
  final double width;

  @override
  Widget build(BuildContext context) {
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${subject.score.toStringAsFixed(1)} · Rank ${subject.rank == 0 ? '-' : subject.rank}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        itemBuilder: (context, index) =>
            _RecommendationPanel(subject: subjects[index], width: _itemWidth),
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
