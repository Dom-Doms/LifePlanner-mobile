import '../../data/models/json_helpers.dart';
import '../../data/models/workout_models.dart';
import 'workout_runner_controller.dart';

class WorkoutEditorException implements Exception {
  const WorkoutEditorException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WorkoutEditorValidationException extends WorkoutEditorException {
  const WorkoutEditorValidationException(super.message);
}

class WorkoutEditorDraft {
  WorkoutEditorDraft({
    required this.name,
    required this.description,
    required List<WorkoutStepDto> topSteps,
    required List<WorkoutBlockDto> blocks,
    required List<WorkoutExerciseDto> legacyExercises,
  }) : topSteps = List.of(topSteps),
       blocks = List.of(blocks),
       legacyExercises = List.of(legacyExercises);

  factory WorkoutEditorDraft.empty() => WorkoutEditorDraft(
    name: '',
    description: '',
    topSteps: [],
    blocks: [],
    legacyExercises: [],
  );

  factory WorkoutEditorDraft.fromTemplate(WorkoutTemplateResponse template) {
    if (template.id <= 0 || template.name.trim().isEmpty) {
      throw const WorkoutEditorException('Payload scheda workout non valido.');
    }

    var topSteps = template.steps.map(_normalizeLoadedStep).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final blocks = template.blocks.map(_normalizeLoadedBlock).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final legacyExercises = [...template.exercises]
      ..sort((a, b) => a.exerciseOrder.compareTo(b.exerciseOrder));

    if (topSteps.isEmpty && blocks.isEmpty && legacyExercises.isNotEmpty) {
      topSteps = legacyExercises
          .asMap()
          .entries
          .map(
            (entry) => WorkoutStepDto(
              id: entry.value.id,
              name: entry.value.name,
              description: entry.value.notes,
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: parseLegacyReps(entry.value.reps),
              sortOrder: entry.key,
              intensity: entry.value.muscleGroup,
              active: true,
            ),
          )
          .toList();
    }

    final draft = WorkoutEditorDraft(
      name: template.name,
      description: template.description ?? '',
      topSteps: topSteps,
      blocks: blocks,
      legacyExercises: legacyExercises,
    );
    draft.normalizeTopLevelOrder();
    return draft;
  }

  String name;
  String description;
  List<WorkoutStepDto> topSteps;
  List<WorkoutBlockDto> blocks;
  List<WorkoutExerciseDto> legacyExercises;

  bool get hasStructure =>
      topSteps.isNotEmpty || blocks.any((block) => block.steps.isNotEmpty);

  List<EditableWorkoutItem> orderedItems() {
    final items = [
      ...topSteps.map(EditableWorkoutItem.step),
      ...blocks.map(EditableWorkoutItem.block),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  void addTopStep(WorkoutStepDto step) {
    topSteps.add(
      step.copyWith(sortOrder: orderedItems().length, clearBlockId: true),
    );
    normalizeTopLevelOrder();
  }

  void addBlock(WorkoutBlockDto block) {
    blocks.add(
      block.copyWith(
        sortOrder: orderedItems().length,
        repeatCount: normalizeRepeatCount(block.repeatCount),
        steps: normalizeSteps(block.steps),
      ),
    );
    normalizeTopLevelOrder();
  }

  void replaceTopStep(WorkoutStepDto oldStep, WorkoutStepDto newStep) {
    final index = topSteps.indexOf(oldStep);
    if (index < 0) return;
    topSteps[index] = newStep.copyWith(
      sortOrder: oldStep.sortOrder,
      clearBlockId: true,
    );
  }

  void removeTopStep(WorkoutStepDto step) {
    topSteps.remove(step);
    normalizeTopLevelOrder();
  }

  void replaceBlock(WorkoutBlockDto oldBlock, WorkoutBlockDto newBlock) {
    final index = blocks.indexOf(oldBlock);
    if (index < 0) return;
    blocks[index] = newBlock.copyWith(
      sortOrder: oldBlock.sortOrder,
      repeatCount: normalizeRepeatCount(newBlock.repeatCount),
      steps: normalizeSteps(newBlock.steps),
    );
  }

  void removeBlock(WorkoutBlockDto block) {
    blocks.remove(block);
    normalizeTopLevelOrder();
  }

  void addBlockStep(WorkoutBlockDto block, WorkoutStepDto step) {
    final steps = [
      ...block.steps,
      step.copyWith(sortOrder: block.steps.length),
    ];
    replaceBlock(block, block.copyWith(steps: normalizeSteps(steps)));
  }

  void replaceBlockStep(
    WorkoutBlockDto block,
    WorkoutStepDto oldStep,
    WorkoutStepDto newStep,
  ) {
    final steps = [...block.steps];
    final index = steps.indexOf(oldStep);
    if (index < 0) return;
    steps[index] = newStep.copyWith(sortOrder: oldStep.sortOrder);
    replaceBlock(block, block.copyWith(steps: normalizeSteps(steps)));
  }

  void removeBlockStep(WorkoutBlockDto block, WorkoutStepDto step) {
    final steps = [...block.steps]..remove(step);
    replaceBlock(block, block.copyWith(steps: normalizeSteps(steps)));
  }

  void moveTopLevelItem(int position, int delta) {
    final items = orderedItems();
    if (items.isEmpty) return;
    final newPosition = (position + delta).clamp(0, items.length - 1).toInt();
    if (newPosition == position) return;
    final moved = items.removeAt(position);
    items.insert(newPosition, moved);
    _applyTopLevelOrder(items);
  }

  void reorderTopLevelItem(int oldIndex, int newIndex) {
    final items = orderedItems();
    if (items.isEmpty || oldIndex < 0 || oldIndex >= items.length) return;
    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (targetIndex < 0 ||
        targetIndex >= items.length ||
        targetIndex == oldIndex) {
      return;
    }
    final moved = items.removeAt(oldIndex);
    items.insert(targetIndex, moved);
    _applyTopLevelOrder(items);
  }

  void reorderBlockStep(WorkoutBlockDto block, int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= block.steps.length) return;
    final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (targetIndex < 0 ||
        targetIndex >= block.steps.length ||
        targetIndex == oldIndex) {
      return;
    }
    final steps = [...block.steps];
    final moved = steps.removeAt(oldIndex);
    steps.insert(targetIndex, moved);
    final reordered = steps
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sortOrder: entry.key))
        .toList();
    replaceBlock(block, block.copyWith(steps: reordered));
  }

  void normalizeTopLevelOrder() => _applyTopLevelOrder(orderedItems());

  Map<String, dynamic> toRequestPayload() {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const WorkoutEditorValidationException(
        'Il nome scheda e obbligatorio.',
      );
    }
    normalizeTopLevelOrder();
    final normalizedTopSteps = [...topSteps]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final normalizedBlocks = blocks
        .map(
          (block) => block.copyWith(
            repeatCount: normalizeRepeatCount(block.repeatCount),
            steps: normalizeSteps(block.steps),
          ),
        )
        .toList();
    return withoutNulls({
      'name': trimmedName,
      'description': description.trim(),
      'estimatedDurationSeconds': estimateDuration(
        normalizedTopSteps,
        normalizedBlocks,
        legacyExercises,
      ),
      'exercises': legacyExercises.map((item) => item.toJson()).toList(),
      'steps': normalizedTopSteps
          .map(
            (step) =>
                workoutStepRequestPayload(step, sortOrder: step.sortOrder),
          )
          .toList(),
      'blocks': normalizedBlocks.map(workoutBlockRequestPayload).toList(),
    });
  }

  void _applyTopLevelOrder(List<EditableWorkoutItem> items) {
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item.step != null) {
        final stepIndex = topSteps.indexOf(item.step!);
        if (stepIndex >= 0) {
          topSteps[stepIndex] = item.step!.copyWith(
            sortOrder: index,
            clearBlockId: true,
          );
        }
      } else {
        final blockIndex = blocks.indexOf(item.block!);
        if (blockIndex >= 0) {
          blocks[blockIndex] = item.block!.copyWith(sortOrder: index);
        }
      }
    }
  }
}

class EditableWorkoutItem {
  EditableWorkoutItem.step(WorkoutStepDto step)
    : this._(step: step, block: null, sortOrder: step.sortOrder);

  EditableWorkoutItem.block(WorkoutBlockDto block)
    : this._(step: null, block: block, sortOrder: block.sortOrder);

  const EditableWorkoutItem._({
    required this.step,
    required this.block,
    required this.sortOrder,
  });

  final WorkoutStepDto? step;
  final WorkoutBlockDto? block;
  final int sortOrder;
}

WorkoutStepDto makeWorkoutEditorStep({
  required String stepType,
  required int sortOrder,
}) {
  final isBreak = stepType == 'BREAK';
  return WorkoutStepDto(
    name: isBreak ? 'Recupero' : '',
    description: '',
    stepType: isBreak ? 'BREAK' : 'ACTIVE',
    measurementType: isBreak ? 'TIME' : 'REPS',
    durationSeconds: isBreak ? 30 : null,
    reps: isBreak ? null : 10,
    sortOrder: sortOrder,
    color: isBreak ? 'var(--workout-break)' : 'var(--workout-active)',
    active: true,
  );
}

WorkoutBlockDto makeWorkoutEditorBlock({required int sortOrder}) {
  return WorkoutBlockDto(
    title: 'Nuovo gruppo',
    sortOrder: sortOrder,
    repeatCount: 2,
    color: 'var(--app-accent)',
    collapsed: false,
    steps: const [],
  );
}

List<WorkoutStepDto> normalizeSteps(List<WorkoutStepDto> steps) {
  final sorted = [...steps]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return sorted
      .asMap()
      .entries
      .map((entry) => entry.value.copyWith(sortOrder: entry.key))
      .toList();
}

int normalizeRepeatCount(int repeatCount) => repeatCount.clamp(1, 99).toInt();

int estimateDuration(
  List<WorkoutStepDto> topSteps,
  List<WorkoutBlockDto> blocks,
  List<WorkoutExerciseDto> legacyExercises,
) {
  var total = topSteps.fold<int>(0, (sum, step) => sum + estimateStep(step));
  for (final block in blocks) {
    final blockDuration = block.steps.fold<int>(
      0,
      (sum, step) => sum + estimateStep(step),
    );
    total += blockDuration * normalizeRepeatCount(block.repeatCount);
  }
  if (total == 0) {
    total = legacyExercises.fold<int>(0, (sum, exercise) {
      final reps = parseLegacyReps(exercise.reps);
      final sets = (exercise.sets ?? 1).clamp(1, 99).toInt();
      final rest = (exercise.restSeconds ?? 0).clamp(0, 3600).toInt();
      return sum + reps * 5 * sets + rest;
    });
  }
  return total;
}

int estimateStep(WorkoutStepDto step) {
  if (step.stepType == 'BREAK' || step.measurementType == 'TIME') {
    return step.durationSeconds == null
        ? 0
        : step.durationSeconds!.clamp(0, 86400);
  }
  return step.reps == null ? 0 : step.reps!.clamp(0, 10000) * 5;
}

Map<String, dynamic> workoutBlockRequestPayload(WorkoutBlockDto block) {
  final steps = normalizeSteps(block.steps);
  return withoutNulls({
    'id': block.id,
    'title': block.title.trim(),
    'sortOrder': block.sortOrder,
    'repeatCount': normalizeRepeatCount(block.repeatCount),
    'color': block.color,
    'collapsed': block.collapsed,
    'steps': steps
        .asMap()
        .entries
        .map(
          (entry) =>
              workoutStepRequestPayload(entry.value, sortOrder: entry.key),
        )
        .toList(),
  });
}

Map<String, dynamic> workoutStepRequestPayload(
  WorkoutStepDto step, {
  required int sortOrder,
}) {
  final stepType = step.stepType == 'BREAK' ? 'BREAK' : 'ACTIVE';
  final measurementType = stepType == 'BREAK'
      ? 'TIME'
      : step.measurementType == 'TIME'
      ? 'TIME'
      : 'REPS';
  return withoutNulls({
    'id': step.id,
    'blockId': null,
    'name': step.name.trim(),
    'description': step.description?.trim(),
    'stepType': stepType,
    'measurementType': measurementType,
    'durationSeconds': measurementType == 'TIME' ? step.durationSeconds : null,
    'reps': stepType == 'ACTIVE' && measurementType == 'REPS'
        ? step.reps
        : null,
    'sortOrder': sortOrder,
    'color': step.color,
    'intensity': step.intensity,
    'active': step.active,
  });
}

WorkoutStepDto _normalizeLoadedStep(WorkoutStepDto step) {
  final stepType = step.stepType == 'BREAK' ? 'BREAK' : 'ACTIVE';
  final measurementType = stepType == 'BREAK'
      ? 'TIME'
      : step.measurementType == 'TIME'
      ? 'TIME'
      : 'REPS';
  final name = step.name.trim();
  if (name.isEmpty) {
    throw const WorkoutEditorException('Payload step workout non valido.');
  }
  return WorkoutStepDto(
    id: step.id,
    blockId: step.blockId,
    name: name,
    description: step.description,
    stepType: stepType,
    measurementType: measurementType,
    durationSeconds: measurementType == 'TIME' ? step.durationSeconds : null,
    reps: measurementType == 'REPS' ? step.reps : null,
    sortOrder: step.sortOrder,
    color: step.color,
    intensity: step.intensity,
    active: step.active ?? true,
  );
}

WorkoutBlockDto _normalizeLoadedBlock(WorkoutBlockDto block) {
  final title = block.title.trim();
  if (title.isEmpty) {
    throw const WorkoutEditorException('Payload gruppo workout non valido.');
  }
  return WorkoutBlockDto(
    id: block.id,
    title: title,
    sortOrder: block.sortOrder,
    repeatCount: normalizeRepeatCount(block.repeatCount),
    color: block.color,
    collapsed: block.collapsed ?? false,
    steps: normalizeSteps(block.steps.map(_normalizeLoadedStep).toList()),
  );
}
