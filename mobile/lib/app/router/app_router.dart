import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/router/app_shell.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/chat/presentation/views/chat_view.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_args.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_args.dart';

/// Builds the app router.
///
/// [home], [login], [transactions], [entries] and [accounts] are the screens that need
/// their own ViewModel, so the caller builds them (the app with its DI
/// container, tests with fakes). The same for the two detail screens, which
/// get what the list handed over (or `null` when they were opened without it).
///
/// [redirect] and [refreshListenable] are the hook for the auth redirect, see
/// [sessionRedirect]: the session state decides between login and the tabs,
/// and the router re-checks it when the listenable fires.
GoRouter createAppRouter({
  required Widget home,
  required Widget login,
  required Widget transactions,
  required Widget entries,
  required Widget accounts,
  required Widget Function(TransactionDetailArgs? args) transactionDetail,
  required Widget Function(EntryDetailArgs? args) entryDetail,
  String initialLocation = AppRoutes.home,
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) {
  // The detail screens open on this navigator, over the tabs.
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(path: AppRoutes.login, builder: (context, state) => login),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.home, home),
          _branch(
            AppRoutes.transactions,
            transactions,
            subRoutes: [
              GoRoute(
                path: 'detail',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    transactionDetail(switch (state.extra) {
                      final TransactionDetailArgs args => args,
                      _ => null,
                    }),
              ),
            ],
          ),
          _branch(
            AppRoutes.entries,
            entries,
            subRoutes: [
              GoRoute(
                path: 'detail',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => entryDetail(switch (state.extra) {
                  final EntryDetailArgs args => args,
                  _ => null,
                }),
              ),
            ],
          ),
          _branch(AppRoutes.accounts, accounts),
          _branch(AppRoutes.chat, const ChatView()),
        ],
      ),
    ],
  );
}

/// Without a session everything goes to the login screen. With one, the login
/// screen goes to the home.
GoRouterRedirect sessionRedirect(SessionController session) =>
    (context, state) {
      final atLogin = state.matchedLocation == AppRoutes.login;
      if (!session.isLoggedIn) return atLogin ? null : AppRoutes.login;
      return atLogin ? AppRoutes.home : null;
    };

StatefulShellBranch _branch(
  String path,
  Widget view, {
  List<RouteBase> subRoutes = const [],
}) => StatefulShellBranch(
  routes: [
    GoRoute(path: path, builder: (context, state) => view, routes: subRoutes),
  ],
);
