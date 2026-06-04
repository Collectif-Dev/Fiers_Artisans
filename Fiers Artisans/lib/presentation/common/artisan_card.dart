import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../data/models/artisan_model.dart';
import '../../core/utils/formatters.dart';
import 'rating_stars.dart';
import 'badge_verified.dart';
import 'availability_badge.dart';

class ArtisanCard extends StatefulWidget {
  final ArtisanModel artisan;
  final VoidCallback? onTap;

  const ArtisanCard({super.key, required this.artisan, this.onTap});

  @override
  State<ArtisanCard> createState() => _ArtisanCardState();
}

class _ArtisanCardState extends State<ArtisanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artisan = widget.artisan;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: AppConstants.animFast,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: _isPressed
                    ? AppTheme.gold.withValues(alpha: 0.15)
                    : theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: _isPressed ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(artisan),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              artisan.fullName,
                              style: theme.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (artisan.isVerified)
                            const BadgeVerified(type: BadgeType.verified),
                          if (artisan.isCertified) ...[
                            const SizedBox(width: 4),
                            const BadgeVerified(type: BadgeType.certified),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artisan.displayTrade,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (artisan.displayCategory != null)
                        Text(
                          artisan.displayCategory!,
                          style: theme.textTheme.labelSmall,
                        ),
                      if (!artisan.isAvailable) ...[
                        const SizedBox(height: 6),
                        const UnavailableBadge(compact: true),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          RatingStars(rating: artisan.averageRating, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            '(${artisan.totalReviews})',
                            style: theme.textTheme.labelSmall,
                          ),
                          const Spacer(),
                          if (artisan.distance != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  Formatters.distance(artisan.distance!),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ArtisanModel artisan) {
    final size = 56.0;
    if (artisan.profilePhotoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: artisan.profilePhotoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _initialsAvatar(artisan, size),
          errorWidget: (_, _, _) => _initialsAvatar(artisan, size),
        ),
      );
    }
    return _initialsAvatar(artisan, size);
  }

  Widget _initialsAvatar(ArtisanModel artisan, double size) {
    final initials =
        '${artisan.firstName.isNotEmpty ? artisan.firstName[0] : ''}${artisan.lastName.isNotEmpty ? artisan.lastName[0] : ''}'
            .toUpperCase();
    // Generate a consistent color from name
    final colorIndex =
        (artisan.firstName.hashCode + artisan.lastName.hashCode).abs() % 6;
    final colors = [
      AppTheme.gold,
      AppTheme.goldDark,
      AppTheme.success,
      const Color(0xFF3498DB),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors[colorIndex].withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: colors[colorIndex],
            fontWeight: FontWeight.w600,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}
