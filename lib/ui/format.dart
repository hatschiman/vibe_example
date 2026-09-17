const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.',
];

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final time = '${_two(d.hour)}:${_two(d.minute)}';
  final daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) return 'Heute, $time';
  if (daysAgo == 1) return 'Gestern, $time';
  final date = '${_weekdays[d.weekday - 1]}, ${d.day}. ${_months[d.month - 1]}';
  return d.year == now.year ? '$date, $time' : '$date ${d.year}, $time';
}

String formatDuration(Duration d) => '${d.inMinutes}:${_two(d.inSeconds % 60)}';
