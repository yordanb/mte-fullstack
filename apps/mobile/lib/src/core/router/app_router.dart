import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_detail_page.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_form_page.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_page.dart';
import 'package:mte_data_center/src/features/auth/presentation/login_page.dart';
import 'package:mte_data_center/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:mte_data_center/src/features/dbr/presentation/dbr_page.dart';
import '../widgets/placeholder_page.dart';

/// GoRouter Milestone 1: /login, / (dashboard), + route stub milestone
/// berikutnya. Redirect ke /login bila tanpa token; /users & /audit
/// khusus admin.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.status == AuthStatus.authenticated;
      final onLogin = state.matchedLocation == '/login';

      if (auth.status == AuthStatus.unknown) return null;
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      if (loggedIn && (state.matchedLocation == '/users' || state.matchedLocation == '/audit')) {
        if (!auth.isAdmin) return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/', builder: (c, s) => const DashboardPage()),
      GoRoute(path: '/dbr', builder: (c, s) => const DbrPage()),
      GoRoute(path: '/performance', builder: (c, s) => const PlaceholderPage(title: 'Performance')),
      GoRoute(path: '/equipment', builder: (c, s) => const PlaceholderPage(title: 'Equipment')),
      GoRoute(path: '/fui', builder: (c, s) => const PlaceholderPage(title: 'FUI')),
      GoRoute(path: '/suggestion', builder: (c, s) => const PlaceholderPage(title: 'Suggestion FUI')),
      GoRoute(
          path: '/report-followup', builder: (c, s) => const PlaceholderPage(title: 'Report Follow Up')),
      GoRoute(path: '/activity', builder: (c, s) => const ActivityPage()),
      GoRoute(
        path: '/activity/new',
        builder: (c, s) => ActivityFormPage(initialDate: s.uri.queryParameters['date']),
      ),
      GoRoute(path: '/activity/:id', builder: (c, s) => ActivityDetailPage(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/activity/:id/edit',
          builder: (c, s) => ActivityFormPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/update-data', builder: (c, s) => const PlaceholderPage(title: 'Update Data')),
      GoRoute(path: '/users', builder: (c, s) => const PlaceholderPage(title: 'Users')),
      GoRoute(path: '/audit', builder: (c, s) => const PlaceholderPage(title: 'Audit Log')),
      GoRoute(path: '/profile', builder: (c, s) => const PlaceholderPage(title: 'Profil')),
    ],
  );
});
