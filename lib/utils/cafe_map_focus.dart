import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';

void showCafeOnMap(
  BuildContext context,
  WidgetRef ref,
  String cafeId,
) {
  ref.read(cafeProvider.notifier).selectCafeForMap(cafeId);
  context.go('/map?focusCafeId=${Uri.encodeComponent(cafeId)}');
}
