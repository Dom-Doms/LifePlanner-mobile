import 'json_helpers.dart';

class WorkoutExerciseDto {
  const WorkoutExerciseDto({
    required this.name,
    required this.exerciseOrder,
    this.id,
    this.muscleGroup,
    this.sets,
    this.reps,
    this.suggestedWeight,
    this.restSeconds,
    this.notes,
  });

  factory WorkoutExerciseDto.fromJson(Map<String, dynamic> json) =>
      WorkoutExerciseDto(
        id: readNullableInt(json, 'id'),
        name: readString(json, 'name'),
        muscleGroup: readNullableString(json, 'muscleGroup'),
        sets: readNullableInt(json, 'sets'),
        reps: readNullableString(json, 'reps'),
        suggestedWeight: readNullableString(json, 'suggestedWeight'),
        restSeconds: readNullableInt(json, 'restSeconds'),
        notes: readNullableString(json, 'notes'),
        exerciseOrder: readInt(json, 'exerciseOrder'),
      );

  final int? id;
  final String name;
  final String? muscleGroup;
  final int? sets;
  final String? reps;
  final String? suggestedWeight;
  final int? restSeconds;
  final String? notes;
  final int exerciseOrder;

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'sets': sets,
    'reps': reps,
    'suggestedWeight': suggestedWeight,
    'restSeconds': restSeconds,
    'notes': notes,
    'exerciseOrder': exerciseOrder,
  });
}

class WorkoutStepDto {
  const WorkoutStepDto({
    required this.name,
    required this.stepType,
    required this.measurementType,
    required this.sortOrder,
    this.id,
    this.blockId,
    this.description,
    this.durationSeconds,
    this.reps,
    this.color,
    this.intensity,
    this.active,
  });

  factory WorkoutStepDto.fromJson(Map<String, dynamic> json) => WorkoutStepDto(
    id: readNullableInt(json, 'id'),
    blockId: readNullableInt(json, 'blockId'),
    name: readString(json, 'name'),
    description: readNullableString(json, 'description'),
    stepType: readString(json, 'stepType', 'ACTIVE'),
    measurementType: readString(json, 'measurementType', 'REPS'),
    durationSeconds: readNullableInt(json, 'durationSeconds'),
    reps: readNullableInt(json, 'reps'),
    sortOrder: readInt(json, 'sortOrder'),
    color: readNullableString(json, 'color'),
    intensity: readNullableString(json, 'intensity'),
    active: readNullableBool(json, 'active'),
  );

  final int? id;
  final int? blockId;
  final String name;
  final String? description;
  final String stepType;
  final String measurementType;
  final int? durationSeconds;
  final int? reps;
  final int sortOrder;
  final String? color;
  final String? intensity;
  final bool? active;

  WorkoutStepDto copyWith({
    int? id,
    int? blockId,
    String? name,
    String? description,
    String? stepType,
    String? measurementType,
    int? durationSeconds,
    int? reps,
    int? sortOrder,
    String? color,
    String? intensity,
    bool? active,
  }) => WorkoutStepDto(
    id: id ?? this.id,
    blockId: blockId ?? this.blockId,
    name: name ?? this.name,
    description: description ?? this.description,
    stepType: stepType ?? this.stepType,
    measurementType: measurementType ?? this.measurementType,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    reps: reps ?? this.reps,
    sortOrder: sortOrder ?? this.sortOrder,
    color: color ?? this.color,
    intensity: intensity ?? this.intensity,
    active: active ?? this.active,
  );

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'blockId': blockId,
    'name': name,
    'description': description,
    'stepType': stepType,
    'measurementType': measurementType,
    'durationSeconds': durationSeconds,
    'reps': reps,
    'sortOrder': sortOrder,
    'color': color,
    'intensity': intensity,
    'active': active,
  });
}

class WorkoutBlockDto {
  const WorkoutBlockDto({
    required this.title,
    required this.sortOrder,
    required this.repeatCount,
    required this.steps,
    this.id,
    this.color,
    this.collapsed,
  });

  factory WorkoutBlockDto.fromJson(Map<String, dynamic> json) =>
      WorkoutBlockDto(
        id: readNullableInt(json, 'id'),
        title: readString(json, 'title'),
        sortOrder: readInt(json, 'sortOrder'),
        repeatCount: readInt(json, 'repeatCount', 1),
        color: readNullableString(json, 'color'),
        collapsed: readNullableBool(json, 'collapsed'),
        steps: asMapList(json['steps']).map(WorkoutStepDto.fromJson).toList(),
      );

  final int? id;
  final String title;
  final int sortOrder;
  final int repeatCount;
  final String? color;
  final bool? collapsed;
  final List<WorkoutStepDto> steps;

  WorkoutBlockDto copyWith({
    int? id,
    String? title,
    int? sortOrder,
    int? repeatCount,
    String? color,
    bool? collapsed,
    List<WorkoutStepDto>? steps,
  }) => WorkoutBlockDto(
    id: id ?? this.id,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    repeatCount: repeatCount ?? this.repeatCount,
    color: color ?? this.color,
    collapsed: collapsed ?? this.collapsed,
    steps: steps ?? this.steps,
  );

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'title': title,
    'sortOrder': sortOrder,
    'repeatCount': repeatCount,
    'color': color,
    'collapsed': collapsed,
    'steps': steps.map((item) => item.toJson()).toList(),
  });
}

class WorkoutTemplateResponse {
  const WorkoutTemplateResponse({
    required this.id,
    required this.name,
    required this.active,
    required this.exercises,
    this.description,
    this.estimatedDurationSeconds,
    this.blocks = const [],
    this.steps = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory WorkoutTemplateResponse.fromJson(
    Map<String, dynamic> json,
  ) => WorkoutTemplateResponse(
    id: readInt(json, 'id'),
    name: readString(json, 'name'),
    description: readNullableString(json, 'description'),
    active: readBool(json, 'active', true),
    estimatedDurationSeconds: readNullableInt(json, 'estimatedDurationSeconds'),
    exercises: asMapList(
      json['exercises'],
    ).map(WorkoutExerciseDto.fromJson).toList(),
    blocks: asMapList(json['blocks']).map(WorkoutBlockDto.fromJson).toList(),
    steps: asMapList(json['steps']).map(WorkoutStepDto.fromJson).toList(),
    createdAt: readNullableString(json, 'createdAt'),
    updatedAt: readNullableString(json, 'updatedAt'),
  );

  final int id;
  final String name;
  final String? description;
  final bool active;
  final int? estimatedDurationSeconds;
  final List<WorkoutExerciseDto> exercises;
  final List<WorkoutBlockDto> blocks;
  final List<WorkoutStepDto> steps;
  final String? createdAt;
  final String? updatedAt;

  Map<String, dynamic> toRequestJson() => withoutNulls({
    'name': name,
    'description': description,
    'estimatedDurationSeconds': estimatedDurationSeconds,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'blocks': blocks.map((item) => item.toJson()).toList(),
    'steps': steps.map((item) => item.toJson()).toList(),
  });
}

class WorkoutParticipantDto {
  const WorkoutParticipantDto({
    required this.displayName,
    required this.participantType,
    this.id,
    this.userId,
  });

  factory WorkoutParticipantDto.fromJson(Map<String, dynamic> json) =>
      WorkoutParticipantDto(
        id: readNullableInt(json, 'id'),
        userId: readNullableInt(json, 'userId'),
        displayName: readString(json, 'displayName'),
        participantType: readString(json, 'participantType', 'FREE_TEXT'),
      );

  final int? id;
  final int? userId;
  final String displayName;
  final String participantType;

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'userId': userId,
    'displayName': displayName,
    'participantType': participantType,
  });
}

class WorkoutSessionExerciseDto {
  const WorkoutSessionExerciseDto({
    required this.name,
    required this.exerciseOrder,
    this.id,
    this.muscleGroup,
    this.plannedSets,
    this.plannedReps,
    this.plannedWeight,
    this.actualSets,
    this.actualReps,
    this.actualWeight,
    this.restSeconds,
    this.notes,
  });

  factory WorkoutSessionExerciseDto.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionExerciseDto(
        id: readNullableInt(json, 'id'),
        name: readString(json, 'name'),
        muscleGroup: readNullableString(json, 'muscleGroup'),
        plannedSets: readNullableInt(json, 'plannedSets'),
        plannedReps: readNullableString(json, 'plannedReps'),
        plannedWeight: readNullableString(json, 'plannedWeight'),
        actualSets: readNullableInt(json, 'actualSets'),
        actualReps: readNullableString(json, 'actualReps'),
        actualWeight: readNullableString(json, 'actualWeight'),
        restSeconds: readNullableInt(json, 'restSeconds'),
        notes: readNullableString(json, 'notes'),
        exerciseOrder: readInt(json, 'exerciseOrder'),
      );

  final int? id;
  final String name;
  final String? muscleGroup;
  final int? plannedSets;
  final String? plannedReps;
  final String? plannedWeight;
  final int? actualSets;
  final String? actualReps;
  final String? actualWeight;
  final int? restSeconds;
  final String? notes;
  final int exerciseOrder;

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'plannedSets': plannedSets,
    'plannedReps': plannedReps,
    'plannedWeight': plannedWeight,
    'actualSets': actualSets,
    'actualReps': actualReps,
    'actualWeight': actualWeight,
    'restSeconds': restSeconds,
    'notes': notes,
    'exerciseOrder': exerciseOrder,
  });
}

class WorkoutSessionResponse {
  const WorkoutSessionResponse({
    required this.id,
    required this.date,
    required this.title,
    required this.participants,
    required this.exercises,
    this.templateId,
    this.notes,
  });

  factory WorkoutSessionResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionResponse(
        id: readInt(json, 'id'),
        date: readString(json, 'date'),
        templateId: readNullableInt(json, 'templateId'),
        title: readString(json, 'title'),
        notes: readNullableString(json, 'notes'),
        participants: asMapList(
          json['participants'],
        ).map(WorkoutParticipantDto.fromJson).toList(),
        exercises: asMapList(
          json['exercises'],
        ).map(WorkoutSessionExerciseDto.fromJson).toList(),
      );

  final int id;
  final String date;
  final int? templateId;
  final String title;
  final String? notes;
  final List<WorkoutParticipantDto> participants;
  final List<WorkoutSessionExerciseDto> exercises;
}

class WorkoutRunStepResponse {
  const WorkoutRunStepResponse({
    required this.name,
    required this.stepType,
    required this.measurementType,
    required this.sequenceIndex,
    required this.blockIndex,
    required this.currentSet,
    required this.totalSets,
    this.stepId,
    this.durationSeconds,
    this.reps,
    this.blockId,
    this.blockTitle,
  });

  factory WorkoutRunStepResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutRunStepResponse(
        stepId: readNullableInt(json, 'stepId'),
        name: readString(json, 'name'),
        stepType: readString(json, 'stepType', 'ACTIVE'),
        measurementType: readString(json, 'measurementType', 'REPS'),
        durationSeconds: readNullableInt(json, 'durationSeconds'),
        reps: readNullableInt(json, 'reps'),
        sequenceIndex: readInt(json, 'sequenceIndex'),
        blockId: readNullableInt(json, 'blockId'),
        blockTitle: readNullableString(json, 'blockTitle'),
        blockIndex: readInt(json, 'blockIndex'),
        currentSet: readInt(json, 'currentSet', 1),
        totalSets: readInt(json, 'totalSets', 1),
      );

  final int? stepId;
  final String name;
  final String stepType;
  final String measurementType;
  final int? durationSeconds;
  final int? reps;
  final int sequenceIndex;
  final int? blockId;
  final String? blockTitle;
  final int blockIndex;
  final int currentSet;
  final int totalSets;
}

class WorkoutRunResponse {
  const WorkoutRunResponse({
    required this.id,
    required this.templateId,
    required this.status,
    required this.elapsedSeconds,
    required this.currentStepIndex,
    required this.currentBlockIndex,
    required this.currentLap,
    required this.totalSteps,
    required this.remainingSteps,
    required this.template,
    required this.createdAt,
    required this.updatedAt,
    this.relatedWorkoutSessionId,
    this.startedAt,
    this.completedAt,
    this.pausedAt,
    this.currentStep,
    this.nextStep,
    this.snapshotJson,
  });

  factory WorkoutRunResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutRunResponse(
        id: readInt(json, 'id'),
        templateId: readInt(json, 'templateId'),
        relatedWorkoutSessionId: readNullableInt(
          json,
          'relatedWorkoutSessionId',
        ),
        status: readString(json, 'status', 'NOT_STARTED'),
        startedAt: readNullableString(json, 'startedAt'),
        completedAt: readNullableString(json, 'completedAt'),
        pausedAt: readNullableString(json, 'pausedAt'),
        elapsedSeconds: readInt(json, 'elapsedSeconds'),
        currentStepIndex: readInt(json, 'currentStepIndex'),
        currentBlockIndex: readInt(json, 'currentBlockIndex'),
        currentLap: readInt(json, 'currentLap', 1),
        totalSteps: readInt(json, 'totalSteps'),
        remainingSteps: readInt(json, 'remainingSteps'),
        currentStep: json['currentStep'] == null
            ? null
            : WorkoutRunStepResponse.fromJson(asMap(json['currentStep'])),
        nextStep: json['nextStep'] == null
            ? null
            : WorkoutRunStepResponse.fromJson(asMap(json['nextStep'])),
        snapshotJson: readNullableString(json, 'snapshotJson'),
        template: WorkoutTemplateResponse.fromJson(asMap(json['template'])),
        createdAt: readString(json, 'createdAt'),
        updatedAt: readString(json, 'updatedAt'),
      );

  final int id;
  final int templateId;
  final int? relatedWorkoutSessionId;
  final String status;
  final String? startedAt;
  final String? completedAt;
  final String? pausedAt;
  final int elapsedSeconds;
  final int currentStepIndex;
  final int currentBlockIndex;
  final int currentLap;
  final int totalSteps;
  final int remainingSteps;
  final WorkoutRunStepResponse? currentStep;
  final WorkoutRunStepResponse? nextStep;
  final String? snapshotJson;
  final WorkoutTemplateResponse template;
  final String createdAt;
  final String updatedAt;
}
