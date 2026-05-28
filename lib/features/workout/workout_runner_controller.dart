import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/workout_models.dart';

class ExecutableWorkoutStep {
  const ExecutableWorkoutStep({
    required this.sequenceKey,
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

  final String sequenceKey;
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

  ExecutableWorkoutStep copyWith({int? sortOrder}) => ExecutableWorkoutStep(
    sequenceKey: sequenceKey,
    id: id,
    originStepId: originStepId,
    name: name,
    description: description,
    stepType: stepType,
    measurementType: measurementType,
    durationSeconds: durationSeconds,
    reps: reps,
    sortOrder: sortOrder ?? this.sortOrder,
    blockTitle: blockTitle,
    blockIndex: blockIndex,
    lap: lap,
    totalLaps: totalLaps,
  );
}

class RunnerSequenceItem {
  const RunnerSequenceItem({
    required this.key,
    required this.title,
    required this.steps,
    required this.startIndex,
    required this.endIndex,
    required this.isGroup,
    this.subtitle,
  });

  final String key;
  final String title;
  final String? subtitle;
  final List<ExecutableWorkoutStep> steps;
  final int startIndex;
  final int endIndex;
  final bool isGroup;

  bool get isSingleStep => !isGroup;
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
          sequenceKey: _sequenceKey(entry.value, entry.key),
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
    this.useInternalTimer = true,
    this.onTimedStepComplete,
    this.onWorkoutComplete,
  }) {
    _sequence = flattenWorkoutTemplate(run.template);
    _hydrate(run);
    if (useInternalTimer && !isFinished) _startTimer();
  }

  List<ExecutableWorkoutStep> _sequence = [];
  Timer? _timer;
  int currentIndex = 0;
  int elapsedSeconds = 0;
  int remainingTime = 0;
  bool isPaused = false;
  bool isFinished = false;
  final bool useInternalTimer;
  final void Function(ExecutableWorkoutStep step)? onTimedStepComplete;
  final VoidCallback? onWorkoutComplete;

  List<ExecutableWorkoutStep> get sequence => _sequence;
  List<RunnerSequenceItem> get reorderableItems =>
      buildRunnerSequenceItems(_sequence);
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
      'sequenceOrder': _sequence.map((step) => step.sequenceKey).toList(),
    }),
  }..removeWhere((_, value) => value == null);

  void hydrateFromServer(WorkoutRunResponse run) {
    final flattened = flattenWorkoutTemplate(run.template);
    if (_hasCompatibleSnapshotOrder(flattened, run.snapshotJson) ||
        !_hasSameSequenceMembers(_sequence, flattened)) {
      _sequence = flattened;
    }
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
    if (useInternalTimer) _startTimer();
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

  bool reorderFutureStep(int oldIndex, int newIndex) {
    if (oldIndex <= currentIndex ||
        oldIndex < 0 ||
        oldIndex >= _sequence.length ||
        _sequence.length < 2) {
      return false;
    }
    var targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    targetIndex = targetIndex.clamp(currentIndex + 1, _sequence.length - 1);
    if (targetIndex == oldIndex) return false;

    final steps = [..._sequence];
    final moved = steps.removeAt(oldIndex);
    steps.insert(targetIndex, moved);
    _sequence = _withDisplayOrder(steps);
    notifyListeners();
    return true;
  }

  bool reorderFutureItem(int oldIndex, int newIndex) {
    final items = reorderableItems;
    if (oldIndex < 0 || oldIndex >= items.length || items.length < 2) {
      return false;
    }
    final movedItem = items[oldIndex];
    if (movedItem.startIndex <= currentIndex) return false;

    var targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    targetIndex = targetIndex.clamp(0, items.length - 1);
    while (targetIndex < items.length &&
        items[targetIndex].endIndex <= currentIndex) {
      targetIndex += 1;
    }
    if (targetIndex >= items.length || targetIndex == oldIndex) return false;

    final moved = items.removeAt(oldIndex);
    items.insert(targetIndex, moved);
    _sequence = _withDisplayOrder(items.expand((item) => item.steps).toList());
    notifyListeners();
    return true;
  }

  @visibleForTesting
  void tickOneSecond() => _handleTick();

  void applyServiceState({
    required int currentStepIndex,
    required int elapsedSeconds,
    required int remainingTime,
    required String status,
    required bool finished,
  }) {
    currentIndex = currentStepIndex
        .clamp(0, _sequence.isEmpty ? 0 : _sequence.length - 1)
        .toInt();
    this.elapsedSeconds = elapsedSeconds;
    this.remainingTime = remainingTime;
    isPaused = status == 'PAUSED';
    isFinished = finished || status == 'COMPLETED' || status == 'CANCELLED';
    if (isFinished) {
      _timer?.cancel();
    }
    notifyListeners();
  }

  void completeLocal() {
    if (isFinished) return;
    isFinished = true;
    _timer?.cancel();
    onWorkoutComplete?.call();
    notifyListeners();
  }

  void _hydrate(WorkoutRunResponse run) {
    _sequence = _applySnapshotOrder(_sequence, run.snapshotJson);
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
    if (!useInternalTimer) return;
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

  List<ExecutableWorkoutStep> _applySnapshotOrder(
    List<ExecutableWorkoutStep> base,
    String? raw,
  ) {
    if (raw == null || raw.isEmpty || base.length < 2) {
      return _withDisplayOrder(base);
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return _withDisplayOrder(base);
      final rawOrder = decoded['sequenceOrder'];
      if (rawOrder is! List || rawOrder.length != base.length) {
        return _withDisplayOrder(base);
      }
      final order = rawOrder.map((item) => item.toString()).toList();
      final byKey = {for (final step in base) step.sequenceKey: step};
      if (order.any((key) => !byKey.containsKey(key))) {
        return _withDisplayOrder(base);
      }
      return _withDisplayOrder(order.map((key) => byKey[key]!).toList());
    } catch (_) {
      return _withDisplayOrder(base);
    }
  }

  bool _hasCompatibleSnapshotOrder(
    List<ExecutableWorkoutStep> base,
    String? raw,
  ) {
    if (raw == null || raw.isEmpty || base.length < 2) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final rawOrder = decoded['sequenceOrder'];
      if (rawOrder is! List || rawOrder.length != base.length) return false;
      final keys = {for (final step in base) step.sequenceKey};
      return rawOrder.every((item) => keys.contains(item.toString()));
    } catch (_) {
      return false;
    }
  }

  bool _hasSameSequenceMembers(
    List<ExecutableWorkoutStep> current,
    List<ExecutableWorkoutStep> flattened,
  ) {
    if (current.length != flattened.length || current.isEmpty) return false;
    final currentKeys = current.map((step) => step.sequenceKey).toSet();
    final flattenedKeys = flattened.map((step) => step.sequenceKey).toSet();
    return currentKeys.length == flattenedKeys.length &&
        currentKeys.containsAll(flattenedKeys);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

List<RunnerSequenceItem> buildRunnerSequenceItems(
  List<ExecutableWorkoutStep> sequence,
) {
  final items = <RunnerSequenceItem>[];
  var index = 0;
  while (index < sequence.length) {
    final step = sequence[index];
    if (step.blockIndex < 0) {
      items.add(
        RunnerSequenceItem(
          key: step.sequenceKey,
          title: step.name,
          subtitle: step.isTimed
              ? '${step.durationSeconds ?? 0} sec'
              : '${step.reps ?? 1} reps',
          steps: [step],
          startIndex: index,
          endIndex: index,
          isGroup: false,
        ),
      );
      index += 1;
      continue;
    }

    final start = index;
    final blockIndex = step.blockIndex;
    final blockTitle = step.blockTitle ?? 'Gruppo';
    while (index < sequence.length &&
        sequence[index].blockIndex == blockIndex &&
        sequence[index].blockTitle == step.blockTitle) {
      index += 1;
    }
    final steps = sequence.sublist(start, index);
    final uniqueNames = <String>[];
    for (final item in steps) {
      if (!uniqueNames.contains(item.name)) uniqueNames.add(item.name);
    }
    items.add(
      RunnerSequenceItem(
        key:
            'group:$blockIndex:${steps.first.sequenceKey}:${steps.last.sequenceKey}',
        title: blockTitle,
        subtitle:
            '${steps.first.totalLaps} giri - ${uniqueNames.take(3).join(', ')}',
        steps: steps,
        startIndex: start,
        endIndex: index - 1,
        isGroup: true,
      ),
    );
  }
  return items;
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
  sequenceKey: '',
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

String _sequenceKey(ExecutableWorkoutStep step, int baseIndex) {
  final origin = step.originStepId ?? step.id;
  return [
    'base:$baseIndex',
    'step:${origin ?? 'new'}',
    'block:${step.blockIndex}',
    'lap:${step.lap}',
    'order:${step.sortOrder}',
    'name:${step.name}',
  ].join('|');
}

List<ExecutableWorkoutStep> _withDisplayOrder(
  List<ExecutableWorkoutStep> steps,
) => steps
    .asMap()
    .entries
    .map((entry) => entry.value.copyWith(sortOrder: entry.key))
    .toList();

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
