import 'planning_models.dart';

bool canLinkWorkoutTemplate(CalendarEventResponse event) {
  return event.type == 'WORKOUT' &&
      event.participant == true &&
      event.owner != true &&
      event.needsWorkoutLink == true &&
      event.linkedWorkoutSessionId == null;
}

bool canChangeWorkoutTemplate(CalendarEventResponse event) {
  return event.type == 'WORKOUT' &&
      event.participant == true &&
      event.owner != true &&
      event.linkedWorkoutSessionId != null;
}

bool canLinkOrChangeWorkoutTemplate(CalendarEventResponse event) {
  return canLinkWorkoutTemplate(event) || canChangeWorkoutTemplate(event);
}

String workoutLinkActionLabel(CalendarEventResponse event) {
  return canChangeWorkoutTemplate(event) ? 'Cambia scheda' : 'Collega scheda';
}

int? effectiveWorkoutSessionId(CalendarEventResponse event) {
  if (event.owner == true) {
    return event.ownerWorkoutSessionId ?? event.workoutSessionId;
  }
  if (event.participant == true) {
    return event.linkedWorkoutSessionId;
  }
  return event.workoutSessionId;
}

int? effectiveWorkoutTemplateId(
  CalendarEventResponse event,
  int? sessionTemplateId,
) {
  if (event.owner == true || event.participant == true) {
    return event.workoutTemplateId ?? sessionTemplateId;
  }
  return event.workoutTemplateId ?? sessionTemplateId;
}

Map<String, dynamic> workoutLinkPayload(int templateId) => {
  'templateId': templateId,
};
