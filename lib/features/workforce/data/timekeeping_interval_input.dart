import 'package:timezone/data/latest.dart' as database;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;

String timekeepingLocalInput(String timestamp, String timezone) {
  if (!_initialized) {
    database.initializeTimeZones();
    _initialized = true;
  }
  final hasOffset = RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(timestamp);
  final parsed = DateTime.parse(hasOffset ? timestamp : '${timestamp}Z');
  final value =
      hasOffset ? tz.TZDateTime.from(parsed, tz.getLocation(timezone)) : parsed;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
}

String? timekeepingWallClock(String value) {
  final match = RegExp(
    r'^(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 5; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(parts[2], parts[1], parts[0], parts[3], parts[4]);
  if (date.year != parts[2] ||
      date.month != parts[1] ||
      date.day != parts[0] ||
      date.hour != parts[3] ||
      date.minute != parts[4]) {
    return null;
  }
  return '${match.group(3)}-${match.group(2)}-${match.group(1)}T${match.group(4)}:${match.group(5)}:00';
}

class TimekeepingIntervalInput {
  TimekeepingIntervalInput({
    this.start = '',
    this.end = '',
    this.timezone = 'Europe/Moscow',
    List<TimekeepingBreakInput>? breaks,
    this.original,
  }) : breaks = breaks ?? [];
  String start;
  String end;
  String timezone;
  final List<TimekeepingBreakInput> breaks;
  Map<String, dynamic>? original;

  factory TimekeepingIntervalInput.fromJson(Map<String, dynamic> json) {
    final zone = json['timezone'] as String;
    return TimekeepingIntervalInput(
      start: timekeepingLocalInput(json['start_at'] as String, zone),
      end: timekeepingLocalInput(json['end_at'] as String, zone),
      timezone: zone,
      original: json,
      breaks:
          (json['break_intervals'] as List? ?? [])
              .map(
                (item) => TimekeepingBreakInput(
                  timekeepingLocalInput(item['start_at'] as String, zone),
                  timekeepingLocalInput(item['end_at'] as String, zone),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    if (original != null) return original!;
    final startAt = timekeepingWallClock(start);
    final endAt = timekeepingWallClock(end);
    if (startAt == null || endAt == null || timezone.trim().isEmpty) {
      throw const FormatException(
        'Укажите даты и время начала и конца работы.',
      );
    }
    if (endAt.compareTo(startAt) <= 0) {
      throw const FormatException('Конец работы должен быть позже начала.');
    }
    return {
      'start_at': startAt,
      'end_at': endAt,
      'timezone': timezone.trim(),
      'break_intervals':
          breaks.map((pause) {
            final from = timekeepingWallClock(pause.start);
            final to = timekeepingWallClock(pause.end);
            if (from == null ||
                to == null ||
                from.compareTo(startAt) < 0 ||
                to.compareTo(endAt) > 0 ||
                from.compareTo(to) >= 0) {
              throw const FormatException(
                'Укажите начало и конец перерыва внутри рабочего интервала.',
              );
            }
            return {'start_at': from, 'end_at': to};
          }).toList(),
    };
  }
}

class TimekeepingBreakInput {
  TimekeepingBreakInput(this.start, this.end);
  String start;
  String end;
}
