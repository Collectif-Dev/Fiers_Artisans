import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers/profile_provider.dart';
import '../../services/chat_realtime_service.dart';
import 'profile_ui.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen>
    with WidgetsBindingObserver {
  StreamSubscription<ChatRealtimeEvent>? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeSub = ChatRealtimeService().domainEvents.listen(_onRealtimeEvent);
    Future.microtask(_revalidateCachedProfile);
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(clientProfileProvider);
    }
  }

  void _revalidateCachedProfile() {
    final current = ref.read(clientProfileProvider);
    if (current.hasValue || current.hasError) {
      ref.invalidate(clientProfileProvider);
    }
  }

  void _onRealtimeEvent(ChatRealtimeEvent event) {
    if (event.event == 'userProfileUpdated' ||
        event.event == 'verificationStatusUpdated') {
      ref.invalidate(clientProfileProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(clientProfileProvider);

    return Scaffold(
      body: asyncProfile.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ProfileErrorState(
          onRetry: () => ref.refresh(clientProfileProvider),
        ),
        data: (profile) {
          final createdAt = profile.createdAt;
          final locationUpdatedAt = profile.locationUpdatedAt;
          final initials = _initials(profile.firstName, profile.lastName);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                toolbarHeight: 0,
                expandedHeight: 210,
                pinned: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: ProfileHeader(
                    title: profile.fullName,
                    subtitle: 'profile.client.subtitle'.tr(),
                    initials: initials,
                    imageUrl: profile.profilePhotoUrl,
                    badges: [
                      ProfileStatusPill(
                        icon: profile.isPhoneVerified
                            ? Icons.verified_user_rounded
                            : Icons.shield_outlined,
                        label: profile.isPhoneVerified
                            ? 'profile.client.phone_verified'.tr()
                            : 'profile.client.phone_pending'.tr(),
                        background: profile.isPhoneVerified
                            ? AppTheme.success.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.18),
                        foreground: Colors.white,
                      ),
                      ProfileStatusPill(
                        icon: profile.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        label: profile.isActive
                            ? 'profile.client.account_active'.tr()
                            : 'profile.client.account_inactive'.tr(),
                        background: profile.isActive
                            ? Colors.white.withValues(alpha: 0.2)
                            : AppTheme.error.withValues(alpha: 0.2),
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              ProfileBodyPadding(
                children: [
                  ProfileSectionCard(
                    title: 'profile.client.contact_title'.tr(),
                    subtitle: 'profile.client.contact_subtitle'.tr(),
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: Icons.phone_rounded,
                          label: 'profile.fields.phone'.tr(),
                          value: Formatters.phone(profile.phone),
                        ),
                        ProfileInfoRow(
                          icon: Icons.email_outlined,
                          label: 'profile.fields.email'.tr(),
                          value: (profile.email ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : profile.email!,
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.client.personal_title'.tr(),
                    subtitle: 'profile.client.personal_subtitle'.tr(),
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'profile.fields.first_name'.tr(),
                          value: profile.firstName,
                        ),
                        ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          label: 'profile.fields.last_name'.tr(),
                          value: profile.lastName,
                        ),
                        ProfileInfoRow(
                          icon: Icons.location_city_outlined,
                          label: 'profile.fields.city'.tr(),
                          value: (profile.city ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : profile.city!,
                        ),
                        ProfileInfoRow(
                          icon: Icons.place_outlined,
                          label: 'profile.fields.commune'.tr(),
                          value: (profile.commune ?? '').trim().isEmpty
                              ? 'profile.common.not_provided'.tr()
                              : profile.commune!,
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.client.location_title'.tr(),
                    subtitle: 'profile.client.location_subtitle'.tr(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.hasCoordinates)
                          Wrap(
                            spacing: 18,
                            runSpacing: 12,
                            children: [
                              ProfileLabelValue(
                                label: 'profile.fields.latitude'.tr(),
                                value: profile.latitude!.toStringAsFixed(5),
                              ),
                              ProfileLabelValue(
                                label: 'profile.fields.longitude'.tr(),
                                value: profile.longitude!.toStringAsFixed(5),
                              ),
                            ],
                          )
                        else
                          ProfileEmptyValue(
                            label: 'profile.common.no_coordinates'.tr(),
                          ),
                        const SizedBox(height: 14),
                        ProfileSubtleHint(
                          icon: Icons.gps_fixed_rounded,
                          text: locationUpdatedAt != null
                              ? 'location.last_update'.tr(
                                  namedArgs: {
                                    'date': DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(locationUpdatedAt),
                                  },
                                )
                              : 'location.last_update_unknown'.tr(),
                        ),
                      ],
                    ),
                  ),
                  ProfileSectionCard(
                    title: 'profile.client.account_title'.tr(),
                    subtitle: 'profile.client.account_subtitle'.tr(),
                    child: Column(
                      children: [
                        ProfileInfoRow(
                          icon: profile.isPhoneVerified
                              ? Icons.verified_user_rounded
                              : Icons.shield_outlined,
                          label: 'profile.client.otp_title'.tr(),
                          value: profile.isPhoneVerified
                              ? 'profile.client.phone_verified'.tr()
                              : 'profile.client.phone_pending'.tr(),
                        ),
                        ProfileInfoRow(
                          icon: Icons.schedule_rounded,
                          label: 'profile.fields.member_since'.tr(),
                          value: createdAt != null
                              ? DateFormat('dd/MM/yyyy').format(createdAt)
                              : 'profile.common.not_provided'.tr(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  String _initials(String firstName, String lastName) {
    final first = firstName.trim().isEmpty ? '' : firstName.trim()[0];
    final last = lastName.trim().isEmpty ? '' : lastName.trim()[0];
    final value = '$first$last'.toUpperCase();
    return value.isEmpty ? 'FA' : value;
  }
}
