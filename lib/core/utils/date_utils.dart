DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime value) =>
    '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)}';

String formatMonthKey(DateTime value) =>
    '${value.year}-${twoDigits(value.month)}';

String formatTimeOfDayParts(int hour, int minute) =>
    '${twoDigits(hour)}:${twoDigits(minute)}';

DateTime mondayOf(DateTime value) {
  final date = dateOnly(value);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}

DateTime firstVisibleMonthDay(DateTime month) {
  final first = DateTime(month.year, month.month);
  return first.subtract(Duration(days: first.weekday - DateTime.monday));
}

DateTime lastVisibleMonthDay(DateTime month) {
  final last = DateTime(month.year, month.month + 1, 0);
  return last.add(Duration(days: DateTime.sunday - last.weekday));
}

String weekdayLabel(DateTime date) {
  const labels = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  return labels[date.weekday - 1];
}

String monthLabel(DateTime date) {
  const labels = [
    'Gennaio',
    'Febbraio',
    'Marzo',
    'Aprile',
    'Maggio',
    'Giugno',
    'Luglio',
    'Agosto',
    'Settembre',
    'Ottobre',
    'Novembre',
    'Dicembre',
  ];
  return '${labels[date.month - 1]} ${date.year}';
}

String compactDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return 'Durata non stimata';
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  if (minutes == 0) return '$remaining sec';
  if (remaining == 0) return '$minutes min';
  return '$minutes min ${remaining}s';
}

int? parseOptionalInt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}
