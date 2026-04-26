import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/favorites_provider.dart';
import '../common/artisan_card.dart';
import '../common/category_chip.dart';
import '../common/recent_conversation_tile.dart';
import '../common/skeleton_loader.dart';

class ClientDashboard extends ConsumerStatefulWidget {
  const ClientDashboard({super.key});

  @override
  ConsumerState<ClientDashboard> createState() => _ClientDashboardState();
}

class _ClientDashboardState extends ConsumerState<ClientDashboard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  List<String> _recentlyViewed = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _loadRecentlyViewed();
    Future.microtask(() async {
      await Future.wait([
        ref.read(categoriesProvider.notifier).load(),
        ref.read(chatProvider.notifier).loadConversations(),
        ref.read(favoritesProvider.notifier).loadFavorites(),
      ]);
    });
  }

  Future<void> _loadRecentlyViewed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentlyViewed = prefs.getStringList('recently_viewed') ?? [];
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final catState = ref.watch(categoriesProvider);
    final chatState = ref.watch(chatProvider);
    final favoritesState = ref.watch(favoritesProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            await Future.wait([
              ref.read(categoriesProvider.notifier).load(),
              ref.read(chatProvider.notifier).loadConversations(),
              ref.read(favoritesProvider.notifier).loadFavorites(),
              _loadRecentlyViewed(),
            ]);
          },
          child: FadeTransition(
            opacity: _fadeIn,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ── Greeting header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'home.greeting'.tr(
                            namedArgs: {'name': user?.firstName ?? ''},
                          ),
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'app.tagline'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Search bar ──
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () => context.push('/client/search'),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'home.search_hint'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Urgent mode CTA ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: GestureDetector(
                      onTap: () => context.push(
                        '/client/search',
                        extra: {'nearby': true},
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.flash_on_rounded,
                              color: Colors.black,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'dashboard.client.urgent_mode'.tr(),
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'dashboard.client.urgent_subtitle'.tr(),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.black54,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Categories section ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'home.categories'.tr(),
                          style: theme.textTheme.headlineMedium,
                        ),
                        TextButton(
                          onPressed: () => context.push('/client/search'),
                          child: Text('home.see_all'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Category chips ──
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: catState.isLoading
                        ? ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: 5,
                            itemBuilder: (_, index) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SkeletonLoader(
                                width: 100,
                                height: 40,
                                borderRadius: 20,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            physics: const BouncingScrollPhysics(),
                            itemCount: catState.categories.length,
                            itemBuilder: (context, index) {
                              final cat = catState.categories[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: CategoryChip(
                                  label: cat.name,
                                  icon: cat.icon,
                                  onTap: () => context.push(
                                    '/client/search',
                                    extra: {'categoryId': cat.id},
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Quick actions ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.location_on_outlined,
                            label: 'home.nearby'.tr(),
                            onTap: () => context.push(
                              '/client/search',
                              extra: {'nearby': true},
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.star_outline_rounded,
                            label: 'home.top_rated'.tr(),
                            onTap: () => context.push(
                              '/client/search',
                              extra: {'topRated': true},
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Favorites ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'dashboard.client.favorites'.tr(),
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child:
                      favoritesState.isLoading &&
                          favoritesState.favorites.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            children: List.generate(
                              2,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SkeletonLoader.artisanCard(),
                              ),
                            ),
                          ),
                        )
                      : favoritesState.favorites.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 36,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'dashboard.client.favorites_empty'.tr(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            children: favoritesState.favorites
                                .take(3)
                                .map(
                                  (artisan) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ArtisanCard(
                                      artisan: artisan,
                                      onTap: () => context.push(
                                        '/client/artisan/${artisan.userId}',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Recently viewed ──
                if (_recentlyViewed.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'dashboard.client.recently_viewed'.tr(),
                        style: theme.textTheme.headlineMedium,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          children: _recentlyViewed
                              .take(3)
                              .map(
                                (name) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.history,
                                        size: 18,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        name,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                // ── Recent conversations (with artisans) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale = MediaQuery.textScalerOf(
                          context,
                        ).scale(1);
                        final isCompact =
                            constraints.maxWidth < 380 || textScale > 1.08;

                        final seeAllButton = TextButton(
                          onPressed: () => context.push('/chat'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            'home.see_all'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'dashboard.client.inbox'.tr(),
                                style: theme.textTheme.headlineMedium,
                              ),
                              if (chatState.conversations.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: seeAllButton,
                                ),
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'dashboard.client.inbox'.tr(),
                                style: theme.textTheme.headlineMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chatState.conversations.isNotEmpty)
                              seeAllButton,
                          ],
                        );
                      },
                    ),
                  ),
                ),

                if (chatState.isLoading && chatState.conversations.isEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: SkeletonLoader(
                          width: double.infinity,
                          height: 72,
                          borderRadius: 12,
                        ),
                      ),
                      childCount: 3,
                    ),
                  )
                else if (chatState.conversations.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'chat.empty'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index >= 3) return null;
                      final convo = chatState.conversations[index];

                      return RecentConversationTile(
                        name: convo.participantName,
                        lastMessage: convo.lastMessage ?? '',
                        unread: convo.unreadCount,
                        lastMessageAt: convo.lastMessageAt,
                        avatarUrl: convo.participantAvatarUrl,
                        showUnavailableBadge:
                            convo.participantRole == 'ARTISAN' &&
                            convo.participantIsAvailable == false,
                        onTap: () {
                          final queryParams = <String, String>{
                            'name': convo.participantName,
                          };
                          final role = convo.participantRole?.trim();
                          if (role != null && role.isNotEmpty) {
                            queryParams['participantRole'] = role;
                          }
                          if (convo.participantIsAvailable != null) {
                            queryParams['participantIsAvailable'] =
                                '${convo.participantIsAvailable}';
                          }
                          final avatar = convo.participantAvatarUrl?.trim();
                          if (avatar != null && avatar.isNotEmpty) {
                            queryParams['avatar'] = avatar;
                          }
                          final query = Uri(queryParameters: queryParams).query;
                          context.push('/chat/${convo.id}?$query');
                        },
                      );
                    }, childCount: chatState.conversations.length.clamp(0, 3)),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
