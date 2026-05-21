import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/auth_models.dart';
import '../../data/models/planning_models.dart';
import '../../data/models/workout_models.dart';
import '../../shared/widgets/app_cards.dart';
import 'event_form_logic.dart';

class EventFormSheet extends StatefulWidget {
  const EventFormSheet({
    required this.date,
    required this.templates,
    this.initial,
    this.initialType,
    super.key,
  });

  final DateTime date;
  final List<WorkoutTemplateResponse> templates;
  final CalendarEventResponse? initial;
  final String? initialType;

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _freeParticipant;
  late final TextEditingController _userSearch;
  late final TextEditingController _recurrenceUntil;
  late String _type;
  late bool _allDay;
  late bool _reminderEnabled;
  late int _reminderMinutes;
  late String _recurrenceType;
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;
  late int? _templateId;
  late List<ParticipantDto> _participants;
  List<UserResponse> _searchResults = [];
  bool _saving = false;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final event = widget.initial;
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _freeParticipant = TextEditingController();
    _userSearch = TextEditingController();
    _recurrenceUntil = TextEditingController(
      text: event?.recurrenceUntil ?? '',
    );
    _type = event?.type ?? widget.initialType ?? 'PERSONAL';
    _allDay = event?.allDay ?? false;
    _reminderEnabled = event?.reminderEnabled ?? false;
    _reminderMinutes = event?.reminderMinutesBefore ?? 30;
    _recurrenceType = event?.recurrenceType ?? 'NONE';
    _startTime =
        parseEventTime(event?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _endTime =
        parseEventTime(event?.endTime) ?? const TimeOfDay(hour: 10, minute: 0);
    _templateId = event?.workoutTemplateId;
    _participants = [...event?.participants ?? const []];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _freeParticipant.dispose();
    _userSearch.dispose();
    _recurrenceUntil.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.initial == null
                  ? (_type == 'WORKOUT'
                        ? 'Aggiungi allenamento'
                        : 'Nuovo evento')
                  : 'Modifica evento',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Titolo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descrizione'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'STUDY', child: Text('Studio')),
                DropdownMenuItem(value: 'EXAM', child: Text('Esame')),
                DropdownMenuItem(value: 'PERSONAL', child: Text('Personale')),
                DropdownMenuItem(value: 'GYM', child: Text('Palestra')),
                DropdownMenuItem(value: 'WORKOUT', child: Text('Allenamento')),
                DropdownMenuItem(value: 'OTHER', child: Text('Altro')),
              ],
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tutto il giorno'),
              value: _allDay,
              onChanged: (value) => setState(() => _allDay = value),
            ),
            if (!_allDay)
              _EventTimePickerPanel(
                start: _startTime,
                end: _endTime,
                onPickStart: () => _pickTime(isStart: true),
                onPickEnd: () => _pickTime(isStart: false),
                onDurationSelected: _applyDuration,
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Luogo'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(labelText: 'Ricorrenza'),
              items: const [
                DropdownMenuItem(value: 'NONE', child: Text('Nessuna')),
                DropdownMenuItem(value: 'DAILY', child: Text('Giornaliera')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Settimanale')),
                DropdownMenuItem(
                  value: 'BIWEEKLY',
                  child: Text('Bisettimanale'),
                ),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Mensile')),
              ],
              onChanged: (value) => setState(() {
                _recurrenceType = value ?? 'NONE';
                if (_recurrenceType == 'NONE') _recurrenceUntil.clear();
              }),
            ),
            if (_recurrenceType != 'NONE') ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ripeti fino al'),
                subtitle: Text(
                  _recurrenceUntil.text.isEmpty
                      ? 'Scegli data fine ricorrenza'
                      : _recurrenceUntil.text,
                ),
                trailing: const Icon(Icons.event),
                onTap: _pickRecurrenceUntil,
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Promemoria'),
              value: _reminderEnabled,
              onChanged: (value) => setState(() => _reminderEnabled = value),
            ),
            if (_reminderEnabled)
              DropdownButtonFormField<int>(
                initialValue: _reminderMinutes,
                decoration: const InputDecoration(labelText: 'Minuti prima'),
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10 minuti')),
                  DropdownMenuItem(value: 30, child: Text('30 minuti')),
                  DropdownMenuItem(value: 60, child: Text('1 ora')),
                  DropdownMenuItem(value: 1440, child: Text('1 giorno')),
                ],
                onChanged: (value) =>
                    setState(() => _reminderMinutes = value ?? 30),
              ),
            if (_type == 'WORKOUT') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _templateId,
                decoration: const InputDecoration(labelText: 'Scheda workout'),
                items: widget.templates
                    .map(
                      (template) => DropdownMenuItem(
                        value: template.id,
                        child: Text(template.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _templateId = value),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Partecipanti',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _participants
                  .map(
                    (participant) => InputChip(
                      label: Text(participant.displayName),
                      onDeleted: () =>
                          setState(() => _participants.remove(participant)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _freeParticipant,
                    decoration: const InputDecoration(labelText: 'Nome libero'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _addFreeParticipant,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userSearch,
                    decoration: const InputDecoration(
                      labelText: 'Cerca utente',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _searching ? null : _searchUsers,
                  icon: _searching
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            ..._searchResults.map(
              (user) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(user.displayLabel),
                subtitle: Text(user.email),
                trailing: const Icon(Icons.person_add_alt),
                onTap: () => _addRegisteredParticipant(user),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorPanel(message: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(widget.initial == null ? 'Crea' : 'Salva'),
            ),
          ],
        );
      },
    );
  }

  void _addFreeParticipant() {
    final name = _freeParticipant.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _participants.add(
        ParticipantDto(displayName: name, participantType: 'FREE_TEXT'),
      );
      _freeParticipant.clear();
    });
  }

  Future<void> _searchUsers() async {
    setState(() => _searching = true);
    try {
      final users = await AppScope.of(
        context,
      ).usersApi.searchUsers(_userSearch.text);
      setState(() => _searchResults = users);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _addRegisteredParticipant(UserResponse user) {
    final exists = _participants.any(
      (item) => item.registeredUserId == user.id,
    );
    if (exists) return;
    setState(() {
      _participants.add(
        ParticipantDto(
          registeredUserId: user.id,
          displayName: user.displayLabel,
          participantType: 'REGISTERED_USER',
        ),
      );
      _searchResults = [];
      _userSearch.clear();
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current =
        (isStart ? _startTime : _endTime) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: current);
    if (!mounted || picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
        final end = _endTime;
        if (end == null ||
            eventMinutesOfDay(end) <= eventMinutesOfDay(picked)) {
          _endTime = addEventDuration(picked, const Duration(hours: 1));
        }
      } else {
        _endTime = picked;
      }
    });
  }

  void _applyDuration(Duration duration) {
    final start = _startTime ?? const TimeOfDay(hour: 9, minute: 0);
    setState(() {
      _startTime = start;
      _endTime = addEventDuration(start, duration);
    });
  }

  Future<void> _pickRecurrenceUntil() async {
    final initial =
        DateTime.tryParse(_recurrenceUntil.text) ??
        widget.date.add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(widget.date) ? widget.date : initial,
      firstDate: widget.date,
      lastDate: widget.date.add(const Duration(days: 365 * 3)),
    );
    if (!mounted || picked == null) return;
    setState(() => _recurrenceUntil.text = dates.formatDate(picked));
  }

  Future<void> _save() async {
    final timeError = validateEventTimes(
      allDay: _allDay,
      start: _startTime,
      end: _endTime,
    );
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Inserisci un titolo.');
      return;
    }
    if (timeError != null) {
      setState(() => _error = timeError);
      return;
    }
    if (_recurrenceType != 'NONE' && _recurrenceUntil.text.trim().isEmpty) {
      setState(() => _error = 'Inserisci la data di fine ripetizione.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = buildEventFormPayload(
        title: _title.text.trim(),
        description: _description.text.trim(),
        eventDate: dates.formatDate(widget.date),
        start: _startTime,
        end: _endTime,
        allDay: _allDay,
        type: _type,
        location: _location.text.trim(),
        workoutTemplateId: _type == 'WORKOUT' ? _templateId : null,
        recurrenceType: _recurrenceType,
        recurrenceUntil: _recurrenceUntil.text.trim(),
        reminderEnabled: _reminderEnabled,
        reminderMinutes: _reminderMinutes,
        participants: _participants,
      );
      if (widget.initial == null) {
        await AppScope.of(context).planningApi.createEvent(payload);
      } else {
        await AppScope.of(
          context,
        ).planningApi.updateEvent(widget.initial!.id, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EventTimePickerPanel extends StatelessWidget {
  const _EventTimePickerPanel({
    required this.start,
    required this.end,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onDurationSelected,
  });

  final TimeOfDay? start;
  final TimeOfDay? end;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<Duration> onDurationSelected;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  label: 'Inizio',
                  value: start == null ? '--:--' : formatEventTime(start!),
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeButton(
                  label: 'Fine',
                  value: end == null ? '--:--' : formatEventTime(end!),
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: eventDurationQuickChoices
                .map(
                  (duration) => ActionChip(
                    label: Text(formatEventDurationLabel(duration)),
                    onPressed: () => onDurationSelected(duration),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.center,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
