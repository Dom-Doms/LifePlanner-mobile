import 'package:flutter/widgets.dart';

import '../data/services/auth_api.dart';
import '../data/services/planning_api.dart';
import '../data/services/push_api.dart';
import '../data/services/users_api.dart';
import '../data/services/workout_api.dart';
import '../features/auth/auth_controller.dart';
import 'app_config.dart';
import 'network/api_client.dart';
import 'notifications/local_notification_service.dart';
import 'notifications/mobile_push_service.dart';
import 'storage/session_storage.dart';

class AppDependencies {
  AppDependencies({
    required this.config,
    required this.apiClient,
    required this.sessionStorage,
    required this.notifications,
    required this.mobilePush,
    required this.authApi,
    required this.planningApi,
    required this.workoutApi,
    required this.usersApi,
    required this.pushApi,
    required this.auth,
  });

  final AppConfig config;
  final ApiClient apiClient;
  final SessionStorage sessionStorage;
  final LocalNotificationService notifications;
  final MobilePushService mobilePush;
  final AuthApi authApi;
  final PlanningApi planningApi;
  final WorkoutApi workoutApi;
  final UsersApi usersApi;
  final PushApi pushApi;
  final AuthController auth;
}

class AppScope extends InheritedWidget {
  const AppScope({required this.dependencies, required super.child, super.key});

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.dependencies;
  }

  static AppDependencies read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope is missing from the widget tree');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
