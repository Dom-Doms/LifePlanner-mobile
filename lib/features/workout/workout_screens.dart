import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/auth_models.dart';
import '../../data/models/workout_models.dart';
import '../../shared/widgets/app_cards.dart';
import 'workout_editor_draft.dart';
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
                builder: (_) => WorkoutDetailScreen(
                  templateId: template.id,
                  initialTemplate: template,
                ),
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
    debugPrint('[workout-list] loading -> loading endpoint=/workout-templates');
    setState(() {
      _loading = true;
      _error = null;
    });
    final deps = AppScope.read(context);
    try {
      await deps.auth.waitUntilReady();
      if (!deps.auth.isAuthenticated) {
        throw ApiException(statusCode: 401, message: 'Sessione non attiva.');
      }
      final templates = await deps.workoutApi.getWorkoutTemplates();
      debugPrint('[workout-list] loading -> loaded count=${templates.length}');
      if (!mounted) return;
      setState(() => _templates = templates);
    } on ApiException catch (error) {
      debugPrint('[workout-list] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[workout-list] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento schede.');
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
    this.initialTemplate,
    super.key,
  });

  final int templateId;
  final int? workoutSessionId;
  final String? eventDate;
  final WorkoutTemplateResponse? initialTemplate;

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
    if (widget.initialTemplate != null) {
      _template = widget.initialTemplate;
      _loading = false;
    }
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    if (widget.templateId <= 0) {
      debugPrint('[workout-detail] invalid templateId=${widget.templateId}');
      setState(() {
        _loading = false;
        _error = 'ID scheda workout non valido.';
        _template = null;
      });
      return;
    }
    debugPrint(
      '[workout-detail] loading -> loading endpoint=/workout-templates/${widget.templateId} id=${widget.templateId}',
    );
    if (_template == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _error = null);
    }
    final deps = AppScope.read(context);
    try {
      await deps.auth.waitUntilReady();
      if (!deps.auth.isAuthenticated) {
        throw ApiException(statusCode: 401, message: 'Sessione non attiva.');
      }
      final template = await deps.workoutApi.getWorkoutTemplate(
        widget.templateId,
      );
      debugPrint('[workout-detail] loading -> loaded id=${template.id}');
      if (!mounted) return;
      setState(() => _template = template);
    } on ApiException catch (error) {
      debugPrint('[workout-detail] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[workout-detail] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento scheda.');
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

enum _WorkoutEditorStatus { loading, loaded, empty, error }

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  var _status = _WorkoutEditorStatus.empty;
  bool _saving = false;
  String? _error;
  WorkoutEditorDraft? _draft;

  bool get _editing => widget.templateId != null;
  bool get _canSave =>
      !_saving &&
      (_status == _WorkoutEditorStatus.loaded ||
          (!_editing && _status == _WorkoutEditorStatus.empty));

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _status = _WorkoutEditorStatus.loading;
      _load();
    } else {
      _draft = WorkoutEditorDraft.empty();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifica scheda' : 'Nuova scheda'),
      ),
      body: _status == _WorkoutEditorStatus.loading
          ? const LoadingView(label: 'Carico editor')
          : _status == _WorkoutEditorStatus.error && _editing && draft == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                ErrorPanel(
                  message: _error ?? 'Impossibile caricare la scheda.',
                  onRetry: _load,
                ),
              ],
            )
          : draft == null
          ? const EmptyState(
              title: 'Editor non disponibile',
              subtitle: 'Riapri la scheda e riprova.',
            )
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
                if (draft.orderedItems().isEmpty) ...[
                  const SizedBox(height: 8),
                  const EmptyState(
                    title: 'Struttura vuota',
                    subtitle: 'Aggiungi esercizi, recuperi o un gruppo.',
                  ),
                ],
                ...draft.orderedItems().asMap().entries.map(
                  (entry) => _editorItem(entry.value, entry.key),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _canSave ? _save : null,
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

  Widget _editorItem(EditableWorkoutItem item, int position) {
    if (item.step != null) {
      final step = item.step!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  step.stepType == 'BREAK' ? Icons.timer : Icons.fitness_center,
                ),
                title: Text(step.name),
                subtitle: Text(_stepMeta(step)),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
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
            ],
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
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.repeat),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 120,
                    maxWidth: 240,
                  ),
                  child: Text(
                    '${block.title} - ${block.repeatCount} giri',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                leading: CircleAvatar(child: Text('${entry.key + 1}')),
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
    final templateId = widget.templateId;
    if (templateId == null || templateId <= 0) {
      debugPrint('[workout-editor] invalid templateId=$templateId');
      setState(() {
        _status = _WorkoutEditorStatus.error;
        _error = 'ID scheda workout non valido.';
        _draft = null;
      });
      return;
    }
    debugPrint(
      '[workout-editor] loading -> loading endpoint=/workout-templates/$templateId id=$templateId',
    );
    setState(() {
      _status = _WorkoutEditorStatus.loading;
      _error = null;
      _draft = null;
    });
    final deps = AppScope.read(context);
    try {
      await deps.auth.waitUntilReady();
      if (!deps.auth.isAuthenticated) {
        throw ApiException(statusCode: 401, message: 'Sessione non attiva.');
      }
      final template = await deps.workoutApi.getWorkoutTemplate(templateId);
      final draft = WorkoutEditorDraft.fromTemplate(template);
      debugPrint('[workout-editor] loading -> loaded id=${template.id}');
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _status = _WorkoutEditorStatus.loaded;
        _error = null;
      });
      _hydrateControllers(draft);
    } on ApiException catch (error) {
      debugPrint('[workout-editor] loading -> error ${error.message}');
      if (!mounted) return;
      setState(() {
        _status = _WorkoutEditorStatus.error;
        _error = error.statusCode == 404
            ? 'Scheda workout non trovata.'
            : error.message;
      });
    } on WorkoutEditorException catch (error) {
      debugPrint('[workout-editor] loading -> error ${error.message}');
      if (!mounted) return;
      setState(() {
        _status = _WorkoutEditorStatus.error;
        _error = error.message;
      });
    } catch (error) {
      debugPrint('[workout-editor] loading -> error $error');
      if (!mounted) return;
      setState(() {
        _status = _WorkoutEditorStatus.error;
        _error = 'Errore caricamento editor.';
      });
    }
  }

  void _hydrateControllers(WorkoutEditorDraft draft) {
    _name.text = draft.name;
    _description.text = draft.description;
  }

  void _syncDraftFields() {
    final draft = _draft;
    if (draft == null) return;
    draft.name = _name.text;
    draft.description = _description.text;
  }

  Future<void> _addItem(String type) async {
    final draft = _draft;
    if (draft == null) return;
    if (type == 'block') {
      final block = await _blockDialog(
        initial: makeWorkoutEditorBlock(sortOrder: draft.orderedItems().length),
      );
      if (!mounted || block == null) return;
      setState(() => draft.addBlock(block));
      return;
    }

    final step = await _stepDialog(
      initial: makeWorkoutEditorStep(
        stepType: type == 'recovery' ? 'BREAK' : 'ACTIVE',
        sortOrder: draft.orderedItems().length,
      ),
    );
    if (!mounted || step == null) return;
    setState(() => draft.addTopStep(step));
  }

  Future<void> _editTopStep(WorkoutStepDto step) async {
    final updated = await _stepDialog(initial: step);
    if (!mounted || updated == null) return;
    setState(() => _draft?.replaceTopStep(step, updated));
  }

  Future<void> _addBlockStep(WorkoutBlockDto block) async {
    final step = await _stepDialog();
    if (!mounted || step == null) return;
    setState(() => _draft?.addBlockStep(block, step));
  }

  Future<void> _editBlockStep(
    WorkoutBlockDto block,
    WorkoutStepDto step,
  ) async {
    final updated = await _stepDialog(initial: step);
    if (!mounted || updated == null) return;
    setState(() => _draft?.replaceBlockStep(block, step, updated));
  }

  Future<void> _editBlock(WorkoutBlockDto block) async {
    final updated = await _blockDialog(initial: block);
    if (!mounted || updated == null) return;
    setState(() => _draft?.replaceBlock(block, updated));
  }

  void _removeTopStep(WorkoutStepDto step) {
    setState(() => _draft?.removeTopStep(step));
  }

  void _removeBlock(WorkoutBlockDto block) {
    setState(() => _draft?.removeBlock(block));
  }

  void _removeBlockStep(WorkoutBlockDto block, WorkoutStepDto step) {
    setState(() => _draft?.removeBlockStep(block, step));
  }

  void _moveItem(int position, int delta) {
    setState(() => _draft?.moveTopLevelItem(position, delta));
  }

  Future<WorkoutStepDto?> _stepDialog({
    WorkoutStepDto? initial,
    String initialType = 'ACTIVE',
  }) {
    return showDialog<WorkoutStepDto>(
      context: context,
      builder: (context) => _WorkoutStepDialog(
        initial:
            initial ??
            makeWorkoutEditorStep(stepType: initialType, sortOrder: 0),
      ),
    );
  }

  Future<WorkoutBlockDto?> _blockDialog({WorkoutBlockDto? initial}) {
    return showDialog<WorkoutBlockDto>(
      context: context,
      builder: (context) => _WorkoutBlockDialog(
        initial: initial ?? makeWorkoutEditorBlock(sortOrder: 0),
      ),
    );
  }

  String _stepMeta(WorkoutStepDto step) => [
    step.stepType == 'BREAK' ? 'Recupero' : 'Esercizio',
    step.measurementType == 'TIME'
        ? dates.compactDuration(step.durationSeconds)
        : '${step.reps ?? 1} reps',
    if (step.description?.trim().isNotEmpty == true) step.description!.trim(),
  ].join(' - ');

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || (_editing && _status != _WorkoutEditorStatus.loaded)) {
      setState(
        () => _error = 'La scheda non e stata caricata: salvataggio bloccato.',
      );
      return;
    }

    _syncDraftFields();
    Map<String, dynamic> payload;
    try {
      payload = draft.toRequestPayload();
    } on WorkoutEditorValidationException catch (error) {
      setState(() => _error = error.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final workoutApi = AppScope.read(context).workoutApi;
    try {
      if (_editing) {
        await workoutApi.updateWorkoutTemplate(widget.templateId!, payload);
      } else {
        await workoutApi.createWorkoutTemplate(payload);
      }
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _WorkoutStepDialog extends StatefulWidget {
  const _WorkoutStepDialog({required this.initial});

  final WorkoutStepDto initial;

  @override
  State<_WorkoutStepDialog> createState() => _WorkoutStepDialogState();
}

class _WorkoutStepDialogState extends State<_WorkoutStepDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _amount;
  late final FocusNode _nameFocus;
  late String _stepType;
  late String _measurementType;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _stepType = initial.stepType == 'BREAK' ? 'BREAK' : 'ACTIVE';
    _measurementType = _stepType == 'BREAK'
        ? 'TIME'
        : initial.measurementType == 'TIME'
        ? 'TIME'
        : 'REPS';
    _name = TextEditingController(text: initial.name);
    _description = TextEditingController(text: initial.description ?? '');
    _amount = TextEditingController(
      text: _measurementType == 'TIME'
          ? '${initial.durationSeconds ?? ''}'
          : '${initial.reps ?? ''}',
    );
    _nameFocus = FocusNode();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amount.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_stepType == 'BREAK' ? 'Recupero' : 'Esercizio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              focusNode: _nameFocus,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _stepType,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('Esercizio')),
                DropdownMenuItem(value: 'BREAK', child: Text('Recupero')),
              ],
              onChanged: (value) {
                setState(() {
                  _stepType = value ?? _stepType;
                  if (_stepType == 'BREAK') {
                    _measurementType = 'TIME';
                    if (_name.text.trim().isEmpty) _name.text = 'Recupero';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _measurementType,
              decoration: const InputDecoration(labelText: 'Misura'),
              items: const [
                DropdownMenuItem(value: 'REPS', child: Text('Ripetizioni')),
                DropdownMenuItem(value: 'TIME', child: Text('Tempo')),
              ],
              onChanged: _stepType == 'BREAK'
                  ? null
                  : (value) =>
                        setState(() => _measurementType = value ?? 'REPS'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _measurementType == 'TIME'
                    ? 'Secondi'
                    : 'Ripetizioni',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Annulla')),
        FilledButton(onPressed: _submit, child: const Text('Ok')),
      ],
    );
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final name = _name.text.trim();
    final amount = dates.parseOptionalInt(_amount.text);
    if (name.isEmpty) {
      setState(() => _error = 'Il nome step e obbligatorio.');
      _nameFocus.requestFocus();
      return;
    }
    if (amount == null || amount <= 0) {
      setState(
        () => _error = _measurementType == 'TIME'
            ? 'La durata deve essere maggiore di zero.'
            : 'Le ripetizioni devono essere maggiori di zero.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      WorkoutStepDto(
        id: widget.initial.id,
        blockId: widget.initial.blockId,
        name: name,
        description: _description.text.trim(),
        stepType: _stepType,
        measurementType: _measurementType,
        durationSeconds: _measurementType == 'TIME' ? amount : null,
        reps: _measurementType == 'REPS' ? amount : null,
        sortOrder: widget.initial.sortOrder,
        color: widget.initial.color,
        intensity: widget.initial.intensity,
        active: true,
      ),
    );
  }
}

class _WorkoutBlockDialog extends StatefulWidget {
  const _WorkoutBlockDialog({required this.initial});

  final WorkoutBlockDto initial;

  @override
  State<_WorkoutBlockDialog> createState() => _WorkoutBlockDialogState();
}

class _WorkoutBlockDialogState extends State<_WorkoutBlockDialog> {
  late final TextEditingController _title;
  late final TextEditingController _repeat;
  late final FocusNode _titleFocus;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _repeat = TextEditingController(text: '${widget.initial.repeatCount}');
    _titleFocus = FocusNode();
  }

  @override
  void dispose() {
    _title.dispose();
    _repeat.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gruppo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            focusNode: _titleFocus,
            decoration: const InputDecoration(labelText: 'Titolo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repeat,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ripetizioni gruppo'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Annulla')),
        FilledButton(onPressed: _submit, child: const Text('Ok')),
      ],
    );
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _submit() {
    final title = _title.text.trim();
    final repeat = dates.parseOptionalInt(_repeat.text) ?? 1;
    if (title.isEmpty) {
      setState(() => _error = 'Il titolo gruppo e obbligatorio.');
      _titleFocus.requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      WorkoutBlockDto(
        id: widget.initial.id,
        title: title,
        sortOrder: widget.initial.sortOrder,
        repeatCount: normalizeRepeatCount(repeat),
        color: widget.initial.color,
        collapsed: widget.initial.collapsed,
        steps: widget.initial.steps,
      ),
    );
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
          ? _loading
                ? const LoadingView(label: 'Carico runner')
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ErrorPanel(
                      message: _error ?? 'Runner non disponibile.',
                      onRetry: _load,
                    ),
                  )
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
                          if (step?.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Text(
                              step!.description!,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 180,
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (step?.isTimed == true)
                                  CircularProgressIndicator(
                                    value: runner.progress,
                                    strokeWidth: 10,
                                  )
                                else
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                        width: 10,
                                      ),
                                    ),
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
                                    if (step?.isTimed == true)
                                      Text(
                                        'Totale ${dates.compactDuration(runner.elapsedSeconds)}',
                                      )
                                    else
                                      const Text('Avanza quando hai finito'),
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
                        if (step?.isTimed == true)
                          FilledButton.icon(
                            onPressed: _busy ? null : _togglePause,
                            icon: Icon(
                              runner.isPaused ? Icons.play_arrow : Icons.pause,
                            ),
                            label: Text(runner.isPaused ? 'Riprendi' : 'Pausa'),
                          ),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _completeStep,
                          icon: Icon(
                            step?.isTimed == true
                                ? Icons.skip_next
                                : Icons.check,
                          ),
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
    if (widget.runId <= 0) {
      debugPrint('[workout-runner] invalid runId=${widget.runId}');
      setState(() {
        _loading = false;
        _error = 'ID runner workout non valido.';
        _runner?.dispose();
        _runner = null;
      });
      return;
    }
    debugPrint(
      '[workout-runner] loading -> loading endpoint=/workout-runs/${widget.runId} id=${widget.runId}',
    );
    setState(() {
      _loading = true;
      _error = null;
    });
    final deps = AppScope.read(context);
    try {
      await deps.auth.waitUntilReady();
      if (!deps.auth.isAuthenticated) {
        throw ApiException(statusCode: 401, message: 'Sessione non attiva.');
      }
      final run = await deps.workoutApi.getWorkoutRun(widget.runId);
      debugPrint('[workout-runner] loading -> loaded id=${run.id}');
      if (!mounted) return;
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
      debugPrint('[workout-runner] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[workout-runner] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento runner.');
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

extension on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
