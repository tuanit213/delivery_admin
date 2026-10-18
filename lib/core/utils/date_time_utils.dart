// The API stores UTC; delivery times are displayed in Vietnam (UTC+7).
DateTime? vietnamTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final hasZone = RegExp(
    r'(Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);
  final utc = hasZone
      ? parsed.toUtc()
      : DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
        );
  return utc.add(const Duration(hours: 7));
}
