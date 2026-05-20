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
}
