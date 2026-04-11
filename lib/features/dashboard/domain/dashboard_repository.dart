import 'dashboard_summary.dart';

abstract class DashboardRepository {
  Future<DashboardSummary> getSummary({required String accessToken});
}
