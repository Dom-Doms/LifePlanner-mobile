import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/features/planning/event_form_logic.dart';

void main() {
  test('event time helpers format native picker values', () {
    final start = parseEventTime('09:30');
    expect(start, isNotNull);
    expect(formatEventTime(start!), '09:30');
    expect(
      addEventDuration(start, const Duration(minutes: 45)),
      const TimeOfDay(hour: 10, minute: 15),
    );
  });

  test('event payload keeps Vue/backend recurrence contract', () {
    final payload = buildEventFormPayload(
      title: 'Lezione',
      eventDate: '2026-05-21',
      allDay: false,
      type: 'PERSONAL',
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
      recurrenceType: 'WEEKLY',
      recurrenceUntil: '2026-06-21',
      reminderEnabled: true,
      reminderMinutes: 30,
    );

    expect(payload['startTime'], '09:00');
    expect(payload['endTime'], '10:00');
    expect(payload['recurrenceType'], 'WEEKLY');
    expect(payload['recurrenceUntil'], '2026-06-21');
    expect(payload['reminderMinutesBefore'], 30);
  });

  test('event payload clears recurrenceUntil when recurrence is none', () {
    final payload = buildEventFormPayload(
      title: 'Evento',
      eventDate: '2026-05-21',
      allDay: false,
      type: 'PERSONAL',
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 0),
      recurrenceType: 'NONE',
      recurrenceUntil: '2026-06-21',
      reminderEnabled: false,
      reminderMinutes: 30,
    );

    expect(payload['recurrenceType'], 'NONE');
    expect(payload.containsKey('recurrenceUntil'), isFalse);
    expect(payload['reminderEnabled'], isFalse);
    expect(payload.containsKey('reminderMinutesBefore'), isFalse);
  });

  test('event time validation rejects end before start', () {
    final error = validateEventTimes(
      allDay: false,
      start: const TimeOfDay(hour: 11, minute: 0),
      end: const TimeOfDay(hour: 10, minute: 59),
    );

    expect(error, contains('fine'));
  });
}
