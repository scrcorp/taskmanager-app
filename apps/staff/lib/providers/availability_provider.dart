/// 내 근무 가용성(Work Availability) Provider
///
/// 조회 전용 화면이라 FutureProvider로 단순 구성. 화면 진입 시 서버에서 로드,
/// pull-to-refresh 시 ref.invalidate로 재조회.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/availability.dart';
import '../services/availability_service.dart';

/// 내 주간 가용성 Provider (조회 전용)
final myAvailabilityProvider =
    FutureProvider.autoDispose<MyAvailability>((ref) async {
  final service = ref.read(availabilityServiceProvider);
  return service.getMyAvailability();
});
