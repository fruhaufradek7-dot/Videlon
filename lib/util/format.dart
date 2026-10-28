
/// Number, duration and date formatting in Czech.
library;

/// "1,2 mil.", "34 tis.", "999".
String compactCount(int n) {
  String fmt(double v, String unit) {
    if (v >= 10) return '${v.floor()}$unit';
    final one = (v * 10).floor() / 10;
    return '${one == one.roundToDouble() ? one.toInt() : one}$unit';
  }

  if (n >= 1000000000) return fmt(n / 1000000000, ' mld.');
  if (n >= 1000000) return fmt(n / 1000000, ' mil.');
  if (n >= 1000) return fmt(n / 1000, ' tis.');
  return '$n';
}

/// Czech view count.
String viewsLabel(int n) => n < 0
    ? ''
    : n == 0
    ? 'Žádná zhlédnutí'
    : n == 1
    ? '1 zhlédnutí'
    : '${compactCount(n)} zhlédnutí';

/// Czech relative time, e.g. "před 3 hodinami".
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);

  if (d.inDays >= 365) {
    final n = d.inDays ~/ 365;
    return 'před $n ${n == 1 ? 'rokem' : n < 5 ? 'lety' : 'lety'}';
  }
  if (d.inDays >= 30) {
    final n = d.inDays ~/ 30;
    return 'před $n ${n == 1 ? 'měsícem' : 'měsíci'}';
  }
  if (d.inDays >= 7) {
    final n = d.inDays ~/ 7;
    return 'před $n ${n == 1 ? 'týdnem' : 'týdny'}';
  }
  if (d.inDays >= 1) {
    final n = d.inDays;
    return 'před $n ${n == 1 ? 'dnem' : 'dny'}';
  }
  if (d.inHours >= 1) {
    final n = d.inHours;
    return 'před $n ${n == 1 ? 'hodinou' : n < 5 ? 'hodinami' : 'hodinami'}';
  }
  if (d.inMinutes >= 1) {
    final n = d.inMinutes;
    return 'před $n ${n == 1 ? 'minutou' : 'minutami'}';
  }
  return 'Právě teď';
}

/// NewPipe upload date as a Czech relative date.
String? relativeDate(String? text) {
  if (text == null || text.isEmpty) return null;
  final t = DateTime.tryParse(text);
  return t == null ? text : timeAgo(t.toLocal());
}

/// "3:07", "1:02:03".
String formatDuration(Duration d) {
  final neg = d.isNegative;
  d = d.abs();
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${neg ? '-' : ''}${h > 0 ? '$h:$m:$s' : '$m:$s'}';
}

