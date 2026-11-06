import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_notifier.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_detail_page.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_form_page.dart';
import 'package:mte_data_center/src/features/activity/presentation/activity_page.dart';
import 'package:mte_data_center/src/features/auth/presentation/login_page.dart';
import 'package:mte_data_center/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:mte_data_center/src/features/dbr/presentation/dbr_page.dart';
import 'package:mte_data_center/src/features/ewacs/presentation/ewacs_page.dart';
import 'package:mte_data_center/src/features/fui/presentation/fui_page.dart';
import 'package:mte_data_center/src/features/fui/presentation/history_page.dart';
import 'package:mte_data_center/src/features/fui/presentation/report_page.dart';
import 'package:mte_data_center/src/features/fui/presentation/suggest_form_page.dart';
import 'package:mte_data_center/src/features/fui/presentation/suggestion_page.dart';
import 'package:mte_data_center/src/features/ss/presentation/ss_page.dart';
import 'package:mte_data_center/src/features/ssab/presentation/ssab_page.dart';
import 'package:mte_data_center/src/features/hourmeter/presentation/hourmeter_page.dart';
import 'package:mte_data_center/src/features/placeholders/presentation/web_placeholder_pages.dart';
import 'package:mte_data_center/src/features/profile/presentation/notifications_page.dart';
import 'package:mte_data_center/src/features/profile/presentation/profile_page.dart';
import 'package:mte_data_center/src/features/project/presentation/project_page.dart';
import 'package:mte_data_center/src/features/equipment/presentation/equipment_detail_page.dart';
import 'package:mte_data_center/src/features/safety/presentation/safety_page.dart';
import 'package:mte_data_center/src/features/update_data/presentation/update_data_page.dart';
import 'package:mte_data_center/src/features/users/presentation/audit_page.dart';
import 'package:mte_data_center/src/features/users/presentation/users_page.dart';
import 'package:mte_data_center/src/features/equipment/presentation/equipment_form_page.dart';
import 'package:mte_data_center/src/features/equipment/presentation/equipment_page.dart';
import 'package:mte_data_center/src/features/mom/presentation/mom_page.dart';
import 'package:mte_data_center/src/features/performance/presentation/performance_page.dart';
import 'package:mte_data_center/src/features/proker/presentation/proker_booster_page.dart';
import 'package:mte_data_center/src/features/proker/presentation/proker_injector_page.dart';
import 'package:mte_data_center/src/features/proker/presentation/proker_primer_page.dart';
import 'package:mte_data_center/src/features/proker/presentation/proker_thermostat_page.dart';
import 'package:mte_data_center/src/features/riwayat/presentation/riwayat_detail_page.dart';
import 'package:mte_data_center/src/features/riwayat/presentation/riwayat_page.dart';
import 'package:mte_data_center/src/features/timeline/presentation/timeline_page.dart';
import 'package:mte_data_center/src/features/yazu/presentation/yazu_page.dart';

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
      GoRoute(path: '/performance', builder: (c, s) => const PerformancePage()),
      GoRoute(path: '/timeline', builder: (c, s) => const TimelinePage()),
      GoRoute(path: '/ppm', builder: (c, s) => const PpmPage()),
      GoRoute(path: '/hourmeter', builder: (c, s) => const HourmeterPage()),
      GoRoute(path: '/yazu', builder: (c, s) => const YazuPage()),
      GoRoute(path: '/yazudc', builder: (c, s) => const YazuDailyCheckPage()),
      GoRoute(path: '/ewacs', builder: (c, s) => const EwacsPage()),
      GoRoute(path: '/riwayat', builder: (c, s) => const RiwayatPage()),
      GoRoute(path: '/project', builder: (c, s) => const ProjectPageList()),
      GoRoute(
          path: '/riwayat/:id',
          builder: (c, s) => RiwayatDetailPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/measurement', builder: (c, s) => const MeasurementPage()),
      GoRoute(path: '/tarsupport', builder: (c, s) => const TarSupportPage()),
      GoRoute(path: '/equipment', builder: (c, s) => const EquipmentPage()),
      GoRoute(path: '/equipment/new', builder: (c, s) => const EquipmentFormPage()),
      GoRoute(
          path: '/equipment/:cn',
          builder: (c, s) => EquipmentDetailPage(cn: s.pathParameters['cn']!)),
      GoRoute(
          path: '/equipment/:cn/edit',
          builder: (c, s) => EquipmentFormPage(cn: s.pathParameters['cn']!)),
      GoRoute(path: '/fui', builder: (c, s) => const FuiPage()),
      GoRoute(path: '/ss', builder: (c, s) => const SsPage()),
      GoRoute(path: '/ssab', builder: (c, s) => const SsabPage()),
      GoRoute(path: '/proker', builder: (c, s) => const ProkerPrimerPage()),
      GoRoute(
          path: '/prokerbooster', builder: (c, s) => const ProkerBoosterPage()),
      GoRoute(
          path: '/prokerinjector',
          builder: (c, s) => const ProkerInjectorPage()),
      GoRoute(
          path: '/prokerthermo',
          builder: (c, s) => const ProkerThermostatPage()),
      GoRoute(path: '/suggestion', builder: (c, s) => const SuggestionPage()),
      GoRoute(
        path: '/suggestion/new',
        builder: (c, s) {
          final q = s.uri.queryParameters;
          return SuggestFormPage(
            labNo: q['lab_no'] ?? '',
            vesselId: q['vesselid'] ?? '',
            unitId: q['unit_id'] ?? '',
            condition: q['condition'] ?? '',
          );
        },
      ),
      GoRoute(path: '/report-followup', builder: (c, s) => const ReportFollowUpPage()),
      GoRoute(
        path: '/report-followup/history',
        builder: (c, s) =>
            SuggestHistoryPage(labNo: s.uri.queryParameters['lab_no'] ?? ''),
      ),
      GoRoute(path: '/activity', builder: (c, s) => const ActivityPage()),
      GoRoute(
        path: '/activity/new',
        builder: (c, s) => ActivityFormPage(initialDate: s.uri.queryParameters['date']),
      ),
      GoRoute(path: '/activity/:id', builder: (c, s) => ActivityDetailPage(id: s.pathParameters['id']!)),
      GoRoute(
          path: '/activity/:id/edit',
          builder: (c, s) => ActivityFormPage(id: s.pathParameters['id']!)),
      GoRoute(path: '/bomak', builder: (c, s) => const SafetyPage()),
      GoRoute(path: '/mom', builder: (c, s) => const MomPage()),
      GoRoute(path: '/update-data', builder: (c, s) => const UpdateDataPage()),
      GoRoute(path: '/users', builder: (c, s) => const UsersPage()),
      GoRoute(path: '/audit', builder: (c, s) => const AuditPage()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfilePage()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsPage()),
    ],
  );
});
