import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'mobile_destination.dart';

final mobileNavigationProvider =
    StateNotifierProvider<MobileNavigationNotifier, MobileNavTab>((ref) {
      return MobileNavigationNotifier();
    });

class MobileNavigationNotifier extends StateNotifier<MobileNavTab> {
  MobileNavigationNotifier() : super(MobileNavTab.overview);

  void setTab(MobileNavTab tab) {
    state = tab;
  }

  void setTabByIndex(int index) {
    if (index < 0 || index >= MobileNavTab.values.length) {
      return;
    }

    state = MobileNavTab.values[index];
  }
}
