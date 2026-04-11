class UserSession {
  const UserSession({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.accessToken,
  });

  final String uid;
  final String email;
  final String displayName;
  final String accessToken;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'accessToken': accessToken,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      accessToken: json['accessToken'] as String,
    );
  }
}
