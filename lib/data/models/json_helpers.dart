Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) return value.map(asMap).toList();
  return <Map<String, dynamic>>[];
}

String readString(
  Map<String, dynamic> json,
  String key, [
  String fallback = '',
]) {
  final value = json[key];
  return value == null ? fallback : value.toString();
}

String? readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int readInt(Map<String, dynamic> json, String key, [int fallback = 0]) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? readNullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool readBool(Map<String, dynamic> json, String key, [bool fallback = false]) {
  final value = json[key];
  if (value is bool) return value;
  if (value == null) return fallback;
  return value.toString().toLowerCase() == 'true';
}

bool? readNullableBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  return value.toString().toLowerCase() == 'true';
}

Map<String, dynamic> withoutNulls(Map<String, dynamic> json) {
  final cleaned = <String, dynamic>{};
  json.forEach((key, value) {
    if (value == null) return;
    if (value is List) {
      cleaned[key] = value
          .where((entry) => entry != null)
          .map(
            (entry) =>
                entry is Map<String, dynamic> ? withoutNulls(entry) : entry,
          )
          .toList();
      return;
    }
    if (value is Map<String, dynamic>) {
      cleaned[key] = withoutNulls(value);
      return;
    }
    cleaned[key] = value;
  });
  return cleaned;
}
