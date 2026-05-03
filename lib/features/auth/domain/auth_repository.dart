import 'user_session.dart';

abstract class AuthRepository {
  Future<UserSession> signIn({required String email, required String password});

  Future<void> signUp({
    required String email,
    required String password,
    required String nombre,
    String? nombreFinca,
  });

  Future<UserSession?> getCurrentSession();
  Future<bool> validateSession(UserSession session);
  Future<void> forgotPassword({required String email});
  Future<void> signOut();
}
