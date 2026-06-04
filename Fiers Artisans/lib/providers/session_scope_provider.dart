import 'package:flutter_riverpod/flutter_riverpod.dart';

final sessionEpochProvider = StateNotifierProvider<SessionEpochNotifier, int>((
  ref,
) {
  return SessionEpochNotifier();
});

class SessionEpochNotifier extends StateNotifier<int> {
  SessionEpochNotifier() : super(0);

  void bump() {
    state = state + 1;
  }
}
