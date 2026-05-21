import 'package:flutter/material.dart';

import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/planning_models.dart';

const eventDurationQuickChoices = <Duration>[
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(minutes: 45),
  Duration(hours: 1),
  Duration(minutes: 90),
  Duration(hours: 2),
];

TimeOfDay? parseEventTime(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String formatEventTime(TimeOfDay time) =>
    dates.formatTimeOfDayParts(time.hour, time.minute);

int eventMinutesOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

TimeOfDay addEventDuration(TimeOfDay start, Duration duration) {
  final totalMinutes = eventMinutesOfDay(start) + duration.inMinutes;
  final clamped = totalMinutes.clamp(0, 23 * 60 + 59).toInt();
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

String formatEventDurationLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  if (minutes == 0) return '$hours h';
  return '$hours h $minutes';
}

String? validateEventTimes({
  required bool allDay,
  required TimeOfDay? start,
  required TimeOfDay? end,
}) {
  if (allDay) return null;
  if (start == null || end == null) {
    return 'Inserisci ora di inizio e ora di fine.';
  }
  if (eventMinutesOfDay(end) <= eventMinutesOfDay(start)) {
    return "L'orario di fine deve essere successivo all'orario di inizio.";
  }
  return null;
}

Map<String, dynamic> buildEventFormPayload({
  required String title,
  required String eventDate,
  required bool allDay,
  required String type,
  required TimeOfDay? start,
  required TimeOfDay? end,
  required String recurrenceType,
  required bool reminderEnabled,
  required int reminderMinutes,
  String? description,
  String? location,
  int? workoutTemplateId,
  String? recurrenceUntil,
  List<ParticipantDto> participants = const [],
}) {
  return calendarEventRequest(
    title: title,
    description: description,
    eventDate: eventDate,
    startTime: start == null ? null : formatEventTime(start),
    endTime: end == null ? null : formatEventTime(end),
    allDay: allDay,
    type: type,
    location: location,
    workoutTemplateId: type == 'WORKOUT' ? workoutTemplateId : null,
    recurrenceType: recurrenceType,
    recurrenceUntil: recurrenceType == 'NONE' ? null : recurrenceUntil,
    reminderEnabled: reminderEnabled,
    reminderMinutesBefore: reminderMinutes,
    participants: participants,
  );
}
