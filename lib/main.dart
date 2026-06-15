import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/viewmodels/auth_viewmodel.dart';
import 'features/home/viewmodels/home_viewmodel.dart';
import 'features/tasks/repositories/task_repository.dart';
import 'features/tasks/viewmodels/task_viewmodel.dart';
import 'features/timetable/repositories/timetable_repository.dart';
import 'features/timetable/viewmodels/timetable_viewmodel.dart';
import 'features/cgpa/repositories/cgpa_repository.dart';
import 'features/cgpa/viewmodels/cgpa_viewmodel.dart';
import 'features/attendance/repositories/attendance_repository.dart';
import 'features/attendance/viewmodels/attendance_viewmodel.dart';
import 'features/study_timer/repositories/timer_repository.dart';
import 'features/study_timer/viewmodels/timer_viewmodel.dart';
import 'features/ai_tools/repositories/ai_session_repository.dart';
import 'features/ai_tools/viewmodels/ai_viewmodel.dart';
import 'features/profile/viewmodels/profile_viewmodel.dart';
import 'core/services/lecture_notification_service.dart';
import 'core/services/incoming_file_service.dart';
import 'core/services/notification_plugin.dart';
import 'core/services/theme_provider.dart';
import 'core/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initial overlay style; the live style is re-applied per-theme in build().
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // IMPORTANT: LectureNotificationService.initialize() must be awaited before
  // runApp() because TimetableViewModel.loadTimetable() calls
  // rescheduleAllForTimetable() which depends on _initialized = true.
  await LectureNotificationService.initialize();
  await NotificationService.initialize();
  await NotificationService.ensurePermissions();

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const BrainUpApp());
}

class BrainUpApp extends StatefulWidget {
  const BrainUpApp({super.key});

  @override
  State<BrainUpApp> createState() => _BrainUpAppState();
}

class _BrainUpAppState extends State<BrainUpApp> {
  // Repositories — created once
  final _authRepo = AuthRepository();
  final _taskRepo = TaskRepository();
  final _ttRepo = TimetableRepository();
  final _attRepo = AttendanceRepository();
  final _themeProvider = ThemeProvider();

  // ViewModels — created once
  late final AuthViewModel _authVM;
  late final GoRouter _router;
  bool _incomingInitialized = false;

  @override
  void initState() {
    super.initState();
    // AuthViewModel must exist before the router so refreshListenable works
    _authVM = AuthViewModel(_authRepo);
    // Router is created ONCE — refreshListenable drives redirect re-evaluation
    _router = createRouter(_authVM);
    _themeProvider.load();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
        // Provide the already-created AuthViewModel (not a new one)
        ChangeNotifierProvider<AuthViewModel>.value(value: _authVM),
        ChangeNotifierProxyProvider<AuthViewModel, HomeViewModel>(
          create: (_) => HomeViewModel(_taskRepo, _attRepo),
          update: (_, auth, prev) =>
              prev ?? HomeViewModel(_taskRepo, _attRepo),
        ),
        ChangeNotifierProvider(
          create: (_) => TimetableViewModel(_ttRepo),
        ),
        ChangeNotifierProxyProvider<TimetableViewModel, TaskViewModel>(
          create: (_) => TaskViewModel(_taskRepo),
          update: (_, timetable, previous) {
            final vm = previous ?? TaskViewModel(_taskRepo);
            vm.loadSubjectsFromTimetable(timetable.subjects);
            return vm;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => CgpaViewModel(
            CgpaRepository(),
          ),
        ),
        ChangeNotifierProxyProvider<TimetableViewModel, AttendanceViewModel>(
          create: (_) =>
              AttendanceViewModel(_attRepo),
          update: (_, timetable, previous) {
            final vm = previous ??
                AttendanceViewModel(_attRepo);
            vm.syncSubjectsFromTimetable(timetable.subjects);
            return vm;
          },
        ),
        ChangeNotifierProxyProvider3<AuthViewModel, TimetableViewModel,
            HomeViewModel, TimerViewModel>(
          create: (_) => TimerViewModel(
            flutterLocalNotificationsPlugin,
            TimerRepository(
              db: FirebaseFirestore.instance,
              userId: _authVM.user?.uid ?? 'guest',
            ),
          ),
          update: (_, auth, timetable, home, previous) {
            final repository = TimerRepository(
              db: FirebaseFirestore.instance,
              userId: auth.user?.uid ?? 'guest',
            );
            if (previous == null) {
              final vm = TimerViewModel(
                flutterLocalNotificationsPlugin,
                repository,
              );
              vm.onSessionSaved = home.refreshStudyStats;
              vm.loadSubjectsFromTimetable(timetable.subjects);
              return vm;
            }
            previous.onSessionSaved = home.refreshStudyStats;
            previous.updateDependencies(repository: repository);
            previous.loadSubjectsFromTimetable(timetable.subjects);
            return previous;
          },
        ),
        ChangeNotifierProxyProvider<AuthViewModel, AiViewModel>(
          create: (_) => AiViewModel(
            sessionRepository: AiSessionRepository(
              db: FirebaseFirestore.instance,
              userId: _authVM.user?.uid ?? 'guest',
            ),
          ),
          update: (_, auth, previous) {
            final uid = auth.user?.uid ?? 'guest';
            if (previous != null && previous.sessionRepository.userId == uid) {
              return previous;
            }
            return AiViewModel(
              sessionRepository: AiSessionRepository(
                db: FirebaseFirestore.instance,
                userId: uid,
              ),
            );
          },
        ),
        ChangeNotifierProvider(create: (_) => ProfileViewModel(_authRepo)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp.router(
          title: 'BrainUp',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.flutterThemeMode,
          builder: (context, child) {
            if (!_incomingInitialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                IncomingFileService.initialize(context);
                _incomingInitialized = true;
              });
            }
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final scheme = Theme.of(context).colorScheme;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: scheme.surface,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          // Router is stable — never recreated
          routerConfig: _router,
        ),
      ),
    );
  }

  @override
  void dispose() {
    IncomingFileService.dispose();
    super.dispose();
  }
}
