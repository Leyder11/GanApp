import '../../../core/network/api_client.dart';
import '../../../core/storage/session_local_store.dart';
import '../domain/auth_repository.dart';
import '../domain/user_session.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required this.apiClient, required this.localStore});

  final ApiClient apiClient;
  final SessionLocalStore localStore;

  @override
  Future<UserSession?> getCurrentSession() {
    return localStore.read();
  }

  @override
  Future<bool> validateSession(UserSession session) async {
    try {
      await apiClient.getJson(
        '/api/v1/users/me',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );
      return true;
    } on ApiException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> forgotPassword({required String email}) {
    return apiClient.postJson(
      '/api/v1/auth/forgot-password',
      body: {'email': email},
    );
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    String? nombreFinca,
  }) {
    final normalizedFarmName = nombreFinca?.trim();

    return apiClient.postJson(
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        'nombre': nombre,
        'tipoUsuarioId': 'ganadero',
        if (normalizedFarmName != null && normalizedFarmName.isNotEmpty)
          'nombreFinca': normalizedFarmName,
      },
    );
  }

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.postJson(
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
    );

    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Respuesta invalida del servidor',
        statusCode: 500,
      );
    }

    final session = UserSession(
      uid: data['uid']?.toString() ?? '',
      email: data['email']?.toString() ?? email,
      displayName: data['nombre']?.toString() ?? 'Ganadero',
      accessToken: data['token']?.toString() ?? '',
    );

    await localStore.save(session);
    return session;
  }

  @override
  Future<void> signOut() {
    return localStore.clear();
  }
}
