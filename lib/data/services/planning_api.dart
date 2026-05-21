import '../../core/network/api_client.dart';
import '../models/json_helpers.dart';
import '../models/planning_logic.dart';
import '../models/planning_models.dart';

class PlanningApi {
  PlanningApi(this._client);

  final ApiClient _client;

  Future<List<DayContextResponse>> getDayContexts() async {
    final data = await _client.getList('/day-contexts');
    return data
        .map((item) => DayContextResponse.fromJson(asMap(item)))
        .toList();
  }

  Future<DayContextResponse> createDayContext({
    required String label,
    String? color,
    String? emoji,
    bool active = true,
  }) async {
    final data = await _client.postMap(
      '/day-contexts',
      body: withoutNulls({
        'label': label,
        'color': color,
        'emoji': emoji,
        'active': active,
      }),
    );
    return DayContextResponse.fromJson(data);
  }

  Future<DayContextResponse> updateDayContext(
    int id, {
    required String label,
    String? color,
    String? emoji,
    bool active = true,
  }) async {
    final data = await _client.putMap(
      '/day-contexts/$id',
      body: withoutNulls({
        'label': label,
        'color': color,
        'emoji': emoji,
        'active': active,
      }),
    );
    return DayContextResponse.fromJson(data);
  }

  Future<void> deleteDayContext(int id) => _client.delete('/day-contexts/$id');

  Future<DailyPlanResponse> getDailyPlan(String date) async {
    final data = await _client.getMap('/daily-plans/date/$date');
    return DailyPlanResponse.fromJson(data);
  }

  Future<DailyPlanResponse> updateDailyPlan({
    required String date,
    int? contextId,
    String? notes,
    String? recurrenceType,
    String? recurrenceUntil,
  }) async {
    final data = await _client.putMap(
      '/daily-plans/date/$date',
      body: withoutNulls({
        'contextId': contextId,
        'notes': notes,
        'recurrenceType': recurrenceType,
        'recurrenceUntil': recurrenceUntil,
      }),
    );
    return DailyPlanResponse.fromJson(data);
  }

  Future<List<DailyPlanResponse>> getWeekPlans(String startDate) async {
    final data = await _client.getList(
      '/daily-plans/week',
      query: {'startDate': startDate},
    );
    return data.map((item) => DailyPlanResponse.fromJson(asMap(item))).toList();
  }

  Future<List<DailyPlanResponse>> getMonthPlans(int year, int month) async {
    final data = await _client.getList(
      '/daily-plans/month',
      query: {'year': '$year', 'month': '$month'},
    );
    return data.map((item) => DailyPlanResponse.fromJson(asMap(item))).toList();
  }

  Future<List<CalendarEventResponse>> getEvents({
    required String from,
    required String to,
  }) async {
    final data = await _client.getList(
      '/events',
      query: {'from': from, 'to': to},
    );
    return data
        .map((item) => CalendarEventResponse.fromJson(asMap(item)))
        .toList();
  }

  Future<CalendarEventResponse> createEvent(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.postMap('/events', body: payload);
    return CalendarEventResponse.fromJson(data);
  }

  Future<CalendarEventResponse> updateEvent(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.putMap('/events/$id', body: payload);
    return CalendarEventResponse.fromJson(data);
  }

  Future<void> deleteEvent(int id) => _client.delete('/events/$id');

  Future<CalendarEventResponse> linkEventWorkout({
    required int eventId,
    required int templateId,
  }) async {
    final data = await _client.postMap(
      '/events/$eventId/workout-link',
      body: workoutLinkPayload(templateId),
    );
    return CalendarEventResponse.fromJson(data);
  }
}
