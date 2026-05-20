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

WorkoutRunResponse _runFor(WorkoutTemplateResponse template) {
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
    template: template,
    createdAt: '2026-01-01T00:00:00',
    updatedAt: '2026-01-01T00:00:00',
  );
}
