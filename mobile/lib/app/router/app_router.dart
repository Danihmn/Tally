import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/router/app_shell.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/accounts/presentation/views/accounts_view.dart';
import 'package:mobile/features/chat/presentation/views/chat_view.dart';
import 'package:mobile/features/entries/presentation/views/entries_view.dart';
import 'package:mobile/features/transactions/presentation/views/transactions_view.dart';

/// Builds the app router.
///
/// [home] and [login] are the two screens that need their own ViewModel, so
/// the caller builds them (the app with its DI container, tests with fakes).
///
/// [redirect] and [refreshListenable] are the hook for the auth redirect, see
/// [sessionRedirect]: the session state decides between login and the tabs,
/// and the router re-checks it when the listenable fires.
GoRouter createAppRouter({
  required Widget home,
  required Widget login,
  String initialLocation = AppRoutes.home,
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: [
      GoRoute(path: AppRoutes.login, builder: (context, state) => login),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.home, home),
          _branch(AppRoutes.transactions, const TransactionsView()),
          _branch(AppRoutes.entries, const EntriesView()),
          _branch(AppRoutes.accounts, const AccountsView()),
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

StatefulShellBranch _branch(String path, Widget view) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => view)],
);
