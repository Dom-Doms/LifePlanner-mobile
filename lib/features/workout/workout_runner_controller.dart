import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/workout_models.dart';

class ExecutableWorkoutStep {
  const ExecutableWorkoutStep({
    required this.name,
    required this.stepType,
    required this.measurementType,
    required this.sortOrder,
    required this.blockIndex,
    required this.lap,
    required this.totalLaps,
    this.id,
    this.description,
    this.durationSeconds,
    this.reps,
    this.blockTitle,
    this.originStepId,
  });

  final int? id;
  final int? originStepId;
  final String name;
  final String? description;
  final String stepType;
  final String measurementType;
  final int? durationSeconds;
  final int? reps;
  final int sortOrder;
  final String? blockTitle;
  final int blockIndex;
  final int lap;
  final int totalLaps;

  bool get isTimed => measurementType == 'TIME';
  bool get isBreak => stepType == 'BREAK';
}

List<ExecutableWorkoutStep> flattenWorkoutTemplate(
  WorkoutTemplateResponse template,
) {
  final sequence = <ExecutableWorkoutStep>[];
  final topSteps = template.steps.isNotEmpty
      ? template.steps
      : _legacyExercisesToSteps(template);
  final items = <_SequenceItem>[
    ...topSteps.map((step) => _SequenceItem.step(step)),
    ...template.blocks.asMap().entries.map(
      (entry) => _SequenceItem.block(entry.value, entry.key),
    ),
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  for (final item in items) {
    if (item.step != null) {
      sequence.add(_toExecutable(item.step!, -1, 1, 1, null));
    } else if (item.block != null) {
      final block = item.block!;
      final repeat = block.repeatCount.clamp(1, 99).toInt();
      final steps = [...block.steps]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      for (var lap = 1; lap <= repeat; lap += 1) {
        for (final step in steps) {
          sequence.add(
            _toExecutable(step, item.blockIndex, lap, repeat, block),
          );
        }
      }
    }
  }

  return sequence
      .asMap()
      .entries
      .map(
        (entry) => ExecutableWorkoutStep(
          id: entry.value.id,
          originStepId: entry.value.originStepId,
          name: entry.value.name,
          description: entry.value.description,
          stepType: entry.value.stepType,
          measurementType: entry.value.measurementType,
          durationSeconds: entry.value.durationSeconds,
          reps: entry.value.reps,
          sortOrder: entry.key,
          blockTitle: entry.value.blockTitle,
          blockIndex: entry.value.blockIndex,
          lap: entry.value.lap,
          totalLaps: entry.value.totalLaps,
        ),
      )
      .toList();
}

class WorkoutRunnerController extends ChangeNotifier {
  WorkoutRunnerController({
    required WorkoutRunResponse run,
    this.onTimedStepComplete,
    this.onWorkoutComplete,
  }) {
    _sequence = flattenWorkoutTemplate(run.template);
    _hydrate(run);
    if (!isFinished) _startTimer();
  }

  List<ExecutableWorkoutStep> _sequence = [];
  Timer? _timer;
  int currentIndex = 0;
  int elapsedSeconds = 0;
  int remainingTime = 0;
  bool isPaused = false;
  bool isFinished = false;
  final void Function(ExecutableWorkoutStep step)? onTimedStepComplete;
  final VoidCallback? onWorkoutComplete;

  List<ExecutableWorkoutStep> get sequence => _sequence;
  ExecutableWorkoutStep? get currentStep =>
      currentIndex >= 0 && currentIndex < _sequence.length
      ? _sequence[currentIndex]
      : null;
  ExecutableWorkoutStep? get nextStep =>
      currentIndex + 1 < _sequence.length ? _sequence[currentIndex + 1] : null;
  double get progress {
    final step = currentStep;
    if (step == null || !step.isTimed) return 0;
    final total = step.durationSeconds ?? 1;
    return ((total - remainingTime) / total).clamp(0, 1).toDouble();
  }

  int get completedSteps => currentIndex.clamp(0, _sequence.length).toInt();

  Map<String, dynamic> snapshot({String? status}) => {
    'status': status,
    'elapsedSeconds': elapsedSeconds,
    'currentStepIndex': currentIndex,
    'currentBlockIndex': currentStep?.blockIndex ?? 0,
    'currentLap': currentStep?.lap ?? 1,
    'snapshotJson': jsonEncode({
      'remainingTime': remainingTime,
      'sequenceLength': _sequence.length,
    }),
  }..removeWhere((_, value) => value == null);

  void hydrateFromServer(WorkoutRunResponse run) {
    _sequence = flattenWorkoutTemplate(run.template);
    _hydrate(run);
    notifyListeners();
  }

  void pause() {
    isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (isFinished) return;
    isPaused = false;
    _startTimer();
    notifyListeners();
  }

  void next() {
    if (currentIndex >= _sequence.length - 1) {
      completeLocal();
      return;
    }
    currentIndex += 1;
    remainingTime = currentStep?.durationSeconds ?? 0;
    notifyListeners();
  }

  void previous() {
    currentIndex = (currentIndex - 1).clamp(0, _sequence.length - 1);
    remainingTime = currentStep?.durationSeconds ?? 0;
    notifyListeners();
  }

  void completeStep() => next();

  @visibleForTesting
  void tickOneSecond() => _handleTick();

  void completeLocal() {
    if (isFinished) return;
    isFinished = true;
    _timer?.cancel();
    onWorkoutComplete?.call();
    notifyListeners();
  }

  void _hydrate(WorkoutRunResponse run) {
    currentIndex = run.currentStepIndex
        .clamp(0, _sequence.isEmpty ? 0 : _sequence.length - 1)
        .toInt();
    elapsedSeconds = run.elapsedSeconds;
    isPaused = run.status == 'PAUSED';
    isFinished = run.status == 'COMPLETED' || run.status == 'CANCELLED';
    remainingTime =
        _readRemainingTime(run.snapshotJson) ??
        currentStep?.durationSeconds ??
        0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _handleTick());
  }

  void _handleTick() {
    if (isPaused || isFinished || currentStep == null) return;
    elapsedSeconds += 1;
    final step = currentStep!;
    if (step.isTimed) {
      remainingTime = (remainingTime - 1).clamp(0, 999999);
      if (remainingTime <= 0) {
        onTimedStepComplete?.call(step);
        next();
      }
    }
    notifyListeners();
  }

  int? _readRemainingTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['remainingTime'];
        if (value is int) return value;
        if (value is num) return value.toInt();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _SequenceItem {
  _SequenceItem.step(WorkoutStepDto step)
    : this._(
        step: step,
        block: null,
        blockIndex: -1,
        sortOrder: step.sortOrder,
      );

  _SequenceItem.block(WorkoutBlockDto block, int blockIndex)
    : this._(
        step: null,
        block: block,
        blockIndex: blockIndex,
        sortOrder: block.sortOrder,
      );

  const _SequenceItem._({
    required this.step,
    required this.block,
    required this.blockIndex,
    required this.sortOrder,
  });

  final WorkoutStepDto? step;
  final WorkoutBlockDto? block;
  final int blockIndex;
  final int sortOrder;
}

ExecutableWorkoutStep _toExecutable(
  WorkoutStepDto step,
  int blockIndex,
  int lap,
  int totalLaps,
  WorkoutBlockDto? block,
) => ExecutableWorkoutStep(
  id: step.id,
  originStepId: step.id,
  name: step.name,
  description: step.description,
  stepType: step.stepType,
  measurementType: step.measurementType,
  durationSeconds: step.durationSeconds,
  reps: step.reps,
  sortOrder: step.sortOrder,
  blockTitle: block?.title,
  blockIndex: blockIndex,
  lap: lap,
  totalLaps: totalLaps,
);

List<WorkoutStepDto> _legacyExercisesToSteps(WorkoutTemplateResponse template) {
  return template.exercises
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

int parseLegacyReps(String? reps) {
  final match = RegExp(r'^\s*(\d+)').firstMatch(reps ?? '');
  if (match == null) return 1;
  return int.tryParse(match.group(1) ?? '') ?? 1;
}
