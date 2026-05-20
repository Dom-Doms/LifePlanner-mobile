import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/planning_models.dart';
import '../../data/models/workout_models.dart';
import '../../shared/widgets/app_cards.dart';
import '../workout/workout_runner_controller.dart';
import '../workout/workout_screens.dart';
import 'event_form_sheet.dart';

class DayScreen extends StatefulWidget {
  const DayScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  late DateTime _date;
  bool _loading = true;
  String? _error;
  DailyPlanResponse? _plan;
  List<DayContextResponse> _contexts = [];
  List<CalendarEventResponse> _events = [];
  List<WorkoutSessionResponse> _sessions = [];
  List<WorkoutTemplateResponse> _templates = [];

  @override
  void initState() {
    super.initState();
    _date = dates.dateOnly(widget.initialDate ?? DateTime.now());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Carico la giornata');
    final workoutCards = _visibleWorkoutCards();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _moveDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${dates.weekdayLabel(_date)} ${_date.day}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(dates.formatDate(_date)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _moveDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorPanel(message: _error!, onRetry: _load),
          ],
          const SizedBox(height: 12),
          _ContextCard(
            plan: _plan,
            contexts: _contexts,
            onSelected: _setContext,
            onCreate: _createContext,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openEventForm(type: 'PERSONAL'),
                  icon: const Icon(Icons.add),
                  label: const Text('Evento'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => _openEventForm(type: 'WORKOUT'),
                  icon: const Icon(Icons.fitness_center),
                  label: const Text('Workout'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            const EmptyState(
              title: 'Nessun evento',
              subtitle: 'Aggiungi un evento o un workout alla giornata.',
            )
          else
            ..._events.map(_eventCard),
          const SizedBox(height: 16),
          Text(
            'Dettaglio allenamento',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (workoutCards.isEmpty)
            const EmptyState(
              title: 'Nessun allenamento',
              subtitle: 'Gli eventi workout collegati compariranno qui.',
            )
          else
            ...workoutCards.map(_workoutCard),
        ],
      ),
    );
  }

  Widget _eventCard(CalendarEventResponse event) {
    final sessionId =
        event.linkedWorkoutSessionId ??
        event.ownerWorkoutSessionId ??
        event.workoutSessionId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  event.type == 'WORKOUT' ? Icons.fitness_center : Icons.event,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (event.completed == true)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              event.allDay
                  ? 'Tutto il giorno'
                  : '${event.startTime ?? '--'} - ${event.endTime ?? '--'}',
            ),
            if (event.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(event.description!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (event.canEdit ?? true)
                  TextButton.icon(
                    onPressed: () => _openEventForm(initial: event),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifica'),
                  ),
                TextButton.icon(
                  onPressed: () => _deleteEvent(event),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(
                    event.canRemoveForMe == true ? 'Rimuovi' : 'Elimina',
                  ),
                ),
                if (event.type == 'WORKOUT' && event.workoutTemplateId != null)
                  TextButton.icon(
                    onPressed: () => _openWorkoutDetail(
                      event.workoutTemplateId!,
                      workoutSessionId: sessionId,
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Apri'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _workoutCard(_DayWorkoutCard card) {
    final title = card.template?.name ?? card.session.title;
    final stepCount = card.template == null
        ? card.session.exercises.length
        : flattenWorkoutTemplate(card.template!).length;
    final duration = card.template == null
        ? null
        : dates.compactDuration(card.template!.estimatedDurationSeconds);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: card.templateId == null
              ? null
              : () => _openWorkoutDetail(
                  card.templateId!,
                  workoutSessionId: card.session.id,
                  initialTemplate: card.template,
                ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.fitness_center),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      card.session.participants
                              .map((item) => item.displayName)
                              .where((item) => item.isNotEmpty)
                              .join(', ')
                              .ifBlank(card.template?.description ?? '') ??
                          '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (card.event.completed == true)
                          const Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('Completato'),
                          ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('$stepCount esercizi'),
                        ),
                        if (duration != null)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(duration),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  List<_DayWorkoutCard> _visibleWorkoutCards() {
    final sessionsById = {for (final session in _sessions) session.id: session};
    final cards = <_DayWorkoutCard>[];
    for (final event in _events) {
      if (event.type != 'WORKOUT' || event.workoutSessionId == null) continue;
      final session = sessionsById[event.workoutSessionId];
      if (session == null) continue;
      final templateId = event.workoutTemplateId ?? session.templateId;
      cards.add(
        _DayWorkoutCard(
          event: event,
          session: session,
          templateId: templateId,
          template: _findTemplate(templateId),
        ),
      );
    }
    return cards;
  }

  WorkoutTemplateResponse? _findTemplate(int? templateId) {
    if (templateId == null) return null;
    for (final template in _templates) {
      if (template.id == templateId) return template;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deps = AppScope.of(context);
      final date = dates.formatDate(_date);
      final results = await Future.wait([
        deps.planningApi.getDayContexts(),
        deps.planningApi.getDailyPlan(date),
        deps.planningApi.getEvents(from: date, to: date),
        deps.workoutApi.getWorkoutSessionsByDate(date),
        deps.workoutApi.getWorkoutTemplates(),
      ]);
      setState(() {
        _contexts = results[0] as List<DayContextResponse>;
        _plan = results[1] as DailyPlanResponse;
        _events = (results[2] as List<CalendarEventResponse>)
          ..sort(_compareEvents);
        _sessions = results[3] as List<WorkoutSessionResponse>;
        _templates = results[4] as List<WorkoutTemplateResponse>;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _compareEvents(CalendarEventResponse a, CalendarEventResponse b) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return (a.startTime ?? '').compareTo(b.startTime ?? '');
  }

  Future<void> _setContext(int? contextId) async {
    final date = dates.formatDate(_date);
    await AppScope.of(context).planningApi.updateDailyPlan(
      date: date,
      contextId: contextId,
      notes: _plan?.notes,
      recurrenceType: 'NONE',
    );
    await _load();
  }

  Future<void> _createContext() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo contesto'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Etichetta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (created == true && mounted && controller.text.trim().isNotEmpty) {
      await AppScope.of(
        context,
      ).planningApi.createDayContext(label: controller.text.trim());
      await _load();
    }
  }

  Future<void> _openEventForm({
    String? type,
    CalendarEventResponse? initial,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EventFormSheet(
        date: _date,
        templates: _templates,
        initial: initial,
        initialType: type,
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _deleteEvent(CalendarEventResponse event) async {
    await AppScope.of(context).planningApi.deleteEvent(event.id);
    await _load();
  }

  void _openWorkoutDetail(
    int templateId, {
    int? workoutSessionId,
    WorkoutTemplateResponse? initialTemplate,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          templateId: templateId,
          workoutSessionId: workoutSessionId,
          eventDate: dates.formatDate(_date),
          initialTemplate: initialTemplate,
        ),
      ),
    );
  }

  void _moveDay(int delta) {
    setState(() => _date = _date.add(Duration(days: delta)));
    _load();
  }
}

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late DateTime _weekStart;
  bool _loading = true;
  String? _error;
  List<DailyPlanResponse> _plans = [];
  List<CalendarEventResponse> _events = [];
  List<WorkoutSessionResponse> _sessions = [];

  @override
  void initState() {
    super.initState();
    _weekStart = dates.mondayOf(DateTime.now());
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Carico la settimana');
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _moveWeek(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${dates.formatDate(days.first)} - ${dates.formatDate(days.last)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: () => _moveWeek(7),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (_error != null) ErrorPanel(message: _error!, onRetry: _load),
          ...days.map(_dayCard),
        ],
      ),
    );
  }

  Widget _dayCard(DateTime day) {
    final key = dates.formatDate(day);
    final matchingPlans = _plans.where((item) => item.date == key);
    final plan = matchingPlans.isEmpty ? null : matchingPlans.first;
    final events = _events.where((item) => item.eventDate == key).toList();
    final sessions = _sessions.where((item) => item.date == key).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${dates.weekdayLabel(day)} ${day.day}'),
          subtitle: Text(
            [
              if (plan?.context != null) plan!.context!.label,
              '${events.length} eventi',
              '${sessions.length} workout',
            ].join(' · '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DayScreen(initialDate: day)),
          ),
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
      final deps = AppScope.of(context);
      final from = dates.formatDate(_weekStart);
      final to = dates.formatDate(_weekStart.add(const Duration(days: 6)));
      final results = await Future.wait([
        deps.planningApi.getWeekPlans(from),
        deps.planningApi.getEvents(from: from, to: to),
        deps.workoutApi.getWorkoutSessions(from: from, to: to),
      ]);
      setState(() {
        _plans = results[0] as List<DailyPlanResponse>;
        _events = results[1] as List<CalendarEventResponse>;
        _sessions = results[2] as List<WorkoutSessionResponse>;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveWeek(int days) {
    setState(() => _weekStart = _weekStart.add(Duration(days: days)));
    _load();
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  bool _loading = true;
  String? _error;
  List<CalendarEventResponse> _events = [];
  List<WorkoutSessionResponse> _sessions = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Carico il calendario');
    final first = dates.firstVisibleMonthDay(_month);
    final days = List.generate(42, (index) => first.add(Duration(days: index)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  dates.monthLabel(_month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (_error != null) ErrorPanel(message: _error!, onRetry: _load),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: days.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _monthCell(days[index]),
          ),
        ],
      ),
    );
  }

  Widget _monthCell(DateTime day) {
    final key = dates.formatDate(day);
    final events = _events.where((item) => item.eventDate == key).toList();
    final sessions = _sessions.where((item) => item.date == key).toList();
    final muted = day.month != _month.month;
    final completed = events.any((item) => item.completed == true);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DayScreen(initialDate: day))),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          color: muted
              ? Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.surface,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: muted ? Theme.of(context).colorScheme.outline : null,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [
                  if (events.isNotEmpty)
                    _dot(Theme.of(context).colorScheme.primary),
                  if (sessions.isNotEmpty)
                    _dot(Theme.of(context).colorScheme.tertiary),
                  if (completed) _dot(Colors.green),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deps = AppScope.of(context);
      final from = dates.formatDate(dates.firstVisibleMonthDay(_month));
      final to = dates.formatDate(dates.lastVisibleMonthDay(_month));
      final results = await Future.wait([
        deps.planningApi.getEvents(from: from, to: to),
        deps.workoutApi.getWorkoutSessions(from: from, to: to),
      ]);
      setState(() {
        _events = results[0] as List<CalendarEventResponse>;
        _sessions = results[1] as List<WorkoutSessionResponse>;
      });
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.plan,
    required this.contexts,
    required this.onSelected,
    required this.onCreate,
  });

  final DailyPlanResponse? plan;
  final List<DayContextResponse> contexts;
  final ValueChanged<int?> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contesto giornata',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(onPressed: onCreate, icon: const Icon(Icons.add)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Nessuno'),
                selected: plan?.context == null,
                onSelected: (_) => onSelected(null),
              ),
              ...contexts
                  .where((item) => item.active)
                  .map(
                    (contextItem) => ChoiceChip(
                      label: Text(
                        [
                          if (contextItem.emoji != null) contextItem.emoji!,
                          contextItem.label,
                        ].join(' '),
                      ),
                      selected: plan?.context?.id == contextItem.id,
                      onSelected: (_) => onSelected(contextItem.id),
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayWorkoutCard {
  const _DayWorkoutCard({
    required this.event,
    required this.session,
    required this.templateId,
    required this.template,
  });

  final CalendarEventResponse event;
  final WorkoutSessionResponse session;
  final int? templateId;
  final WorkoutTemplateResponse? template;
}

extension _BlankString on String {
  String? ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}
