import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../features/auth/views/splash_screen.dart';
import '../../features/auth/views/onboarding_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/signup_screen.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/tasks/views/tasks_screen.dart';
import '../../features/tasks/views/task_detail_screen.dart';
import '../../features/tasks/viewmodels/task_viewmodel.dart';
import '../theme/app_palette.dart';
import '../../features/timetable/views/timetable_screen.dart';
import '../../features/ai_tools/views/ai_tools_screen.dart';
import '../../features/ai_tools/views/summarizer_screen.dart';
import '../../features/ai_tools/views/grammar_screen.dart';
import '../../features/ai_tools/views/chatbot_screen.dart';
import '../../features/ai_tools/views/tts_screen.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/cgpa/views/cgpa_screen.dart';
import '../../features/attendance/views/attendance_screen.dart';
import '../../features/study_timer/views/study_timer_screen.dart';
import '../../features/documents/views/documents_screen.dart';
import '../../features/documents/views/document_library_screen.dart';
import '../../features/documents/views/scanner_screen.dart';
import '../../features/documents/models/scanner_editor_route_args.dart';
import '../../features/documents/views/scanner_editor_screen.dart';
import '../../features/documents/views/pdf_viewer_screen.dart';
import '../../features/documents/models/document_model.dart';
import '../../features/documents/views/image_to_pdf_screen.dart';
import '../../features/documents/views/pdf_generator_screen.dart';
import '../../features/documents/views/qr_screen.dart';
import '../../features/documents/views/documents_scope.dart';
import '../navigation/back_navigation.dart';
import '../widgets/brainup_bottom_nav.dart';

Widget _rootScreen(Widget child, {String fallback = '/home'}) =>
    BrainUpBackHandler(fallback: fallback, child: child);

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Root navigator — SnackBars and Provider lookups from notification handlers.
GlobalKey<NavigatorState> get brainupRootNavigatorKey => _rootNavigatorKey;

GoRouter createRouter(AuthViewModel authVM) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isAuth = authVM.isAuthenticated;
      final isLoading = authVM.state == AuthState.initial;
      final loc = state.matchedLocation;

      if (isLoading) return '/splash';
      if (!isAuth &&
          loc != '/login' &&
          loc != '/signup' &&
          loc != '/onboarding' &&
          loc != '/splash') {
        return '/onboarding';
      }
      if (isAuth &&
          (loc == '/login' ||
              loc == '/signup' ||
              loc == '/onboarding' ||
              loc == '/splash')) {
        return '/home';
      }
      return null;
    },
    refreshListenable: authVM,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      // Push-on-top routes (full screen, outside shell)
      GoRoute(
        path: '/cgpa',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(const CgpaScreen()),
      ),
      GoRoute(
        path: '/attendance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(const AttendanceScreen()),
      ),
      GoRoute(
        path: '/study-timer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(const StudyTimerScreen()),
      ),
      GoRoute(
        path: '/documents',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const DocumentsScope(child: DocumentsScreen()),
      ),
      GoRoute(
        path: '/documents/library',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => DocumentsScope(
          child: DocumentLibraryScreen(
            initialSubject: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/documents/scanner',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const DocumentsScope(child: ScannerScreen()),
      ),
      GoRoute(
        path: '/documents/scanner-editor',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final extra = state.extra;
          var initial = const <File>[];
          var processOnLoad = false;

          if (extra is ScannerEditorRouteArgs) {
            initial = List<File>.from(extra.pages);
            processOnLoad = extra.processOnLoad;
          } else if (extra is Map) {
            final raw = extra['pages'];
            if (raw is List) {
              initial = raw
                  .map<File>((e) => e is File ? e : File(e.toString()))
                  .toList();
            }
            processOnLoad = extra['processOnLoad'] == true;
          } else if (extra is List<File>) {
            initial = List<File>.from(extra);
          } else if (extra is List) {
            initial = extra
                .map<File>((e) => e is File ? e : File(e.toString()))
                .toList();
          }

          return DocumentsScope(
            child: ScannerEditorScreen(
              initialPages: initial,
              processOnLoad: processOnLoad,
            ),
          );
        },
      ),
      GoRoute(
        path: '/documents/pdf-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is DocumentModel) {
            return DocumentsScope(
              child: PdfViewerScreen(
                path: extra.localPath,
                title: extra.title,
                docId: extra.id,
              ),
            );
          }
          if (extra is String) {
            return DocumentsScope(child: PdfViewerScreen(path: extra));
          }
          if (extra is Map) {
            final map = extra.cast<String, dynamic>();
            return DocumentsScope(
              child: PdfViewerScreen(
                path: map['path'] as String? ?? '',
                title: map['title'] as String?,
                docId: map['docId'] as String?,
                autoAnalyze: map['autoAnalyze'] as bool? ?? false,
              ),
            );
          }
          return const DocumentsScope(
            child: Scaffold(body: Center(child: Text('No document'))),
          );
        },
      ),
      GoRoute(
        path: '/documents/image-to-pdf',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => DocumentsScope(
          child: ImageToPdfScreen(
            initialPaths:
                (state.extra as List?)?.map((e) => e.toString()).toList(),
          ),
        ),
      ),
      GoRoute(
        path: '/documents/pdf-generator',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) =>
            const DocumentsScope(child: PdfGeneratorScreen()),
      ),
      GoRoute(
        path: '/documents/qr',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const DocumentsScope(child: QrScreen()),
      ),
      GoRoute(
        path: '/ai/summarizer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) {
          final extra = state.extra;
          final initialText = extra is String ? extra.trim() : null;
          return _rootScreen(
            SummarizerScreen(
              initialText: initialText != null && initialText.isNotEmpty
                  ? initialText
                  : null,
            ),
            fallback: brainupAiToolsFallback,
          );
        },
      ),
      GoRoute(
        path: '/ai/grammar',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(
          const GrammarScreen(),
          fallback: brainupAiToolsFallback,
        ),
      ),
      GoRoute(
        path: '/ai/chatbot',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(
          const ChatbotScreen(),
          fallback: brainupAiToolsFallback,
        ),
      ),
      GoRoute(
        path: '/ai/tts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => _rootScreen(
          const TtsScreen(),
          fallback: brainupAiToolsFallback,
        ),
      ),
      GoRoute(
        path: '/tasks/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final vm = context.read<TaskViewModel>();
          final matches = vm.allTasks.where((t) => t.id == id);
          if (matches.isEmpty) {
            return _rootScreen(
              Scaffold(
                backgroundColor: context.colors.surface,
                appBar: AppBar(
                  backgroundColor: context.colors.surface,
                  automaticallyImplyLeading: false,
                  leading: brainUpBackButton(context, fallback: '/tasks'),
                ),
                body: Center(
                  child: Text(
                    'Task not found',
                    style: context.text.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
              fallback: '/tasks',
            );
          }
          return _rootScreen(
            TaskDetailScreen(task: matches.first, vm: vm),
            fallback: '/tasks',
          );
        },
      ),
      // Bottom nav shell
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (_, __) => const TasksScreen(),
          ),
          GoRoute(
            path: '/timetable',
            builder: (_, __) => const TimetableScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (_, __) => const AiToolsScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const _routes = ['/home', '/tasks', '/timetable', '/ai', '/profile'];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _routes.indexOf(loc);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        brainupShellBack(context);
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: BrainUpBottomNav(
          currentIndex: _currentIndex(context),
          onTap: (i) => context.go(_routes[i]),
        ),
      ),
    );
  }
}
