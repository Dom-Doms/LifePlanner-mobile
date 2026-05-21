import 'dart:async';
import 'dart:math' as math;

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
          _DayTimelineCard(
            date: _date,
            events: _events,
            onEventSelected: _showEventActions,
          ),
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

  Future<void> _showEventActions(CalendarEventResponse event) async {
    final sessionId = _eventWorkoutSessionId(event);
    final session = _findSession(sessionId);
    final templateId = event.workoutTemplateId ?? session?.templateId;
    final canOpenWorkout = event.type == 'WORKOUT' && templateId != null;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    event.type == 'WORKOUT'
                        ? Icons.fitness_center
                        : Icons.event,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (event.completed == true)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                event.allDay
                    ? 'Tutto il giorno'
                    : '${_shortTime(event.startTime) ?? '--'} - ${_shortTime(event.endTime) ?? '--'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (event.description?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (event.canEdit ?? true)
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openEventForm(initial: event);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Modifica'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _deleteEvent(event);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      event.canRemoveForMe == true ? 'Rimuovi' : 'Elimina',
                    ),
                  ),
                  if (canOpenWorkout)
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _openWorkoutDetail(
                          templateId,
                          workoutSessionId: sessionId,
                          initialTemplate: _findTemplate(templateId),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Apri'),
                    ),
                ],
              ),
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
      final sessionId = _eventWorkoutSessionId(event);
      if (event.type != 'WORKOUT' || sessionId == null) continue;
      final session = sessionsById[sessionId];
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

  int? _eventWorkoutSessionId(CalendarEventResponse event) =>
      event.linkedWorkoutSessionId ??
      event.ownerWorkoutSessionId ??
      event.workoutSessionId;

  WorkoutSessionResponse? _findSession(int? sessionId) {
    if (sessionId == null) return null;
    for (final session in _sessions) {
      if (session.id == sessionId) return session;
    }
    return null;
  }

  WorkoutTemplateResponse? _findTemplate(int? templateId) {
    if (templateId == null) return null;
    for (final template in _templates) {
      if (template.id == templateId) return template;
    }
    return null;
  }

  Future<void> _load() async {
    final date = dates.formatDate(_date);
    debugPrint(
      '[day-screen] loading -> loading date=$date endpoints=/day-contexts,/daily-plans/date/$date,/events,/workout-sessions/date/$date,/workout-templates',
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
      final results = await Future.wait([
        deps.planningApi.getDayContexts(),
        deps.planningApi.getDailyPlan(date),
        deps.planningApi.getEvents(from: date, to: date),
        deps.workoutApi.getWorkoutSessionsByDate(date),
        deps.workoutApi.getWorkoutTemplates(),
      ]);
      debugPrint('[day-screen] loading -> loaded date=$date');
      if (!mounted) return;
      setState(() {
        _contexts = results[0] as List<DayContextResponse>;
        _plan = results[1] as DailyPlanResponse;
        _events = (results[2] as List<CalendarEventResponse>)
          ..sort(_compareEvents);
        _sessions = results[3] as List<WorkoutSessionResponse>;
        _templates = results[4] as List<WorkoutTemplateResponse>;
      });
    } on ApiException catch (error) {
      debugPrint('[day-screen] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[day-screen] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento giornata.');
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

  String? _shortTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
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
    final from = dates.formatDate(_weekStart);
    final to = dates.formatDate(_weekStart.add(const Duration(days: 6)));
    debugPrint(
      '[week-screen] loading -> loading from=$from to=$to endpoints=/daily-plans/week,/events,/workout-sessions',
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
      final results = await Future.wait([
        deps.planningApi.getWeekPlans(from),
        deps.planningApi.getEvents(from: from, to: to),
        deps.workoutApi.getWorkoutSessions(from: from, to: to),
      ]);
      debugPrint('[week-screen] loading -> loaded from=$from to=$to');
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<DailyPlanResponse>;
        _events = results[1] as List<CalendarEventResponse>;
        _sessions = results[2] as List<WorkoutSessionResponse>;
      });
    } on ApiException catch (error) {
      debugPrint('[week-screen] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[week-screen] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento settimana.');
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
    final from = dates.formatDate(dates.firstVisibleMonthDay(_month));
    final to = dates.formatDate(dates.lastVisibleMonthDay(_month));
    debugPrint(
      '[calendar-screen] loading -> loading from=$from to=$to endpoints=/events,/workout-sessions',
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
      final results = await Future.wait([
        deps.planningApi.getEvents(from: from, to: to),
        deps.workoutApi.getWorkoutSessions(from: from, to: to),
      ]);
      debugPrint('[calendar-screen] loading -> loaded from=$from to=$to');
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<CalendarEventResponse>;
        _sessions = results[1] as List<WorkoutSessionResponse>;
      });
    } on ApiException catch (error) {
      debugPrint('[calendar-screen] loading -> error ${error.message}');
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      debugPrint('[calendar-screen] loading -> error $error');
      if (mounted) setState(() => _error = 'Errore caricamento calendario.');
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

enum _TimelineMode { compact, fullDay }

class _DayTimelineCard extends StatefulWidget {
  const _DayTimelineCard({
    required this.date,
    required this.events,
    required this.onEventSelected,
  });

  final DateTime date;
  final List<CalendarEventResponse> events;
  final ValueChanged<CalendarEventResponse> onEventSelected;

  @override
  State<_DayTimelineCard> createState() => _DayTimelineCardState();
}

class _DayTimelineCardState extends State<_DayTimelineCard> {
  static const double _hourHeight = 64;
  static const double _hourGutter = 52;
  static const double _minimumEventHeight = 22;
  static const double _compactEventHeight = 34;

  Timer? _clock;
  _TimelineMode _mode = _TimelineMode.compact;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isToday) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = [...widget.events]..sort(_compareTimelineEvents);
    final allDayEvents = events
        .where((event) => event.allDay || _eventStartMinutes(event) == null)
        .toList();
    final timedEvents = events
        .where((event) => !event.allDay && _eventStartMinutes(event) != null)
        .toList();
    final range = _resolveRange(timedEvents);
    final layouts = _layoutTimedEvents(timedEvents, range);

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Timeline',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Compatta'),
                  selected: _mode == _TimelineMode.compact,
                  onSelected: (_) =>
                      setState(() => _mode = _TimelineMode.compact),
                ),
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('24h'),
                  selected: _mode == _TimelineMode.fullDay,
                  onSelected: (_) =>
                      setState(() => _mode = _TimelineMode.fullDay),
                ),
              ],
            ),
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: EmptyState(
                title: 'Nessun evento',
                subtitle: 'Aggiungi un evento o un workout alla giornata.',
              ),
            )
          else ...[
            if (allDayEvents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allDayEvents
                      .map(
                        (event) => ActionChip(
                          avatar: Icon(
                            event.type == 'WORKOUT'
                                ? Icons.fitness_center
                                : Icons.event,
                            size: 16,
                          ),
                          label: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              event.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          onPressed: () => widget.onEventSelected(event),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (range.hourCount <= 0)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: EmptyState(
                  title: 'Nessun evento a orario',
                  subtitle: 'Gli eventi senza orario restano in alto.',
                ),
              )
            else
              _timelineGrid(context, range, layouts),
          ],
        ],
      ),
    );
  }

  Widget _timelineGrid(
    BuildContext context,
    _VisibleTimelineRange range,
    List<_TimelineEventLayout> layouts,
  ) {
    final height = range.hourCount * _hourHeight;
    final currentTop = _currentTimeTop(range);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.max(0.0, constraints.maxWidth - _hourGutter);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              ...List.generate(range.hourCount, (index) {
                final hour = range.startHour + index;
                return Positioned(
                  top: index * _hourHeight,
                  left: 0,
                  right: 0,
                  height: _hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: _hourGutter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3, left: 12),
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          height: 1,
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (currentTop != null)
                Positioned(
                  top: currentTop,
                  left: 0,
                  right: 0,
                  child: _CurrentTimeMarker(label: _formatMinutes(_nowMinute)),
                ),
              ...layouts.map((layout) {
                final available = math.max(
                  0.0,
                  contentWidth * layout.widthFraction - 4,
                );
                final left =
                    _hourGutter + contentWidth * layout.leftFraction + 2;
                final maxWidth = math.max(0.0, constraints.maxWidth - left - 4);
                final width = math.min(available, maxWidth);
                return Positioned(
                  top: layout.top,
                  left: left,
                  width: width,
                  height: layout.height,
                  child: _TimelineEventTile(
                    layout: layout,
                    onTap: () => widget.onEventSelected(layout.event),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  _VisibleTimelineRange _resolveRange(List<CalendarEventResponse> events) {
    if (_mode == _TimelineMode.fullDay) {
      return const _VisibleTimelineRange(0, 24);
    }
    if (events.isEmpty) {
      if (!_isToday) return const _VisibleTimelineRange(0, 0);
      final start = math.max(0, DateTime.now().hour - 1);
      final end = math.min(24, math.max(start + 3, DateTime.now().hour + 2));
      return _VisibleTimelineRange(start, end);
    }

    var firstStart = 24 * 60;
    var lastEnd = 0;
    for (final event in events) {
      final start = _eventStartMinutes(event);
      if (start == null) continue;
      final end = _eventEndMinutes(event, start);
      firstStart = math.min(firstStart, start);
      lastEnd = math.max(lastEnd, end);
    }

    var startHour = math.max(0, (firstStart / 60).floor() - 1);
    var endHour = math.min(24, (lastEnd / 60).ceil() + 1);
    while (endHour - startHour < 3 && endHour < 24) {
      endHour += 1;
    }
    while (endHour - startHour < 3 && startHour > 0) {
      startHour -= 1;
    }
    return _VisibleTimelineRange(startHour, endHour);
  }

  List<_TimelineEventLayout> _layoutTimedEvents(
    List<CalendarEventResponse> events,
    _VisibleTimelineRange range,
  ) {
    if (range.hourCount <= 0) return const [];
    final normalized =
        events
            .map((event) {
              final start = _eventStartMinutes(event);
              if (start == null) return null;
              final end = _eventEndMinutes(event, start);
              final visibleStart = start
                  .clamp(range.startMinute, range.endMinute)
                  .toInt();
              var visibleEnd = end
                  .clamp(range.startMinute, range.endMinute)
                  .toInt();
              if (visibleEnd <= visibleStart) {
                visibleEnd = math.min(range.endMinute, visibleStart + 15);
              }
              if (visibleEnd <= visibleStart) return null;
              return _NormalizedTimelineEvent(
                event: event,
                start: visibleStart,
                end: visibleEnd,
              );
            })
            .whereType<_NormalizedTimelineEvent>()
            .toList()
          ..sort((a, b) {
            final byStart = a.start.compareTo(b.start);
            return byStart != 0 ? byStart : a.end.compareTo(b.end);
          });

    final groups = <List<_NormalizedTimelineEvent>>[];
    var group = <_NormalizedTimelineEvent>[];
    var groupEnd = 0;
    for (final event in normalized) {
      if (group.isEmpty || event.start < groupEnd) {
        group.add(event);
        groupEnd = math.max(groupEnd, event.end);
      } else {
        groups.add(group);
        group = [event];
        groupEnd = event.end;
      }
    }
    if (group.isNotEmpty) groups.add(group);

    final layouts = <_TimelineEventLayout>[];
    for (final itemGroup in groups) {
      final columns = <List<_NormalizedTimelineEvent>>[];
      final assignments = <_NormalizedTimelineEvent, int>{};
      for (final event in itemGroup) {
        var columnIndex = columns.indexWhere(
          (column) => column.last.end <= event.start,
        );
        if (columnIndex == -1) {
          columnIndex = columns.length;
          columns.add(<_NormalizedTimelineEvent>[]);
        }
        columns[columnIndex].add(event);
        assignments[event] = columnIndex;
      }

      final columnCount = math.max(1, columns.length);
      for (final event in itemGroup) {
        final duration = event.end - event.start;
        final rawHeight = duration / 60 * _hourHeight;
        final height = math.max(_minimumEventHeight, rawHeight);
        final top = (event.start - range.startMinute) / 60 * _hourHeight;
        final clampedHeight = math.min(
          height,
          range.hourCount * _hourHeight - top,
        );
        final columnIndex = assignments[event] ?? 0;
        layouts.add(
          _TimelineEventLayout(
            event: event.event,
            top: top,
            height: clampedHeight,
            leftFraction: columnIndex / columnCount,
            widthFraction: 1 / columnCount,
            compact: clampedHeight < _compactEventHeight,
          ),
        );
      }
    }
    return layouts;
  }

  double? _currentTimeTop(_VisibleTimelineRange range) {
    if (!_isToday) return null;
    final minutes = _nowMinute;
    if (minutes < range.startMinute || minutes > range.endMinute) return null;
    return (minutes - range.startMinute) / 60 * _hourHeight;
  }

  bool get _isToday =>
      dates.formatDate(widget.date) == dates.formatDate(DateTime.now());

  int get _nowMinute => DateTime.now().hour * 60 + DateTime.now().minute;

  static int _compareTimelineEvents(
    CalendarEventResponse a,
    CalendarEventResponse b,
  ) {
    if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
    return (_eventStartMinutes(a) ?? 0).compareTo(_eventStartMinutes(b) ?? 0);
  }

  static int? _eventStartMinutes(CalendarEventResponse event) =>
      _parseTime(event.startTime);

  static int _eventEndMinutes(CalendarEventResponse event, int start) {
    final parsedEnd = _parseTime(event.endTime);
    if (parsedEnd == null || parsedEnd <= start) return start + 60;
    return parsedEnd;
  }

  static int? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final safeHour = hour.clamp(0, 23).toInt();
    final safeMinute = minute.clamp(0, 59).toInt();
    return (safeHour * 60) + safeMinute;
  }

  static String _formatMinutes(int value) {
    final hour = value ~/ 60;
    final minute = value % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _TimelineEventTile extends StatelessWidget {
  const _TimelineEventTile({required this.layout, required this.onTap});

  final _TimelineEventLayout layout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final event = layout.event;
    final scheme = Theme.of(context).colorScheme;
    final isWorkout = event.type == 'WORKOUT';
    final background = isWorkout
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final foreground = isWorkout
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    final titleStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: foreground,
      fontWeight: FontWeight.w700,
    );
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: layout.compact ? 2 : 5,
          ),
          child: layout.compact
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isWorkout ? Icons.fitness_center : Icons.event,
                          size: 14,
                          color: foreground,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        if (event.completed == true)
                          Icon(Icons.check_circle, size: 14, color: foreground),
                      ],
                    ),
                    if (layout.height >= 44)
                      Text(
                        '${_shortTimelineTime(event.startTime)} - ${_shortTimelineTime(event.endTime)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground.withValues(alpha: .8),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  String _shortTimelineTime(String? value) {
    if (value == null || value.isEmpty) return '--';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}

class _CurrentTimeMarker extends StatelessWidget {
  const _CurrentTimeMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        SizedBox(
          width: _DayTimelineCardState._hourGutter,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ),
        ),
        Expanded(child: Container(height: 2, color: color)),
      ],
    );
  }
}

class _VisibleTimelineRange {
  const _VisibleTimelineRange(this.startHour, this.endHour);

  final int startHour;
  final int endHour;

  int get hourCount => math.max(0, endHour - startHour);
  int get startMinute => startHour * 60;
  int get endMinute => endHour * 60;
}

class _NormalizedTimelineEvent {
  const _NormalizedTimelineEvent({
    required this.event,
    required this.start,
    required this.end,
  });

  final CalendarEventResponse event;
  final int start;
  final int end;
}

class _TimelineEventLayout {
  const _TimelineEventLayout({
    required this.event,
    required this.top,
    required this.height,
    required this.leftFraction,
    required this.widthFraction,
    required this.compact,
  });

  final CalendarEventResponse event;
  final double top;
  final double height;
  final double leftFraction;
  final double widthFraction;
  final bool compact;
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
