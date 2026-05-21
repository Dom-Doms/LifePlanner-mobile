import 'package:flutter_test/flutter_test.dart';
import 'package:lifeplanner_mobile/data/models/workout_models.dart';
import 'package:lifeplanner_mobile/features/workout/workout_editor_draft.dart';

void main() {
  test(
    'maps backend template to editor draft with ordered steps and blocks',
    () {
      final draft = WorkoutEditorDraft.fromTemplate(
        const WorkoutTemplateResponse(
          id: 10,
          name: 'Upper',
          description: 'Strength day',
          active: true,
          exercises: [],
          steps: [
            WorkoutStepDto(
              name: 'Cooldown',
              stepType: 'BREAK',
              measurementType: 'TIME',
              durationSeconds: 45,
              sortOrder: 2,
            ),
          ],
          blocks: [
            WorkoutBlockDto(
              title: 'Circuit',
              sortOrder: 0,
              repeatCount: 3,
              steps: [
                WorkoutStepDto(
                  name: 'Push up',
                  stepType: 'ACTIVE',
                  measurementType: 'REPS',
                  reps: 12,
                  sortOrder: 1,
                ),
                WorkoutStepDto(
                  name: 'Squat',
                  stepType: 'ACTIVE',
                  measurementType: 'REPS',
                  reps: 10,
                  sortOrder: 0,
                ),
              ],
            ),
          ],
        ),
      );

      expect(draft.name, 'Upper');
      expect(draft.description, 'Strength day');
      expect(
        draft.orderedItems().map(
          (item) => item.block?.title ?? item.step?.name,
        ),
        ['Circuit', 'Cooldown'],
      );
      expect(draft.blocks.single.steps.map((step) => step.name), [
        'Squat',
        'Push up',
      ]);
    },
  );

  test('maps draft to backend save payload preserving structure order', () {
    final draft = WorkoutEditorDraft(
      name: 'Leg day',
      description: 'Heavy',
      legacyExercises: const [],
      topSteps: const [
        WorkoutStepDto(
          name: 'Finisher',
          stepType: 'ACTIVE',
          measurementType: 'TIME',
          durationSeconds: 60,
          sortOrder: 2,
        ),
      ],
      blocks: const [
        WorkoutBlockDto(
          title: 'Main',
          sortOrder: 0,
          repeatCount: 2,
          steps: [
            WorkoutStepDto(
              name: 'Squat',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 8,
              sortOrder: 1,
            ),
            WorkoutStepDto(
              name: 'Rest',
              stepType: 'BREAK',
              measurementType: 'TIME',
              durationSeconds: 30,
              sortOrder: 0,
            ),
          ],
        ),
      ],
    );

    final payload = draft.toRequestPayload();
    final blocks = payload['blocks'] as List<dynamic>;
    final topSteps = payload['steps'] as List<dynamic>;
    final block = blocks.single as Map<String, dynamic>;
    final blockSteps = block['steps'] as List<dynamic>;

    expect(payload['name'], 'Leg day');
    expect(payload['estimatedDurationSeconds'], 200);
    expect(block['sortOrder'], 0);
    expect(topSteps.single['sortOrder'], 1);
    expect(blockSteps.map((item) => item['name']), ['Rest', 'Squat']);
    expect(blockSteps.map((item) => item['sortOrder']), [0, 1]);
  });

  test('adds exercise to visible top-level structure', () {
    final draft = WorkoutEditorDraft.empty()..name = 'Draft';

    draft.addTopStep(
      const WorkoutStepDto(
        name: 'Lunge',
        stepType: 'ACTIVE',
        measurementType: 'REPS',
        reps: 10,
        sortOrder: 0,
      ),
    );

    expect(draft.orderedItems().single.step?.name, 'Lunge');
    expect(draft.toRequestPayload()['steps'], isNotEmpty);
  });

  test('adds recovery to visible top-level structure', () {
    final draft = WorkoutEditorDraft.empty()..name = 'Draft';

    draft.addTopStep(
      const WorkoutStepDto(
        name: 'Recupero',
        stepType: 'BREAK',
        measurementType: 'TIME',
        durationSeconds: 30,
        sortOrder: 0,
      ),
    );

    final payloadStep =
        (draft.toRequestPayload()['steps'] as List<dynamic>).single
            as Map<String, dynamic>;
    expect(payloadStep['stepType'], 'BREAK');
    expect(payloadStep['durationSeconds'], 30);
  });

  test('preserves top-level order after moving steps and groups', () {
    final draft = WorkoutEditorDraft.empty()
      ..name = 'Draft'
      ..addTopStep(
        const WorkoutStepDto(
          name: 'Warmup',
          stepType: 'ACTIVE',
          measurementType: 'TIME',
          durationSeconds: 20,
          sortOrder: 0,
        ),
      )
      ..addBlock(
        const WorkoutBlockDto(
          title: 'Circuit',
          sortOrder: 1,
          repeatCount: 2,
          steps: [],
        ),
      );

    draft.moveTopLevelItem(1, -1);

    expect(
      draft.orderedItems().map((item) => item.block?.title ?? item.step?.name),
      ['Circuit', 'Warmup'],
    );
    final payload = draft.toRequestPayload();
    expect((payload['blocks'] as List<dynamic>).single['sortOrder'], 0);
    expect((payload['steps'] as List<dynamic>).single['sortOrder'], 1);
  });

  test('reorders top-level items by drag indexes', () {
    final draft = WorkoutEditorDraft.empty()
      ..name = 'Draft'
      ..addTopStep(
        const WorkoutStepDto(
          name: 'Warmup',
          stepType: 'ACTIVE',
          measurementType: 'TIME',
          durationSeconds: 20,
          sortOrder: 0,
        ),
      )
      ..addTopStep(
        const WorkoutStepDto(
          name: 'Rest',
          stepType: 'BREAK',
          measurementType: 'TIME',
          durationSeconds: 30,
          sortOrder: 1,
        ),
      )
      ..addBlock(
        const WorkoutBlockDto(
          title: 'Circuit',
          sortOrder: 2,
          repeatCount: 2,
          steps: [],
        ),
      );

    draft.reorderTopLevelItem(2, 0);

    expect(
      draft.orderedItems().map((item) => item.block?.title ?? item.step?.name),
      ['Circuit', 'Warmup', 'Rest'],
    );
  });

  test('reorders top-level group and keeps save payload valid', () {
    final draft = WorkoutEditorDraft(
      name: 'Mixed',
      description: '',
      legacyExercises: const [],
      topSteps: const [
        WorkoutStepDto(
          id: 10,
          blockId: 99,
          name: 'Warmup',
          stepType: 'ACTIVE',
          measurementType: 'TIME',
          durationSeconds: 20,
          sortOrder: 0,
        ),
        WorkoutStepDto(
          id: 11,
          name: 'Finisher',
          stepType: 'ACTIVE',
          measurementType: 'REPS',
          reps: 12,
          sortOrder: 2,
        ),
      ],
      blocks: const [
        WorkoutBlockDto(
          id: 20,
          title: 'Circuit',
          sortOrder: 1,
          repeatCount: 3,
          color: 'blue',
          collapsed: true,
          steps: [
            WorkoutStepDto(
              id: 21,
              blockId: 20,
              name: 'Push up',
              stepType: 'ACTIVE',
              measurementType: 'REPS',
              reps: 10,
              sortOrder: 1,
            ),
            WorkoutStepDto(
              id: 22,
              blockId: 20,
              name: 'Rest',
              stepType: 'BREAK',
              measurementType: 'TIME',
              durationSeconds: 30,
              sortOrder: 0,
            ),
          ],
        ),
      ],
    );

    draft.reorderTopLevelItem(1, 0);
    final payload = draft.toRequestPayload();
    final blocks = (payload['blocks'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final steps = (payload['steps'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final block = blocks.single;
    final blockSteps = (block['steps'] as List<dynamic>)
        .cast<Map<String, dynamic>>();

    expect(block['sortOrder'], 0);
    expect(block['repeatCount'], 3);
    expect(block['color'], 'blue');
    expect(block['collapsed'], isTrue);
    expect(steps.map((step) => step['sortOrder']), [1, 2]);
    expect(steps.any((step) => step.containsKey('blockId')), isFalse);
    expect(blockSteps.map((step) => step['name']), ['Rest', 'Push up']);
    expect(blockSteps.map((step) => step['sortOrder']), [0, 1]);
    expect(blockSteps.any((step) => step.containsKey('blockId')), isFalse);
  });

  test('reorders steps inside a group by drag indexes', () {
    const block = WorkoutBlockDto(
      title: 'Circuit',
      sortOrder: 0,
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
          durationSeconds: 30,
          sortOrder: 1,
        ),
      ],
    );
    final draft = WorkoutEditorDraft(
      name: 'Draft',
      description: '',
      topSteps: const [],
      blocks: const [block],
      legacyExercises: const [],
    );

    draft.reorderBlockStep(draft.blocks.single, 1, 0);

    expect(draft.blocks.single.steps.map((step) => step.name), [
      'Rest',
      'Push up',
    ]);
    final payloadSteps =
        ((draft.toRequestPayload()['blocks'] as List<dynamic>).single['steps']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(payloadSteps.map((step) => step['sortOrder']), [0, 1]);
  });

  test(
    'edit load with invalid backend payload fails instead of emptying draft',
    () {
      expect(
        () => WorkoutEditorDraft.fromTemplate(
          const WorkoutTemplateResponse(
            id: 0,
            name: '',
            active: true,
            exercises: [],
          ),
        ),
        throwsA(isA<WorkoutEditorException>()),
      );
      expect(
        () => WorkoutEditorDraft.empty().toRequestPayload(),
        throwsA(isA<WorkoutEditorValidationException>()),
      );
    },
  );
}
