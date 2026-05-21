import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/data/models/workout_models.dart';
import 'package:lifeplanner_mobile/features/workout/workout_runner_controller.dart';

void main() {
  test('flattenWorkoutTemplate expands ordered blocks and top-level steps', () {
    const template = WorkoutTemplateResponse(
      id: 1,
      name: 'Test',
      active: true,
      estimatedDurationSeconds: 90,
      exercises: [],
      steps: [
        WorkoutStepDto(
          name: 'Warmup',
          stepType: 'ACTIVE',
          measurementType: 'TIME',
          durationSeconds: 30,
          sortOrder: 0,
        ),
      ],
      blocks: [
        WorkoutBlockDto(
          title: 'Circuit',
          sortOrder: 1,
          repeatCount: 2,
          steps: [
            WorkoutStepDto(
              name: 'Push up',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 10,
              sortOrder: 0,
            ),
            WorkoutStepDto(
              name: 'Rest',
              stepType: 'BREAK',
              measurementType: 'TIME',
              durationSeconds: 20,
              sortOrder: 1,
            ),
          ],
        ),
      ],
    );

    final sequence = flattenWorkoutTemplate(template);

    expect(sequence.map((step) => step.name), [
      'Warmup',
      'Push up',
      'Rest',
      'Push up',
      'Rest',
    ]);
    expect(sequence.last.lap, 2);
    expect(sequence.last.totalLaps, 2);
  });

  test('flattenWorkoutTemplate falls back to legacy exercises', () {
    const template = WorkoutTemplateResponse(
      id: 2,
      name: 'Legacy',
      active: true,
      exercises: [
        WorkoutExerciseDto(id: 10, name: 'Squat', reps: '12', exerciseOrder: 0),
        WorkoutExerciseDto(
          id: 11,
          name: 'Plank',
          reps: '60 sec',
          exerciseOrder: 1,
        ),
      ],
    );

    final sequence = flattenWorkoutTemplate(template);

    expect(sequence.map((step) => step.name), ['Squat', 'Plank']);
    expect(sequence.map((step) => step.measurementType), ['REPS', 'REPS']);
    expect(sequence.map((step) => step.reps), [12, 60]);
  });

  test('runner advances from reps exercise to recovery', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Squat',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 12,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Rest',
            stepType: 'BREAK',
            measurementType: 'TIME',
            durationSeconds: 30,
            sortOrder: 1,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    expect(runner.currentStep?.isTimed, isFalse);
    runner.completeStep();

    expect(runner.currentStep?.name, 'Rest');
    expect(runner.currentStep?.isBreak, isTrue);
    expect(runner.remainingTime, 30);
  });

  test('runner advances from recovery to next exercise when timer ends', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Rest',
            stepType: 'BREAK',
            measurementType: 'TIME',
            durationSeconds: 1,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Push up',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 1,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    runner.tickOneSecond();

    expect(runner.currentStep?.name, 'Push up');
    expect(runner.currentStep?.isTimed, isFalse);
  });

  test('runner completes on the last step', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Plank',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 1,
            sortOrder: 0,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    runner.completeStep();

    expect(runner.isFinished, isTrue);
  });

  test('runner distinguishes reps steps from timed steps', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Lunge',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 8,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Hold',
            stepType: 'ACTIVE',
            measurementType: 'TIME',
            durationSeconds: 2,
            sortOrder: 1,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    runner.tickOneSecond();
    expect(runner.currentStep?.name, 'Lunge');
    expect(runner.remainingTime, 0);

    runner.completeStep();
    expect(runner.currentStep?.name, 'Hold');
    expect(runner.remainingTime, 2);

    runner.tickOneSecond();
    expect(runner.remainingTime, 1);
  });

  test('runner reorders only future steps and keeps current step stable', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Squat',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Bench',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 8,
            sortOrder: 1,
          ),
          const WorkoutStepDto(
            name: 'Row',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 12,
            sortOrder: 2,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    final changed = runner.reorderFutureStep(2, 1);

    expect(changed, isTrue);
    expect(runner.currentStep?.name, 'Squat');
    expect(runner.sequence.map((step) => step.name), ['Squat', 'Row', 'Bench']);
  });

  test('runner blocks completed and current steps from reorder', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Squat',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Bench',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 8,
            sortOrder: 1,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    expect(runner.reorderFutureStep(0, 1), isFalse);
    runner.completeStep();
    expect(runner.reorderFutureStep(0, 1), isFalse);
  });

  test('runner next uses reordered future sequence', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Squat',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Bench',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 8,
            sortOrder: 1,
          ),
          const WorkoutStepDto(
            name: 'Row',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 12,
            sortOrder: 2,
          ),
        ]),
      ),
    );
    addTearDown(runner.dispose);

    runner.reorderFutureStep(2, 1);
    runner.completeStep();

    expect(runner.currentStep?.name, 'Row');
    expect(runner.nextStep?.name, 'Bench');
  });

  test('runner snapshot persists and hydrates custom sequence order', () {
    final template = _template([
      const WorkoutStepDto(
        id: 1,
        name: 'Squat',
        stepType: 'ACTIVE',
        measurementType: 'REPS',
        reps: 10,
        sortOrder: 0,
      ),
      const WorkoutStepDto(
        id: 2,
        name: 'Bench',
        stepType: 'ACTIVE',
        measurementType: 'REPS',
        reps: 8,
        sortOrder: 1,
      ),
      const WorkoutStepDto(
        id: 3,
        name: 'Row',
        stepType: 'ACTIVE',
        measurementType: 'REPS',
        reps: 12,
        sortOrder: 2,
      ),
    ]);
    final runner = WorkoutRunnerController(run: _runFor(template));
    addTearDown(runner.dispose);

    runner.reorderFutureStep(2, 1);
    final snapshotJson = runner.snapshot()['snapshotJson'] as String;
    final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
    final hydrated = WorkoutRunnerController(
      run: _runFor(template, snapshotJson: snapshotJson),
    );
    addTearDown(hydrated.dispose);

    expect(snapshot['sequenceOrder'], isA<List<dynamic>>());
    expect(hydrated.sequence.map((step) => step.name), [
      'Squat',
      'Row',
      'Bench',
    ]);
  });

  test('runner grouped reorder survives snapshot hydration', () {
    final template = WorkoutTemplateResponse(
      id: 44,
      name: 'Grouped hydrate',
      active: true,
      exercises: const [],
      steps: const [
        WorkoutStepDto(
          id: 1,
          name: 'Warmup',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 10,
          sortOrder: 0,
        ),
        WorkoutStepDto(
          id: 2,
          name: 'Finisher',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 12,
          sortOrder: 2,
        ),
      ],
      blocks: const [
        WorkoutBlockDto(
          title: 'Legs',
          sortOrder: 1,
          repeatCount: 1,
          steps: [
            WorkoutStepDto(
              id: 3,
              name: 'Curl',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 10,
              sortOrder: 0,
            ),
          ],
        ),
      ],
    );
    final runner = WorkoutRunnerController(run: _runFor(template));
    addTearDown(runner.dispose);

    expect(runner.reorderFutureItem(2, 1), isTrue);
    final snapshotJson = runner.snapshot()['snapshotJson'] as String;
    final hydrated = WorkoutRunnerController(
      run: _runFor(template, snapshotJson: snapshotJson),
    );
    addTearDown(hydrated.dispose);

    expect(hydrated.currentStep?.name, 'Warmup');
    expect(hydrated.sequence.map((step) => step.name), [
      'Warmup',
      'Finisher',
      'Curl',
    ]);
  });

  test(
    'server hydrate without sequence order keeps local reordered sequence',
    () {
      final template = _template([
        const WorkoutStepDto(
          id: 1,
          name: 'Squat',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 10,
          sortOrder: 0,
        ),
        const WorkoutStepDto(
          id: 2,
          name: 'Bench',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 8,
          sortOrder: 1,
        ),
        const WorkoutStepDto(
          id: 3,
          name: 'Row',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 12,
          sortOrder: 2,
        ),
      ]);
      final runner = WorkoutRunnerController(run: _runFor(template));
      addTearDown(runner.dispose);

      runner.reorderFutureStep(2, 1);
      runner.hydrateFromServer(_runFor(template));

      expect(runner.currentStep?.name, 'Squat');
      expect(runner.sequence.map((step) => step.name), [
        'Squat',
        'Row',
        'Bench',
      ]);
    },
  );

  test('timed completion callback fires for each timed step', () {
    final completed = <String>[];
    final runner = WorkoutRunnerController(
      run: _runFor(
        _template([
          const WorkoutStepDto(
            name: 'Rest one',
            stepType: 'BREAK',
            measurementType: 'TIME',
            durationSeconds: 1,
            sortOrder: 0,
          ),
          const WorkoutStepDto(
            name: 'Rest two',
            stepType: 'BREAK',
            measurementType: 'TIME',
            durationSeconds: 1,
            sortOrder: 1,
          ),
          const WorkoutStepDto(
            name: 'Hold',
            stepType: 'ACTIVE',
            measurementType: 'TIME',
            durationSeconds: 1,
            sortOrder: 2,
          ),
        ]),
      ),
      onTimedStepComplete: (step) => completed.add(step.name),
    );
    addTearDown(runner.dispose);

    runner.tickOneSecond();
    runner.tickOneSecond();
    runner.tickOneSecond();

    expect(completed, ['Rest one', 'Rest two', 'Hold']);
  });

  test('builds grouped runner items from flattened sequence', () {
    final sequence = flattenWorkoutTemplate(_groupTemplate());
    final items = buildRunnerSequenceItems(sequence);

    expect(items.map((item) => item.title), ['Warmup', 'Legs']);
    expect(items.first.isSingleStep, isTrue);
    expect(items.last.isGroup, isTrue);
    expect(items.last.steps.map((step) => step.name), [
      'Curl',
      'Rest',
      'Press',
      'Curl',
      'Rest',
      'Press',
    ]);
  });

  test('runner reorders future group as one unit', () {
    final runner = WorkoutRunnerController(run: _runFor(_groupTemplate()));
    addTearDown(runner.dispose);

    runner.reorderFutureItem(1, 0);

    expect(runner.currentStep?.name, 'Warmup');
    expect(runner.sequence.map((step) => step.name), [
      'Warmup',
      'Curl',
      'Rest',
      'Press',
      'Curl',
      'Rest',
      'Press',
    ]);
  });

  test('runner next follows reordered grouped order', () {
    final runner = WorkoutRunnerController(
      run: _runFor(
        WorkoutTemplateResponse(
          id: 43,
          name: 'Grouped',
          active: true,
          exercises: const [],
          steps: const [
            WorkoutStepDto(
              name: 'Warmup',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 10,
              sortOrder: 0,
            ),
            WorkoutStepDto(
              name: 'Finisher',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 12,
              sortOrder: 2,
            ),
          ],
          blocks: const [
            WorkoutBlockDto(
              title: 'Legs',
              sortOrder: 1,
              repeatCount: 1,
              steps: [
                WorkoutStepDto(
                  name: 'Curl',
                  stepType: 'ACTIVE',
                  measurementType: 'REPS',
                  reps: 10,
                  sortOrder: 0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
    addTearDown(runner.dispose);

    runner.reorderFutureItem(2, 1);
    runner.completeStep();

    expect(runner.currentStep?.name, 'Finisher');
    expect(runner.nextStep?.name, 'Curl');
  });
}

WorkoutTemplateResponse _template(List<WorkoutStepDto> steps) {
  return WorkoutTemplateResponse(
    id: 42,
    name: 'Runner test',
    active: true,
    exercises: const [],
    steps: steps,
  );
}

WorkoutTemplateResponse _groupTemplate() {
  return const WorkoutTemplateResponse(
    id: 43,
    name: 'Grouped',
    active: true,
    exercises: [],
    steps: [
      WorkoutStepDto(
        name: 'Warmup',
        stepType: 'ACTIVE',
        measurementType: 'REPS',
        reps: 10,
        sortOrder: 0,
      ),
    ],
    blocks: [
      WorkoutBlockDto(
        title: 'Legs',
        sortOrder: 1,
        repeatCount: 2,
        steps: [
          WorkoutStepDto(
            name: 'Curl',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 0,
          ),
          WorkoutStepDto(
            name: 'Rest',
            stepType: 'BREAK',
            measurementType: 'TIME',
            durationSeconds: 30,
            sortOrder: 1,
          ),
          WorkoutStepDto(
            name: 'Press',
            stepType: 'ACTIVE',
            measurementType: 'REPS',
            reps: 10,
            sortOrder: 2,
          ),
        ],
      ),
    ],
  );
}

WorkoutRunResponse _runFor(
  WorkoutTemplateResponse template, {
  String? snapshotJson,
}) {
  final steps = flattenWorkoutTemplate(template);
  return WorkoutRunResponse(
    id: 7,
    templateId: template.id,
    status: 'IN_PROGRESS',
    elapsedSeconds: 0,
    currentStepIndex: 0,
    currentBlockIndex: 0,
    currentLap: 1,
    totalSteps: steps.length,
    remainingSteps: steps.length,
    snapshotJson: snapshotJson,
    template: template,
    createdAt: '2026-01-01T00:00:00',
    updatedAt: '2026-01-01T00:00:00',
  );
}
