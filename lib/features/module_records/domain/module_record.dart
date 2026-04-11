class ModuleRecord {
  const ModuleRecord({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.rawData,
  });

  final String id;
  final String title;
  final String subtitle;
  final String footnote;
  final Map<String, dynamic> rawData;
}
