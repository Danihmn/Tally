import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/router/app_shell.dart';
import 'package:mobile/features/accounts/presentation/views/accounts_view.dart';
import 'package:mobile/features/chat/presentation/views/chat_view.dart';
import 'package:mobile/features/entries/presentation/views/entries_view.dart';
import 'package:mobile/features/home/presentation/views/home_view.dart';
import 'package:mobile/features/transactions/presentation/views/transactions_view.dart';

/// Builds the app router.
///
/// [redirect] and [refreshListenable] are the hook for the auth redirect
/// (phase 2): the session state decides between login and the tabs, and the
/// router re-checks it when the listenable fires.
GoRouter createAppRouter({
  String initialLocation = AppRoutes.home,
  GoRouterRedirect? redirect,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: redirect,
    refreshListenable: refreshListenable,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.home, const HomeView()),
          _branch(AppRoutes.transactions, const TransactionsView()),
          _branch(AppRoutes.entries, const EntriesView()),
          _branch(AppRoutes.accounts, const AccountsView()),
          _branch(AppRoutes.chat, const ChatView()),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget view) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => view)],
);
