import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/auth_models.dart';
import '../../data/models/json_helpers.dart';
import '../../data/models/workout_models.dart';
import '../../shared/widgets/app_cards.dart';
import 'workout_runner_controller.dart';

class WorkoutsListScreen extends StatefulWidget {
  const WorkoutsListScreen({super.key});

  @override
  State<WorkoutsListScreen> createState() => _WorkoutsListScreenState();
}

class _WorkoutsListScreenState extends State<WorkoutsListScreen> {
  final _search = TextEditingController();
  bool _loading = true;
  String? _error;
  List<WorkoutTemplateResponse> _templates = [];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Carico le schede');
    final visible = _filteredTemplates();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Allenamenti',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filled(
                onPressed: _openNewTemplate,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Cerca scheda',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const EmptyState(
              title: 'Nessuna scheda',
              subtitle: 'Crea una scheda workout o modifica la ricerca.',
            )
          else
            ...visible.map(_templateCard),
        ],
      ),
    );
  }

  Widget _templateCard(WorkoutTemplateResponse template) {
    final sequence = flattenWorkoutTemplate(template);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.fitness_center),
          title: Text(template.name),
          subtitle: Text(
            [
              dates.compactDuration(template.estimatedDurationSeconds),
              '${sequence.length} step',
              if (template.updatedAt != null)
                'Agg. ${template.updatedAt!.take(10)}',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkoutDetailScreen(templateId: template.id),
              ),
            );
            await _load();
          },
        ),
      ),
    );
  }

  List<WorkoutTemplateResponse> _filteredTemplates() {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _templates;
    return _templates.where((template) {
      final content = [
        template.name,
        template.description ?? '',
        ...template.exercises.map((item) => item.name),
        ...template.steps.map((item) => item.name),
        ...template.blocks.expand(
          (block) => [block.title, ...block.steps.map((step) => step.name)],
        ),
      ].join(' ').toLowerCase();
      return content.contains(query);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await AppScope.of(
        context,
      ).workoutApi.getWorkoutTemplates();
      setState(() => _templates = templates);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNewTemplate() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WorkoutEditorScreen()));
    await _load();
  }
}

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    required this.templateId,
    this.workoutSessionId,
    this.eventDate,
    super.key,
  });

  final int templateId;
  final int? workoutSessionId;
  final String? eventDate;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _loading = true;
  bool _starting = false;
  String? _error;
  WorkoutTemplateResponse? _template;
  final _shareSearch = TextEditingController();
  List<UserResponse> _shareResults = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shareSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final template = _template;
    return Scaffold(
      appBar: AppBar(
        title: Text(template?.name ?? 'Scheda workout'),
        actions: [
          if (template != null)
            IconButton(onPressed: _edit, icon: const Icon(Icons.edit)),
          if (template != null)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const LoadingView(label: 'Carico la scheda')
          : template == null
          ? ErrorPanel(message: _error ?? 'Scheda non trovata', onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  if (_error != null)
                    ErrorPanel(message: _error!, onRetry: _load),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (template.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Text(template.description!),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                dates.compactDuration(
                                  template.estimatedDurationSeconds,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${flattenWorkoutTemplate(template).length} step',
                              ),
                            ),
                            Chip(
                              label: Text('${template.blocks.length} gruppi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _starting ? null : _startRun,
                    icon: _starting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('START'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sequenza',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...flattenWorkoutTemplate(template).map(_stepTile),
                  const SizedBox(height: 16),
                  _ShareCard(
                    searchController: _shareSearch,
                    results: _shareResults,
                    onSearch: _searchUsers,
                    onShare: _shareWithUser,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _stepTile(ExecutableWorkoutStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          children: [
            CircleAvatar(child: Text('${step.sortOrder + 1}')),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    [
                      step.isBreak ? 'Recupero' : 'Esercizio',
                      step.measurementType == 'TIME'
                          ? dates.compactDuration(step.durationSeconds)
                          : '${step.reps ?? 1} reps',
                      if (step.blockTitle != null)
                        '${step.blockTitle} ${step.lap}/${step.totalLaps}',
                    ].join(' · '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final template = await AppScope.of(
        context,
      ).workoutApi.getWorkoutTemplate(widget.templateId);
      setState(() => _template = template);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startRun() async {
    setState(() => _starting = true);
    try {
      final run = await AppScope.of(context).workoutApi.startWorkoutRun(
        templateId: widget.templateId,
        workoutSessionId: widget.workoutSessionId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WorkoutRunScreen(runId: run.id, eventDate: widget.eventDate),
        ),
      );
      await _load();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutEditorScreen(templateId: widget.templateId),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final workoutApi = AppScope.of(context).workoutApi;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare la scheda?'),
        content: const Text('L\'azione usa l\'endpoint di delete del backend.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await workoutApi.deleteWorkoutTemplate(widget.templateId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _searchUsers() async {
    final usersApi = AppScope.of(context).usersApi;
    final users = await usersApi.searchUsers(_shareSearch.text);
    setState(() => _shareResults = users);
  }

  Future<void> _shareWithUser(UserResponse user) async {
    final workoutApi = AppScope.of(context).workoutApi;
    await workoutApi.shareWorkoutTemplate(
      id: widget.templateId,
      targetUserId: user.id,
    );
    if (mounted) {
      showSnack(context, 'Scheda condivisa con ${user.displayLabel}');
    }
    setState(() {
      _shareResults = [];
      _shareSearch.clear();
    });
  }
}

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen({this.templateId, super.key});

  final int? templateId;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<WorkoutStepDto> _topSteps = [];
  List<WorkoutBlockDto> _blocks = [];
  List<WorkoutExerciseDto> _legacyExercises = [];

  bool get _editing => widget.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifica scheda' : 'Nuova scheda'),
      ),
      body: _loading
          ? const LoadingView(label: 'Carico editor')
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome scheda'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Descrizione'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorPanel(message: _error!),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Struttura',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: _addItem,
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'exercise',
                          child: Text('Esercizio'),
                        ),
                        PopupMenuItem(
                          value: 'recovery',
                          child: Text('Recupero'),
                        ),
                        PopupMenuItem(value: 'block', child: Text('Gruppo')),
                      ],
                    ),
                  ],
                ),
                ..._orderedEditorItems().asMap().entries.map(
                  (entry) => _editorItem(entry.value, entry.key),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Salva scheda'),
                ),
              ],
            ),
    );
  }

  Widget _editorItem(_EditableWorkoutItem item, int position) {
    if (item.step != null) {
      final step = item.step!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              step.stepType == 'BREAK' ? Icons.timer : Icons.fitness_center,
            ),
            title: Text(step.name),
            subtitle: Text(_stepMeta(step)),
            trailing: Wrap(
              children: [
                IconButton(
                  onPressed: () => _moveItem(position, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: () => _moveItem(position, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  onPressed: () => _editTopStep(step),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () => _removeTopStep(step),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final block = item.block!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${block.title} · ${block.repeatCount} giri',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => _moveItem(position, -1),
                  icon: const Icon(Icons.arrow_upward),
                ),
                IconButton(
                  onPressed: () => _moveItem(position, 1),
                  icon: const Icon(Icons.arrow_downward),
                ),
                IconButton(
                  onPressed: () => _editBlock(block),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () => _removeBlock(block),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            ...block.steps.asMap().entries.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value.name),
                subtitle: Text(_stepMeta(entry.value)),
                trailing: Wrap(
                  children: [
                    IconButton(
                      onPressed: () => _editBlockStep(block, entry.value),
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      onPressed: () => _removeBlockStep(block, entry.value),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addBlockStep(block),
              icon: const Icon(Icons.add),
              label: const Text('Step nel gruppo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final template = await AppScope.of(
        context,
      ).workoutApi.getWorkoutTemplate(widget.templateId!);
      setState(() {
        _name.text = template.name;
        _description.text = template.description ?? '';
        _topSteps = [...template.steps];
        _blocks = [...template.blocks];
        _legacyExercises = [...template.exercises];
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_EditableWorkoutItem> _orderedEditorItems() {
    final items = [
      ..._topSteps.map(_EditableWorkoutItem.step),
      ..._blocks.map(_EditableWorkoutItem.block),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<void> _addItem(String type) async {
    if (type == 'block') {
      final block = await _blockDialog();
      if (block == null) return;
      setState(
        () => _blocks.add(
          block.copyWith(sortOrder: _orderedEditorItems().length),
        ),
      );
      _normalizeSortOrder();
      return;
    }
    final step = await _stepDialog(
      initialType: type == 'recovery' ? 'BREAK' : 'ACTIVE',
    );
    if (step == null) return;
    setState(
      () =>
          _topSteps.add(step.copyWith(sortOrder: _orderedEditorItems().length)),
    );
    _normalizeSortOrder();
  }

  Future<void> _editTopStep(WorkoutStepDto step) async {
    final updated = await _stepDialog(initial: step);
    if (updated == null) return;
    setState(() {
      final index = _topSteps.indexOf(step);
      _topSteps[index] = updated.copyWith(sortOrder: step.sortOrder);
    });
  }

  Future<void> _addBlockStep(WorkoutBlockDto block) async {
    final step = await _stepDialog();
    if (step == null) return;
    final steps = [
      ...block.steps,
      step.copyWith(sortOrder: block.steps.length),
    ];
    _replaceBlock(block, block.copyWith(steps: steps));
  }

  Future<void> _editBlockStep(
    WorkoutBlockDto block,
    WorkoutStepDto step,
  ) async {
    final updated = await _stepDialog(initial: step);
    if (updated == null) return;
    final steps = [...block.steps];
    final index = steps.indexOf(step);
    steps[index] = updated.copyWith(sortOrder: step.sortOrder);
    _replaceBlock(block, block.copyWith(steps: steps));
  }

  Future<void> _editBlock(WorkoutBlockDto block) async {
    final updated = await _blockDialog(initial: block);
    if (updated == null) return;
    _replaceBlock(
      block,
      updated.copyWith(sortOrder: block.sortOrder, steps: block.steps),
    );
  }

  void _removeTopStep(WorkoutStepDto step) {
    setState(() => _topSteps.remove(step));
    _normalizeSortOrder();
  }

  void _removeBlock(WorkoutBlockDto block) {
    setState(() => _blocks.remove(block));
    _normalizeSortOrder();
  }

  void _removeBlockStep(WorkoutBlockDto block, WorkoutStepDto step) {
    final steps = [...block.steps]..remove(step);
    _replaceBlock(block, block.copyWith(steps: _normalizeSteps(steps)));
  }

  void _replaceBlock(WorkoutBlockDto oldBlock, WorkoutBlockDto newBlock) {
    setState(() {
      final index = _blocks.indexOf(oldBlock);
      _blocks[index] = newBlock;
    });
  }

  void _moveItem(int position, int delta) {
    final items = _orderedEditorItems();
    final newPosition = (position + delta).clamp(0, items.length - 1).toInt();
    if (newPosition == position) return;
    final moved = items.removeAt(position);
    items.insert(newPosition, moved);
    setState(() {
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        if (item.step != null) {
          final stepIndex = _topSteps.indexOf(item.step!);
          _topSteps[stepIndex] = item.step!.copyWith(sortOrder: index);
        } else {
          final blockIndex = _blocks.indexOf(item.block!);
          _blocks[blockIndex] = item.block!.copyWith(sortOrder: index);
        }
      }
    });
  }

  void _normalizeSortOrder() {
    final items = _orderedEditorItems();
    setState(() {
      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];
        if (item.step != null) {
          final stepIndex = _topSteps.indexOf(item.step!);
          _topSteps[stepIndex] = item.step!.copyWith(sortOrder: index);
        } else {
          final blockIndex = _blocks.indexOf(item.block!);
          _blocks[blockIndex] = item.block!.copyWith(sortOrder: index);
        }
      }
    });
  }

  List<WorkoutStepDto> _normalizeSteps(List<WorkoutStepDto> steps) {
    return steps
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(sortOrder: entry.key))
        .toList();
  }

  Future<WorkoutStepDto?> _stepDialog({
    WorkoutStepDto? initial,
    String initialType = 'ACTIVE',
  }) async {
    final name = TextEditingController(text: initial?.name ?? '');
    final description = TextEditingController(text: initial?.description ?? '');
    final amount = TextEditingController(
      text: initial?.measurementType == 'TIME'
          ? '${initial?.durationSeconds ?? ''}'
          : '${initial?.reps ?? ''}',
    );
    var stepType = initial?.stepType ?? initialType;
    var measurementType =
        initial?.measurementType ?? (stepType == 'BREAK' ? 'TIME' : 'REPS');
    final result = await showDialog<WorkoutStepDto>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Step'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: stepType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Esercizio')),
                    DropdownMenuItem(value: 'BREAK', child: Text('Recupero')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    stepType = value ?? stepType;
                    if (stepType == 'BREAK') measurementType = 'TIME';
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: measurementType,
                  decoration: const InputDecoration(labelText: 'Misura'),
                  items: const [
                    DropdownMenuItem(value: 'REPS', child: Text('Ripetizioni')),
                    DropdownMenuItem(value: 'TIME', child: Text('Tempo')),
                  ],
                  onChanged: stepType == 'BREAK'
                      ? null
                      : (value) => setDialogState(
                          () => measurementType = value ?? measurementType,
                        ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: measurementType == 'TIME'
                        ? 'Secondi'
                        : 'Ripetizioni',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Note'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                WorkoutStepDto(
                  id: initial?.id,
                  blockId: initial?.blockId,
                  name: name.text.trim(),
                  description: description.text.trim(),
                  stepType: stepType,
                  measurementType: measurementType,
                  durationSeconds: measurementType == 'TIME'
                      ? dates.parseOptionalInt(amount.text)
                      : null,
                  reps: measurementType == 'REPS'
                      ? dates.parseOptionalInt(amount.text)
                      : null,
                  sortOrder: initial?.sortOrder ?? 0,
                  active: true,
                ),
              ),
              child: const Text('Ok'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    description.dispose();
    amount.dispose();
    return result;
  }

  Future<WorkoutBlockDto?> _blockDialog({WorkoutBlockDto? initial}) async {
    final title = TextEditingController(text: initial?.title ?? '');
    final repeat = TextEditingController(text: '${initial?.repeatCount ?? 1}');
    final result = await showDialog<WorkoutBlockDto>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repeat,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ripetizioni gruppo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              WorkoutBlockDto(
                id: initial?.id,
                title: title.text.trim(),
                sortOrder: initial?.sortOrder ?? 0,
                repeatCount: dates.parseOptionalInt(repeat.text) ?? 1,
                steps: initial?.steps ?? const [],
              ),
            ),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    title.dispose();
    repeat.dispose();
    return result;
  }

  String _stepMeta(WorkoutStepDto step) => [
    step.stepType == 'BREAK' ? 'Recupero' : 'Esercizio',
    step.measurementType == 'TIME'
        ? dates.compactDuration(step.durationSeconds)
        : '${step.reps ?? 1} reps',
  ].join(' · ');

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      _normalizeSortOrder();
      final payload = withoutNulls({
        'name': _name.text.trim(),
        'description': _description.text.trim(),
        'estimatedDurationSeconds': _estimateDuration(),
        'exercises': _legacyExercises.map((item) => item.toJson()).toList(),
        'steps': _normalizeSteps(
          _topSteps,
        ).map((item) => item.toJson()).toList(),
        'blocks': _blocks
            .map(
              (block) =>
                  block.copyWith(steps: _normalizeSteps(block.steps)).toJson(),
            )
            .toList(),
      });
      if (_editing) {
        await AppScope.of(
          context,
        ).workoutApi.updateWorkoutTemplate(widget.templateId!, payload);
      } else {
        await AppScope.of(context).workoutApi.createWorkoutTemplate(payload);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _estimateDuration() {
    var total = 0;
    for (final step in _topSteps) {
      total += step.durationSeconds ?? 0;
    }
    for (final block in _blocks) {
      final blockDuration = block.steps.fold<int>(
        0,
        (sum, step) => sum + (step.durationSeconds ?? 0),
      );
      total += blockDuration * block.repeatCount;
    }
    return total;
  }
}

class WorkoutRunScreen extends StatefulWidget {
  const WorkoutRunScreen({required this.runId, this.eventDate, super.key});

  final int runId;
  final String? eventDate;

  @override
  State<WorkoutRunScreen> createState() => _WorkoutRunScreenState();
}

class _WorkoutRunScreenState extends State<WorkoutRunScreen> {
  WorkoutRunnerController? _runner;
  Timer? _autosave;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _persistState();
    _runner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runner = _runner;
    return Scaffold(
      appBar: AppBar(title: const Text('Workout run')),
      body: _loading || runner == null
          ? const LoadingView(label: 'Carico runner')
          : AnimatedBuilder(
              animation: runner,
              builder: (context, _) {
                final step = runner.currentStep;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_error != null)
                      ErrorPanel(message: _error!, onRetry: _load),
                    SectionCard(
                      child: Column(
                        children: [
                          Text(
                            step?.name ?? 'Workout completato',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: step?.isTimed == true
                                      ? runner.progress
                                      : null,
                                  strokeWidth: 10,
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      step?.isTimed == true
                                          ? dates.compactDuration(
                                              runner.remainingTime,
                                            )
                                          : '${step?.reps ?? 0} reps',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    Text(
                                      'Totale ${dates.compactDuration(runner.elapsedSeconds)}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (step?.blockTitle != null)
                            Text(
                              '${step!.blockTitle} · giro ${step.lap}/${step.totalLaps}',
                            ),
                          if (runner.nextStep != null)
                            Text('Prossimo: ${runner.nextStep!.name}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _previous,
                          icon: const Icon(Icons.skip_previous),
                          label: const Text('Indietro'),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _togglePause,
                          icon: Icon(
                            runner.isPaused ? Icons.play_arrow : Icons.pause,
                          ),
                          label: Text(runner.isPaused ? 'Riprendi' : 'Pausa'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _completeStep,
                          icon: const Icon(Icons.skip_next),
                          label: Text(
                            step?.isTimed == true ? 'Skip' : 'Completato',
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _busy ? null : _finish,
                          icon: const Icon(Icons.flag),
                          label: const Text('Fine'),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _cancel,
                          icon: const Icon(Icons.close),
                          label: const Text('Annulla'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sequenza',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ...runner.sequence.asMap().entries.map(
                      (entry) => ListTile(
                        selected: entry.key == runner.currentIndex,
                        leading: CircleAvatar(child: Text('${entry.key + 1}')),
                        title: Text(entry.value.name),
                        subtitle: Text(
                          entry.value.isTimed
                              ? dates.compactDuration(
                                  entry.value.durationSeconds,
                                )
                              : '${entry.value.reps ?? 1} reps',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final run = await AppScope.of(
        context,
      ).workoutApi.getWorkoutRun(widget.runId);
      _runner?.dispose();
      _runner = WorkoutRunnerController(
        run: run,
        onTimedStepComplete: _notifyTimedStepComplete,
        onWorkoutComplete: _notifyWorkoutComplete,
      );
      _autosave?.cancel();
      _autosave = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _persistState(),
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePause() async {
    final runner = _runner;
    if (runner == null) return;
    final workoutApi = AppScope.of(context).workoutApi;
    setState(() => _busy = true);
    try {
      final run = runner.isPaused
          ? await workoutApi.resumeWorkoutRun(widget.runId)
          : await workoutApi.pauseWorkoutRun(widget.runId);
      if (runner.isPaused) {
        runner.resume();
      } else {
        runner.pause();
      }
      runner.hydrateFromServer(run);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _previous() async {
    _runner?.previous();
    await _persistState();
  }

  Future<void> _completeStep() async {
    _runner?.completeStep();
    await _persistState();
  }

  Future<void> _finish() async {
    final runner = _runner;
    if (runner == null) return;
    final workoutApi = AppScope.of(context).workoutApi;
    final notifications = AppScope.of(context).notifications;
    runner.completeLocal();
    setState(() => _busy = true);
    try {
      await workoutApi.completeWorkoutRun(
        runId: widget.runId,
        payload: runner.snapshot(status: 'COMPLETED'),
      );
      await notifications.show(
        id: widget.runId * 1000 + 999,
        title: 'Workout completato',
        body: 'Hai completato ${runner.sequence.length} step.',
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final workoutApi = AppScope.of(context).workoutApi;
    await workoutApi.cancelWorkoutRun(widget.runId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _persistState() async {
    final runner = _runner;
    if (runner == null || runner.isFinished) return;
    try {
      await AppScope.of(context).workoutApi.updateWorkoutRunState(
        runId: widget.runId,
        payload: runner.snapshot(
          status: runner.isPaused ? 'PAUSED' : 'IN_PROGRESS',
        ),
      );
    } catch (_) {
      return;
    }
  }

  Future<void> _notifyTimedStepComplete(ExecutableWorkoutStep step) async {
    await AppScope.of(context).notifications.show(
      id: widget.runId * 1000 + step.sortOrder,
      title: step.isBreak ? 'Recupero finito' : 'Esercizio finito',
      body: step.isBreak
          ? 'Riprendi con il prossimo esercizio.'
          : '${step.name} completato.',
    );
  }

  Future<void> _notifyWorkoutComplete() async {
    await AppScope.of(context).notifications.show(
      id: widget.runId * 1000 + 998,
      title: 'Workout completato',
      body: 'Sequenza terminata.',
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({
    required this.searchController,
    required this.results,
    required this.onSearch,
    required this.onShare,
  });

  final TextEditingController searchController;
  final List<UserResponse> results;
  final Future<void> Function() onSearch;
  final Future<void> Function(UserResponse user) onShare;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Condividi scheda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(labelText: 'Cerca utente'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onSearch,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          ...results.map(
            (user) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(user.displayLabel),
              subtitle: Text(user.email),
              trailing: const Icon(Icons.send),
              onTap: () => onShare(user),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableWorkoutItem {
  _EditableWorkoutItem.step(WorkoutStepDto step)
    : this._(step: step, block: null, sortOrder: step.sortOrder);

  _EditableWorkoutItem.block(WorkoutBlockDto block)
    : this._(step: null, block: block, sortOrder: block.sortOrder);

  const _EditableWorkoutItem._({
    required this.step,
    required this.block,
    required this.sortOrder,
  });

  final WorkoutStepDto? step;
  final WorkoutBlockDto? block;
  final int sortOrder;
}

extension on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
