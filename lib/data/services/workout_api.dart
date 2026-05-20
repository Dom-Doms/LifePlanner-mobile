import '../../core/network/api_client.dart';
import '../models/json_helpers.dart';
import '../models/workout_models.dart';

class WorkoutApi {
  WorkoutApi(this._client);

  final ApiClient _client;

  Future<List<WorkoutTemplateResponse>> getWorkoutTemplates() async {
    final data = await _client.getList('/workout-templates');
    return data
        .map((item) => WorkoutTemplateResponse.fromJson(asMap(item)))
        .toList();
  }

  Future<WorkoutTemplateResponse> getWorkoutTemplate(int id) async {
    final data = await _client.getMap('/workout-templates/$id');
    return WorkoutTemplateResponse.fromJson(data);
  }

  Future<WorkoutTemplateResponse> createWorkoutTemplate(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.postMap('/workout-templates', body: payload);
    return WorkoutTemplateResponse.fromJson(data);
  }

  Future<WorkoutTemplateResponse> updateWorkoutTemplate(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.putMap('/workout-templates/$id', body: payload);
    return WorkoutTemplateResponse.fromJson(data);
  }

  Future<void> deleteWorkoutTemplate(int id) =>
      _client.delete('/workout-templates/$id');

  Future<Map<String, dynamic>> shareWorkoutTemplate({
    required int id,
    required int targetUserId,
  }) => _client.postMap(
    '/workout-templates/$id/share',
    body: {'targetUserId': targetUserId},
  );

  Future<List<WorkoutSessionResponse>> getWorkoutSessions({
    required String from,
    required String to,
  }) async {
    final data = await _client.getList(
      '/workout-sessions',
      query: {'from': from, 'to': to},
    );
    return data
        .map((item) => WorkoutSessionResponse.fromJson(asMap(item)))
        .toList();
  }

  Future<List<WorkoutSessionResponse>> getWorkoutSessionsByDate(
    String date,
  ) async {
    final data = await _client.getList('/workout-sessions/date/$date');
    return data
        .map((item) => WorkoutSessionResponse.fromJson(asMap(item)))
        .toList();
  }

  Future<WorkoutSessionResponse> createWorkoutSession(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.postMap('/workout-sessions', body: payload);
    return WorkoutSessionResponse.fromJson(data);
  }

  Future<WorkoutSessionResponse> updateWorkoutSession(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.putMap('/workout-sessions/$id', body: payload);
    return WorkoutSessionResponse.fromJson(data);
  }

  Future<void> deleteWorkoutSession(int id) =>
      _client.delete('/workout-sessions/$id');

  Future<WorkoutSessionResponse> createWorkoutSessionFromTemplate(
    Map<String, dynamic> payload,
  ) async {
    final data = await _client.postMap(
      '/workout-sessions/from-template',
      body: payload,
    );
    return WorkoutSessionResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> startWorkoutRun({
    required int templateId,
    int? workoutSessionId,
  }) async {
    final data = await _client.postMap(
      '/workout-templates/$templateId/start',
      query: {
        if (workoutSessionId != null) 'workoutSessionId': '$workoutSessionId',
      },
    );
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> getWorkoutRun(int runId) async {
    final data = await _client.getMap('/workout-runs/$runId');
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> updateWorkoutRunState({
    required int runId,
    required Map<String, dynamic> payload,
  }) async {
    final data = await _client.putMap(
      '/workout-runs/$runId/state',
      body: payload,
    );
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> pauseWorkoutRun(int runId) async {
    final data = await _client.postMap('/workout-runs/$runId/pause');
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> resumeWorkoutRun(int runId) async {
    final data = await _client.postMap('/workout-runs/$runId/resume');
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> completeWorkoutRun({
    required int runId,
    required Map<String, dynamic> payload,
  }) async {
    final data = await _client.postMap(
      '/workout-runs/$runId/complete',
      body: payload,
    );
    return WorkoutRunResponse.fromJson(data);
  }

  Future<WorkoutRunResponse> cancelWorkoutRun(int runId) async {
    final data = await _client.postMap('/workout-runs/$runId/cancel');
    return WorkoutRunResponse.fromJson(data);
  }
}
