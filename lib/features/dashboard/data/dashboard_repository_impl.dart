import '../../../core/network/api_client.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<DashboardSummary> getSummary({required String accessToken}) async {
    final response = await apiClient.getJson(
      '/api/v1/dashboard/summary',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Respuesta invalida en dashboard summary',
        statusCode: 500,
      );
    }

    return DashboardSummary.fromJson(data);
  }
}
