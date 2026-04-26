import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../config/constants.dart';
import '../../data/models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/formatters.dart';
import '../common/availability_badge.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? participantName;
  final String? participantAvatarUrl;
  final String? participantRole;
  final bool? participantIsAvailable;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.participantName,
    this.participantAvatarUrl,
    this.participantRole,
    this.participantIsAvailable,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  static final RegExp _conversationIdPattern = RegExp(r'^[a-fA-F0-9]{24}$');
  String? _currentUserId;
  int _lastMessageCount = 0;
  bool _invalidConversationId = false;

  @override
  void initState() {
    super.initState();
    final conversationId = widget.conversationId.trim();
    if (!_conversationIdPattern.hasMatch(conversationId)) {
      _invalidConversationId = true;
      return;
    }
    Future.microtask(_bootstrapConversation);
  }

  Future<void> _bootstrapConversation() async {
    try {
      _currentUserId = await SecureStorage.getUserId();
    } catch (_) {
      // On web, secure storage can fail transiently; continue without user id.
      _currentUserId = null;
    }

    if (!mounted) return;
    setState(() {});

    final notifier = ref.read(chatProvider.notifier);
    await notifier.loadMessages(widget.conversationId);
    await notifier.markAsRead(widget.conversationId);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveCurrentUserIdIfNeeded() async {
    if ((_currentUserId ?? '').isNotEmpty) return;
    try {
      _currentUserId = await SecureStorage.getUserId();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Keep null and let caller handle with explicit UX.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messagesFor(widget.conversationId);
    final conversation = chatState.conversationById(widget.conversationId);
    final hasKnownConversation = conversation != null;

    final resolvedName =
        (conversation?.participantName.trim().isNotEmpty ?? false)
        ? conversation!.participantName
        : (widget.participantName?.trim().isNotEmpty ?? false)
        ? widget.participantName!.trim()
        : 'Conversation';

    final resolvedAvatar =
        (conversation?.participantAvatarUrl?.trim().isNotEmpty ?? false)
        ? conversation!.participantAvatarUrl!.trim()
        : (widget.participantAvatarUrl?.trim().isNotEmpty ?? false)
        ? widget.participantAvatarUrl!.trim()
        : null;

    final resolvedParticipantRole =
        conversation?.participantRole ?? widget.participantRole;
    final resolvedParticipantIsAvailable =
        conversation?.participantIsAvailable ?? widget.participantIsAvailable;

    final showUnavailableBadge =
        resolvedParticipantRole == 'ARTISAN' &&
        resolvedParticipantIsAvailable == false;

    final isConversationLoading =
        chatState.isMessagesLoading(widget.conversationId) && messages.isEmpty;

    if (_invalidConversationId) {
      return Scaffold(
        appBar: AppBar(title: Text('chat.title'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Conversation invalide. Veuillez ouvrir une conversation depuis la liste.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/chat'),
                  child: const Text('Retour aux conversations'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      _scrollToBottom();
    }

    if (chatState.authRequired) {
      return Scaffold(
        appBar: AppBar(title: Text('chat.title'.tr())),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 34),
                const SizedBox(height: 12),
                Text(
                  'Session expiree. Veuillez vous reconnecter.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Se reconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              backgroundImage: resolvedAvatar != null
                  ? NetworkImage(resolvedAvatar)
                  : null,
              child: resolvedAvatar == null
                  ? Text(
                      resolvedName.isNotEmpty
                          ? resolvedName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: theme.colorScheme.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          resolvedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (showUnavailableBadge)
                        const UnavailableBadge(compact: true),
                    ],
                  ),
                  Text(
                    hasKnownConversation ? 'Messagerie SMS' : 'Chargement…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: isConversationLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? Center(
                    child: Text(
                      chatState.errorMessage ?? 'Aucun message',
                      style: theme.textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMine = msg.senderId == _currentUserId;
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: AnimatedSlide(
                          offset: Offset.zero,
                          duration: AppConstants.animFast,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            decoration: BoxDecoration(
                              color: isMine
                                  ? theme.colorScheme.primary
                                  : theme.cardTheme.color,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMine ? 16 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  msg.content,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isMine ? Colors.black : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  Formatters.relativeDate(msg.createdAt),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isMine
                                        ? Colors.black54
                                        : theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: InputDecoration(
                        hintText: 'chat.type_message'.tr(),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_invalidConversationId) return;
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    await _resolveCurrentUserIdIfNeeded();
    if ((_currentUserId ?? '').isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session invalide. Veuillez vous reconnecter.'),
        ),
      );
      return;
    }

    _messageCtrl.clear();

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Optimistic: add message to local list immediately
    final optimistic = MessageModel(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _currentUserId!,
      content: text,
      createdAt: DateTime.now(),
    );
    ref.read(chatProvider.notifier).addMessage(optimistic);
    _scrollToBottom();

    // Send via REST — replace temp on success, remove on failure
    try {
      await ref
          .read(chatProvider.notifier)
          .sendMessage(
            conversationId: widget.conversationId,
            content: text,
            tempId: tempId,
          );
    } catch (_) {
      ref.read(chatProvider.notifier).removeMessage(tempId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
