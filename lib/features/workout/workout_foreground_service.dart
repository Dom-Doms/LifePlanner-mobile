import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'workout_runner_controller.dart';

class WorkoutServiceStep {
  const WorkoutServiceStep({
    required this.sequenceKey,
    required this.name,
    required this.stepType,
    required this.measurementType,
    required this.sortOrder,
    required this.blockIndex,
    required this.lap,
    required this.totalLaps,
    this.id,
    this.durationSeconds,
    this.reps,
    this.blockTitle,
  });

  factory WorkoutServiceStep.fromRunnerStep(ExecutableWorkoutStep step) =>
      WorkoutServiceStep(
        sequenceKey: step.sequenceKey,
        id: step.id,
        name: step.name,
        stepType: step.stepType,
        measurementType: step.measurementType,
        durationSeconds: step.durationSeconds,
        reps: step.reps,
        sortOrder: step.sortOrder,
        blockTitle: step.blockTitle,
        blockIndex: step.blockIndex,
        lap: step.lap,
        totalLaps: step.totalLaps,
      );

  final String sequenceKey;
  final int? id;
  final String name;
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

  Map<String, dynamic> toJson() => {
    'sequenceKey': sequenceKey,
    'id': id,
    'name': name,
    'stepType': stepType,
    'measurementType': measurementType,
    'durationSeconds': durationSeconds,
    'reps': reps,
    'sortOrder': sortOrder,
    'blockTitle': blockTitle,
    'blockIndex': blockIndex,
    'lap': lap,
    'totalLaps': totalLaps,
  }..removeWhere((_, value) => value == null);
}

class WorkoutServicePayload {
  const WorkoutServicePayload({
    required this.runId,
    required this.currentStepIndex,
    required this.elapsedSeconds,
    required this.remainingTime,
    required this.status,
    required this.sequence,
  });

  factory WorkoutServicePayload.fromRunner({
    required int runId,
    required WorkoutRunnerController runner,
  }) => WorkoutServicePayload(
    runId: runId,
    currentStepIndex: runner.currentIndex,
    elapsedSeconds: runner.elapsedSeconds,
    remainingTime: runner.remainingTime,
    status: runner.isPaused ? 'PAUSED' : 'IN_PROGRESS',
    sequence: runner.sequence.map(WorkoutServiceStep.fromRunnerStep).toList(),
  );

  final int runId;
  final int currentStepIndex;
  final int elapsedSeconds;
  final int remainingTime;
  final String status;
  final List<WorkoutServiceStep> sequence;

  Map<String, dynamic> toJson() => {
    'runId': runId,
    'currentStepIndex': currentStepIndex,
    'elapsedSeconds': elapsedSeconds,
    'remainingTime': remainingTime,
    'status': status,
    'sequence': sequence.map((step) => step.toJson()).toList(),
  };
}

class WorkoutServiceState {
  const WorkoutServiceState({
    required this.runId,
    required this.currentStepIndex,
    required this.elapsedSeconds,
    required this.remainingTime,
    required this.status,
    required this.active,
    required this.finished,
  });

  factory WorkoutServiceState.fromJson(Map<dynamic, dynamic> json) =>
      WorkoutServiceState(
        runId: _readInt(json, 'runId'),
        currentStepIndex: _readInt(json, 'currentStepIndex'),
        elapsedSeconds: _readInt(json, 'elapsedSeconds'),
        remainingTime: _readInt(json, 'remainingTime'),
        status: json['status']?.toString() ?? 'IN_PROGRESS',
        active: json['active'] == true,
        finished: json['finished'] == true,
      );

  final int runId;
  final int currentStepIndex;
  final int elapsedSeconds;
  final int remainingTime;
  final String status;
  final bool active;
  final bool finished;

  bool get paused => status == 'PAUSED';
}

class WorkoutServiceEvent {
  const WorkoutServiceEvent({required this.type, required this.state});

  factory WorkoutServiceEvent.fromJson(Map<dynamic, dynamic> json) =>
      WorkoutServiceEvent(
        type: json['type']?.toString() ?? 'stateChanged',
        state: WorkoutServiceState.fromJson(
          (json['state'] as Map?) ?? const <String, dynamic>{},
        ),
      );

  final String type;
  final WorkoutServiceState state;
}

class WorkoutForegroundService {
  WorkoutForegroundService({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('lifeplanner_mobile/workout_foreground_service') {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel _channel;
  final _events = StreamController<WorkoutServiceEvent>.broadcast();

  Stream<WorkoutServiceEvent> get events => _events.stream;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> start(WorkoutServicePayload payload) =>
      _invokeBool('startWorkoutService', payload.toJson());

  Future<bool> update(WorkoutServicePayload payload) =>
      _invokeBool('updateWorkoutService', payload.toJson());

  Future<bool> pause() => _invokeBool('pauseWorkoutService');

  Future<bool> resume() => _invokeBool('resumeWorkoutService');

  Future<bool> completeCurrentStep() =>
      _invokeBool('completeCurrentStepWorkoutService');

  Future<bool> skipCurrentStep() => _invokeBool('skipWorkoutServiceStep');

  Future<bool> previousStep() => _invokeBool('previousWorkoutServiceStep');

  Future<bool> stop() => _invokeBool('stopWorkoutService');

  Future<WorkoutServiceState?> getState() async {
    if (!isSupported) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getWorkoutServiceState',
      );
      return result == null ? null : WorkoutServiceState.fromJson(result);
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> _invokeBool(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'onWorkoutServiceEvent') return;
    final args = call.arguments;
    if (args is Map) {
      _events.add(WorkoutServiceEvent.fromJson(args));
    }
  }

  Future<void> dispose() => _events.close();
}

int _readInt(Map<dynamic, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
