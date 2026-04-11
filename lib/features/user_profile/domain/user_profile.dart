class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nombre,
    required this.nombreFinca,
    required this.currentFarmId,
  });

  final String uid;
  final String nombre;
  final String nombreFinca;
  final String currentFarmId;
}
