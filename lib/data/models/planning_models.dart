import 'json_helpers.dart';

class DayContextResponse {
  const DayContextResponse({
    required this.id,
    required this.label,
    required this.active,
    this.color,
    this.emoji,
  });

  factory DayContextResponse.fromJson(Map<String, dynamic> json) =>
      DayContextResponse(
        id: readInt(json, 'id'),
        label: readString(json, 'label'),
        active: readBool(json, 'active', true),
        color: readNullableString(json, 'color'),
        emoji: readNullableString(json, 'emoji'),
      );

  final int id;
  final String label;
  final bool active;
  final String? color;
  final String? emoji;

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'label': label,
    'active': active,
    'color': color,
    'emoji': emoji,
  });
}

class DailyPlanResponse {
  const DailyPlanResponse({
    required this.id,
    required this.date,
    this.context,
    this.notes,
  });

  factory DailyPlanResponse.fromJson(Map<String, dynamic> json) =>
      DailyPlanResponse(
        id: readInt(json, 'id'),
        date: readString(json, 'date'),
        context: json['context'] == null
            ? null
            : DayContextResponse.fromJson(asMap(json['context'])),
        notes: readNullableString(json, 'notes'),
      );

  final int id;
  final String date;
  final DayContextResponse? context;
  final String? notes;
}

class ParticipantDto {
  const ParticipantDto({
    required this.displayName,
    required this.participantType,
    this.id,
    this.registeredUserId,
    this.hidden,
    this.linkedWorkoutSessionId,
    this.completed,
    this.completedAt,
  });

  factory ParticipantDto.fromJson(Map<String, dynamic> json) => ParticipantDto(
    id: readNullableInt(json, 'id'),
    registeredUserId: readNullableInt(json, 'registeredUserId'),
    displayName: readString(json, 'displayName'),
    participantType: readString(json, 'participantType', 'FREE_TEXT'),
    hidden: readNullableBool(json, 'hidden'),
    linkedWorkoutSessionId: readNullableInt(json, 'linkedWorkoutSessionId'),
    completed: readNullableBool(json, 'completed'),
    completedAt: readNullableString(json, 'completedAt'),
  );

  final int? id;
  final int? registeredUserId;
  final String displayName;
  final String participantType;
  final bool? hidden;
  final int? linkedWorkoutSessionId;
  final bool? completed;
  final String? completedAt;

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'registeredUserId': registeredUserId,
    'displayName': displayName,
    'participantType': participantType,
    'hidden': hidden,
    'linkedWorkoutSessionId': linkedWorkoutSessionId,
    'completed': completed,
    'completedAt': completedAt,
  });
}

class CalendarEventResponse {
  const CalendarEventResponse({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.allDay,
    required this.type,
    required this.reminderEnabled,
    required this.participants,
    this.description,
    this.startTime,
    this.endTime,
    this.location,
    this.color,
    this.workoutSessionId,
    this.workoutTemplateId,
    this.recurrenceType,
    this.recurrenceUntil,
    this.reminderMinutesBefore,
    this.reminderSentAt,
    this.completed,
    this.completedAt,
    this.owner,
    this.participant,
    this.hidden,
    this.linkedWorkoutSessionId,
    this.ownerWorkoutSessionId,
    this.canEdit,
    this.canRemoveForMe,
    this.needsWorkoutLink,
  });

  factory CalendarEventResponse.fromJson(Map<String, dynamic> json) =>
      CalendarEventResponse(
        id: readInt(json, 'id'),
        title: readString(json, 'title'),
        description: readNullableString(json, 'description'),
        eventDate: readString(json, 'eventDate'),
        startTime: readNullableString(json, 'startTime'),
        endTime: readNullableString(json, 'endTime'),
        allDay: readBool(json, 'allDay'),
        type: readString(json, 'type', 'OTHER'),
        location: readNullableString(json, 'location'),
        color: readNullableString(json, 'color'),
        workoutSessionId: readNullableInt(json, 'workoutSessionId'),
        workoutTemplateId: readNullableInt(json, 'workoutTemplateId'),
        recurrenceType: readNullableString(json, 'recurrenceType'),
        recurrenceUntil: readNullableString(json, 'recurrenceUntil'),
        reminderEnabled: readBool(json, 'reminderEnabled'),
        reminderMinutesBefore: readNullableInt(json, 'reminderMinutesBefore'),
        reminderSentAt: readNullableString(json, 'reminderSentAt'),
        completed: readNullableBool(json, 'completed'),
        completedAt: readNullableString(json, 'completedAt'),
        owner: readNullableBool(json, 'owner'),
        participant: readNullableBool(json, 'participant'),
        hidden: readNullableBool(json, 'hidden'),
        linkedWorkoutSessionId: readNullableInt(json, 'linkedWorkoutSessionId'),
        ownerWorkoutSessionId: readNullableInt(json, 'ownerWorkoutSessionId'),
        canEdit: readNullableBool(json, 'canEdit'),
        canRemoveForMe: readNullableBool(json, 'canRemoveForMe'),
        needsWorkoutLink: readNullableBool(json, 'needsWorkoutLink'),
        participants: asMapList(
          json['participants'],
        ).map(ParticipantDto.fromJson).toList(),
      );

  final int id;
  final String title;
  final String? description;
  final String eventDate;
  final String? startTime;
  final String? endTime;
  final bool allDay;
  final String type;
  final String? location;
  final String? color;
  final int? workoutSessionId;
  final int? workoutTemplateId;
  final String? recurrenceType;
  final String? recurrenceUntil;
  final bool reminderEnabled;
  final int? reminderMinutesBefore;
  final String? reminderSentAt;
  final bool? completed;
  final String? completedAt;
  final bool? owner;
  final bool? participant;
  final bool? hidden;
  final int? linkedWorkoutSessionId;
  final int? ownerWorkoutSessionId;
  final bool? canEdit;
  final bool? canRemoveForMe;
  final bool? needsWorkoutLink;
  final List<ParticipantDto> participants;
}

Map<String, dynamic> calendarEventRequest({
  required String title,
  required String eventDate,
  required bool allDay,
  required String type,
  String? description,
  String? startTime,
  String? endTime,
  String? location,
  String? color,
  int? workoutSessionId,
  int? workoutTemplateId,
  String? recurrenceType,
  String? recurrenceUntil,
  bool reminderEnabled = false,
  int? reminderMinutesBefore,
  List<ParticipantDto> participants = const [],
}) => withoutNulls({
  'title': title,
  'description': description,
  'eventDate': eventDate,
  'startTime': allDay ? null : startTime,
  'endTime': allDay ? null : endTime,
  'allDay': allDay,
  'type': type,
  'location': location,
  'color': color,
  'workoutSessionId': workoutSessionId,
  'workoutTemplateId': workoutTemplateId,
  'recurrenceType': recurrenceType ?? 'NONE',
  'recurrenceUntil': recurrenceUntil,
  'reminderEnabled': reminderEnabled,
  'reminderMinutesBefore': reminderEnabled ? reminderMinutesBefore : null,
  'participants': participants.map((item) => item.toJson()).toList(),
});
