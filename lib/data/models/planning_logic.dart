import 'planning_models.dart';

bool canLinkWorkoutTemplate(CalendarEventResponse event) {
  return event.type == 'WORKOUT' &&
      event.participant == true &&
      event.owner != true &&
      event.needsWorkoutLink == true &&
      event.linkedWorkoutSessionId == null;
}

Map<String, dynamic> workoutLinkPayload(int templateId) => {
  'templateId': templateId,
};
