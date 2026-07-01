import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/artisan_model.dart';
import '../data/models/client_profile_model.dart';
import '../data/repositories/artisan_repository.dart';
import '../data/repositories/profile_repository.dart';

const _profileCacheTtl = Duration(minutes: 2);

final clientProfileProvider = FutureProvider.autoDispose<ClientProfileModel>((
  ref,
) async {
  final link = ref.keepAlive();
  final timer = Timer(_profileCacheTtl, link.close);
  ref.onDispose(timer.cancel);

  return ProfileRepository().getMyClientProfile();
});

final artisanOwnProfileProvider = FutureProvider.autoDispose<ArtisanModel>((
  ref,
) async {
  final link = ref.keepAlive();
  final timer = Timer(_profileCacheTtl, link.close);
  ref.onDispose(timer.cancel);

  return ArtisanRepository().getMyArtisanProfile();
});
