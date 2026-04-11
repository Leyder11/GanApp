import '../domain/farm.dart';
import '../domain/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile> getMyProfile({required String accessToken});

  Future<List<Farm>> getMyFarms({required String accessToken});

  Future<Farm> createFarm({
    required String accessToken,
    required String farmName,
  });

  Future<UserProfile> selectFarm({
    required String accessToken,
    required String farmId,
  });

  Future<UserProfile> updateFarmName({
    required String accessToken,
    required String farmName,
  });
}
