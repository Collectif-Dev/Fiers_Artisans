import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/notification_repository.dart';
import '../common/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repo = NotificationRepository();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await _repo.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications =
            List<Map<String, dynamic>>.from(result['data'] as List);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _markAsRead(int index) async {
    final notif = _notifications[index];
    if (notif['isRead'] == true) return;
    final id = (notif['_id'] ?? notif['id']).toString();
    try {
      await _repo.markAsRead(id);
      if (!mounted) return;
      setState(() {
        _notifications[index] = {...notif, 'isRead': true};
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => {...n, 'isRead': true})
            .toList();
      });
    } catch (_) {}
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'NEW_MESSAGE':
        return Icons.chat_bubble_outline;
      case 'SUBSCRIPTION_EXPIRY':
        return Icons.credit_card;
      case 'NEARBY_SEARCH':
        return Icons.location_on_outlined;
      case 'REVIEW_RECEIVED':
        return Icons.star_outline;
      case 'DOCUMENT_APPROVED':
        return Icons.check_circle_outline;
      case 'DOCUMENT_REJECTED':
        return Icons.cancel_outlined;
      case 'PAYMENT_SUCCESS':
        return Icons.payment;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String? type, ThemeData theme) {
    switch (type) {
      case 'NEW_MESSAGE':
        return Colors.blue;
      case 'SUBSCRIPTION_EXPIRY':
        return Colors.orange;
      case 'NEARBY_SEARCH':
        return Colors.green;
      case 'REVIEW_RECEIVED':
        return Colors.amber;
      case 'DOCUMENT_APPROVED':
        return Colors.teal;
      case 'DOCUMENT_REJECTED':
        return Colors.red;
      case 'PAYMENT_SUCCESS':
        return Colors.green;
      default:
        return theme.colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = _notifications.any((n) => n['isRead'] != true);

    return Scaffold(
      appBar: AppBar(
        title: Text('notifications.title'.tr()),
        actions: [
          if (!_isLoading && _notifications.isNotEmpty && hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'notifications.mark_all_read'.tr(),
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) return _buildShimmer(theme);

    if (_hasError) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'notifications.error'.tr(),
        actionLabel: 'notifications.retry'.tr(),
        onAction: _load,
      );
    }

    if (_notifications.isEmpty) {
      return EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'notifications.empty'.tr(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (context, i) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          final isRead = notif['isRead'] == true;
          final type = notif['type']?.toString();
          final title = notif['title']?.toString() ?? '';
          final body = notif['body']?.toString() ?? '';
          final createdAt = notif['createdAt'] != null
              ? DateTime.tryParse(notif['createdAt'].toString())
              : null;
          final iconColor = _colorForType(type, theme);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: iconColor.withValues(alpha: 0.15),
              child: Icon(_iconForType(type), color: iconColor, size: 22),
            ),
            title: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    Formatters.relativeDate(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ],
            ),
            trailing: isRead
                ? null
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
            onTap: () => _markAsRead(index),
          );
        },
      ),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surface,
      highlightColor: theme.colorScheme.surface.withValues(alpha: 0.5),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 8,
        itemBuilder: (context, i) => ListTile(
          leading: const CircleAvatar(),
          title: Container(
            height: 14,
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Container(
            height: 10,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
