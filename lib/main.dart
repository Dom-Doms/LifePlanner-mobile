import 'package:flutter/material.dart';

import 'core/app_config.dart';
import 'core/app_scope.dart';
import 'core/network/api_client.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/notifications/mobile_push_service.dart';
import 'core/storage/session_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/services/auth_api.dart';
import 'data/services/planning_api.dart';
import 'data/services/push_api.dart';
import 'data/services/users_api.dart';
import 'data/services/workout_api.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/auth_screens.dart';
import 'features/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final apiClient = ApiClient(baseUrl: config.apiBaseUrl);
  final sessionStorage = SessionStorage();
  final notifications = LocalNotificationService();
  final authApi = AuthApi(apiClient);
  final pushApi = PushApi(apiClient);
  late final AuthController authController;
  final mobilePush = MobilePushService(
    backend: PushApiMobilePushBackend(pushApi),
    firebase: FirebaseMessagingGateway(),
    notifier: LocalEventReminderNotifier(notifications),
    isAuthenticated: () => authController.isAuthenticated,
  );
  authController = AuthController(
    authApi: authApi,
    apiClient: apiClient,
    storage: sessionStorage,
    mobilePush: mobilePush,
  );
  await mobilePush.initialize();
  final dependencies = AppDependencies(
    config: config,
    apiClient: apiClient,
    sessionStorage: sessionStorage,
    notifications: notifications,
    mobilePush: mobilePush,
    authApi: authApi,
    planningApi: PlanningApi(apiClient),
    workoutApi: WorkoutApi(apiClient),
    usersApi: UsersApi(apiClient),
    pushApi: pushApi,
    auth: authController,
  );

  runApp(AppScope(dependencies: dependencies, child: const LifePlannerApp()));
}

class LifePlannerApp extends StatefulWidget {
  const LifePlannerApp({super.key});

  @override
  State<LifePlannerApp> createState() => _LifePlannerAppState();
}

class _LifePlannerAppState extends State<LifePlannerApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _restoreStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restoreStarted) {
      _restoreStarted = true;
      AppScope.of(context).auth.restore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return AnimatedBuilder(
      animation: deps.auth,
      builder: (context, _) {
        return MaterialApp(
          title: 'LifePlanner',
          debugShowCheckedModeBanner: false,
          theme: buildLifePlannerTheme(Brightness.light),
          darkTheme: buildLifePlannerTheme(Brightness.dark),
          themeMode: _themeMode,
          home: deps.auth.restoring
              ? const _SplashScreen()
              : deps.auth.isAuthenticated
              ? MainShell(
                  themeMode: _themeMode,
                  onThemeChanged: (value) => setState(() => _themeMode = value),
                )
              : const LoginScreen(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
