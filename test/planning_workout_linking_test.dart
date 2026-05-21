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

  test('shows change template for already linked workout invite', () {
    final event = _event(
      type: 'WORKOUT',
      owner: false,
      participant: true,
      needsWorkoutLink: false,
      linkedWorkoutSessionId: 42,
      workoutTemplateId: 9,
    );

    expect(canChangeWorkoutTemplate(event), isTrue);
    expect(canLinkOrChangeWorkoutTemplate(event), isTrue);
    expect(workoutLinkActionLabel(event), 'Cambia scheda');
  });

  test('uses participant linked session before owner workout session', () {
    final event = _event(
      type: 'WORKOUT',
      owner: false,
      participant: true,
      needsWorkoutLink: false,
      linkedWorkoutSessionId: 42,
      ownerWorkoutSessionId: 7,
      workoutSessionId: 42,
      workoutTemplateId: 9,
    );

    expect(effectiveWorkoutSessionId(event), 42);
    expect(effectiveWorkoutTemplateId(event, 9), 9);
  });

  test('uses owner workout session for owner event', () {
    final event = _event(
      type: 'WORKOUT',
      owner: true,
      participant: false,
      needsWorkoutLink: false,
      ownerWorkoutSessionId: 7,
      workoutSessionId: 7,
      workoutTemplateId: 3,
    );

    expect(effectiveWorkoutSessionId(event), 7);
    expect(effectiveWorkoutTemplateId(event, 3), 3);
    expect(canChangeWorkoutTemplate(event), isFalse);
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
  int? ownerWorkoutSessionId,
  int? workoutSessionId,
  int? workoutTemplateId,
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
    ownerWorkoutSessionId: ownerWorkoutSessionId,
    workoutSessionId: workoutSessionId,
    workoutTemplateId: workoutTemplateId,
    participants: participants,
  );
}
