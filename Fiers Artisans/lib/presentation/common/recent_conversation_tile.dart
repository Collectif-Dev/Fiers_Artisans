import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import 'availability_badge.dart';

class RecentConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final int unread;
  final DateTime? lastMessageAt;
  final String? avatarUrl;
  final bool showUnavailableBadge;
  final VoidCallback onTap;

  const RecentConversationTile({
    super.key,
    required this.name,
    required this.lastMessage,
    required this.unread,
    required this.onTap,
    this.lastMessageAt,
    this.avatarUrl,
    this.showUnavailableBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              _ConversationAvatar(name: name, avatarUrl: avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showUnavailableBadge) ...[
                      const SizedBox(height: 4),
                      const UnavailableBadge(compact: true),
                    ],
                    if (lastMessage.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        Formatters.truncate(lastMessage, 48),
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastMessageAt != null)
                    Text(
                      Formatters.relativeDate(lastMessageAt!),
                      style: theme.textTheme.labelSmall,
                    ),
                  if (unread > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppTheme.gold,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ConversationAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeName = name.trim();
    final initial = safeName.isNotEmpty ? safeName[0].toUpperCase() : '?';
    final avatar = avatarUrl?.trim();

    return CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      backgroundImage: (avatar != null && avatar.isNotEmpty)
          ? NetworkImage(avatar)
          : null,
      child: (avatar == null || avatar.isEmpty)
          ? Text(
              initial,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
