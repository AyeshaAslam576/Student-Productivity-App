import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

const _shellPaths = {
  '/home',
  '/tasks',
  '/timetable',
  '/ai',
  '/profile',
};

/// Fallback when an AI feature route cannot [GoRouter.pop] (e.g. deep link).
const brainupAiToolsFallback = '/ai';

bool brainupIsShellLocation(String location) => _shellPaths.contains(location);

/// Navigates back without emptying the root stack (which closes the app).
///
/// Pushed full-screen routes (summarizer, documents, task detail, etc.) use
/// [GoRouter.pop] when the stack allows it so the previous screen is restored.
/// [fallback] is only used when there is nothing to pop. Shell tabs use
/// [GoRouter.pop] when possible; [MainShell] sends non-home tabs to `/home`
/// on system back.
void brainupPop(BuildContext context, {String fallback = '/home'}) {
  final router = GoRouter.of(context);
  final loc = router.state.matchedLocation;

  if (!brainupIsShellLocation(loc)) {
    if (router.canPop()) {
      router.pop();
      return;
    }
    if (loc != fallback) {
      router.go(fallback);
    }
    return;
  }

  if (router.canPop()) {
    router.pop();
    return;
  }
  if (loc != fallback) {
    router.go(fallback);
  }
}

/// System back on bottom-nav tabs: leave non-home tabs for `/home`; exit on home.
void brainupShellBack(BuildContext context) {
  final loc = GoRouter.of(context).state.matchedLocation;
  if (loc != '/home') {
    context.go('/home');
  } else {
    SystemNavigator.pop();
  }
}

/// Standard back [IconButton] for custom app bars (not [AppBar.automaticallyImplyLeading]).
Widget brainUpBackButton(
  BuildContext context, {
  String fallback = '/home',
  Color? iconColor,
}) {
  return IconButton(
    tooltip: 'Back',
    onPressed: () => brainupPop(context, fallback: fallback),
    icon: Icon(
      Icons.arrow_back_rounded,
      color: iconColor,
    ),
  );
}

/// Ensures the system back gesture / button matches [brainupPop].
class BrainUpBackHandler extends StatelessWidget {
  final Widget child;
  final String fallback;
  final Future<bool> Function()? onBeforePop;

  const BrainUpBackHandler({
    super.key,
    required this.child,
    this.fallback = '/home',
    this.onBeforePop,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (onBeforePop != null) {
          final allow = await onBeforePop!();
          if (!allow) return;
        }
        if (!context.mounted) return;
        brainupPop(context, fallback: fallback);
      },
      child: child,
    );
  }
}
