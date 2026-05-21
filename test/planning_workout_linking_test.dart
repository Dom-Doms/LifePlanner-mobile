import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/data/models/planning_logic.dart';
import 'package:lifeplanner_mobile/data/models/planning_models.dart';

void main() {
  test('recognizes invited workout event needing a template link', () {
    final event = _event(
      type: 'WORKOUT',
      owner: false,
      participant: true,
      needsWorkoutLink: true,
    );

    expect(canLinkWorkoutTemplate(event), isTrue);
  });

  test('does not show template link for owner workout event', () {
    final event = _event(
      type: 'WORKOUT',
      owner: true,
      participant: false,
      needsWorkoutLink: true,
    );

    expect(canLinkWorkoutTemplate(event), isFalse);
  });

  test('does not show template link for non workout event', () {
    final event = _event(
      type: 'PERSONAL',
      owner: false,
      participant: true,
      needsWorkoutLink: true,
    );

    expect(canLinkWorkoutTemplate(event), isFalse);
  });

  test('does not show template link for already linked workout invite', () {
    final event = _event(
      type: 'WORKOUT',
      owner: false,
      participant: true,
      needsWorkoutLink: false,
      linkedWorkoutSessionId: 42,
    );

    expect(canLinkWorkoutTemplate(event), isFalse);
  });

  test(
    'does not show template link for free text participant payload only',
    () {
      final event = _event(
        type: 'WORKOUT',
        owner: false,
        participant: false,
        needsWorkoutLink: true,
        participants: const [
          ParticipantDto(displayName: 'Guest', participantType: 'FREE_TEXT'),
        ],
      );

      expect(canLinkWorkoutTemplate(event), isFalse);
    },
  );

  test('builds workout link payload', () {
    expect(workoutLinkPayload(9), {'templateId': 9});
  });
}

CalendarEventResponse _event({
  required String type,
  required bool owner,
  required bool participant,
  required bool needsWorkoutLink,
  int? linkedWorkoutSessionId,
  List<ParticipantDto> participants = const [],
}) {
  return CalendarEventResponse(
    id: 1,
    title: 'Workout',
    eventDate: '2026-05-21',
    allDay: false,
    type: type,
    reminderEnabled: false,
    owner: owner,
    participant: participant,
    needsWorkoutLink: needsWorkoutLink,
    linkedWorkoutSessionId: linkedWorkoutSessionId,
    participants: participants,
  );
}
