import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart' as dates;
import '../../data/models/auth_models.dart';
import '../../data/models/planning_models.dart';
import '../../data/models/workout_models.dart';
import '../../shared/widgets/app_cards.dart';

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
  late final TextEditingController _startTime;
  late final TextEditingController _endTime;
  late final TextEditingController _freeParticipant;
  late final TextEditingController _userSearch;
  late String _type;
  late bool _allDay;
  late bool _reminderEnabled;
  late int _reminderMinutes;
  late String _recurrenceType;
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
    _startTime = TextEditingController(text: (event?.startTime ?? '').take(5));
    _endTime = TextEditingController(text: (event?.endTime ?? '').take(5));
    _freeParticipant = TextEditingController();
    _userSearch = TextEditingController();
    _type = event?.type ?? widget.initialType ?? 'PERSONAL';
    _allDay = event?.allDay ?? false;
    _reminderEnabled = event?.reminderEnabled ?? false;
    _reminderMinutes = event?.reminderMinutesBefore ?? 30;
    _recurrenceType = event?.recurrenceType ?? 'NONE';
    _templateId = event?.workoutTemplateId;
    _participants = [...event?.participants ?? const []];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _startTime.dispose();
    _endTime.dispose();
    _freeParticipant.dispose();
    _userSearch.dispose();
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _startTime,
                      decoration: const InputDecoration(
                        labelText: 'Inizio HH:mm',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _endTime,
                      decoration: const InputDecoration(
                        labelText: 'Fine HH:mm',
                      ),
                    ),
                  ),
                ],
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
              onChanged: (value) =>
                  setState(() => _recurrenceType = value ?? 'NONE'),
            ),
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = calendarEventRequest(
        title: _title.text.trim(),
        description: _description.text.trim(),
        eventDate: dates.formatDate(widget.date),
        startTime: _startTime.text.trim(),
        endTime: _endTime.text.trim(),
        allDay: _allDay,
        type: _type,
        location: _location.text.trim(),
        workoutTemplateId: _type == 'WORKOUT' ? _templateId : null,
        recurrenceType: _recurrenceType,
        reminderEnabled: _reminderEnabled,
        reminderMinutesBefore: _reminderMinutes,
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

extension on String {
  String take(int count) => length <= count ? this : substring(0, count);
}
