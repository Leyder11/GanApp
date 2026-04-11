import '../../../core/network/api_client.dart';
import '../domain/farm.dart';
import '../domain/user_profile.dart';
import 'user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl({required this.apiClient});

  final ApiClient apiClient;

  @override
  Future<UserProfile> getMyProfile({required String accessToken}) async {
    final response = await apiClient.getJson(
      '/api/v1/users/me',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Perfil de usuario invalido',
        statusCode: 500,
      );
    }

    return _map(data);
  }

  @override
  Future<List<Farm>> getMyFarms({required String accessToken}) async {
    final response = await apiClient.getJson(
      '/api/v1/farms',
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = response['data'];
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (farm) => Farm(
            id: farm['id']?.toString() ?? '',
            nombre: farm['nombre']?.toString() ?? 'Finca',
          ),
        )
        .toList();
  }

  @override
  Future<Farm> createFarm({
    required String accessToken,
    required String farmName,
  }) async {
    final response = await apiClient.postJson(
      '/api/v1/farms',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'nombre': farmName},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(message: 'No se pudo crear la finca', statusCode: 500);
    }

    return Farm(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? farmName,
    );
  }

  @override
  Future<UserProfile> selectFarm({
    required String accessToken,
    required String farmId,
  }) async {
    final response = await apiClient.postJson(
      '/api/v1/farms/select',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'farmId': farmId},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'No se pudo seleccionar la finca',
        statusCode: 500,
      );
    }

    return _map(data);
  }

  @override
  Future<UserProfile> updateFarmName({
    required String accessToken,
    required String farmName,
  }) async {
    final response = await apiClient.patchJson(
      '/api/v1/users/me',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {'nombreFinca': farmName},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'No se pudo actualizar la finca',
        statusCode: 500,
      );
    }

    return _map(data);
  }

  UserProfile _map(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? 'Ganadero',
      nombreFinca: data['nombreFinca']?.toString() ?? 'Mi Finca',
      currentFarmId: data['currentFarmId']?.toString() ?? '',
    );
  }
}
