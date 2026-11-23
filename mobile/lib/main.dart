import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/config_error_app.dart';
import 'package:mobile/app/di/injection.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/router/app_routes.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/core/session/session_controller.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/accounts_view_model.dart';
import 'package:mobile/features/accounts/presentation/viewmodels/card_bill_view_model.dart';
import 'package:mobile/features/accounts/presentation/views/accounts_view.dart';
import 'package:mobile/features/accounts/presentation/views/card_bill_view.dart';
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:mobile/features/auth/presentation/views/login_view.dart';
import 'package:mobile/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:mobile/features/chat/presentation/viewmodels/conversations_view_model.dart';
import 'package:mobile/features/chat/presentation/views/chat_view.dart';
import 'package:mobile/features/chat/presentation/views/conversations_view.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entries_view_model.dart';
import 'package:mobile/features/entries/presentation/viewmodels/entry_actions_view_model.dart';
import 'package:mobile/features/entries/presentation/viewmodels/linked_transactions_view_model.dart';
import 'package:mobile/features/entries/presentation/views/entries_view.dart';
import 'package:mobile/features/entries/presentation/views/entry_detail_view.dart';
import 'package:mobile/features/entries/presentation/views/planning_view.dart';
import 'package:mobile/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:mobile/features/home/presentation/views/home_view.dart';
import 'package:mobile/features/household/presentation/viewmodels/users_view_model.dart';
import 'package:mobile/features/household/presentation/views/user_detail_view.dart';
import 'package:mobile/features/household/presentation/views/users_view.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrences_view_model.dart';
import 'package:mobile/features/recurrences/presentation/views/recurrences_view.dart';
import 'package:mobile/features/settings/presentation/widgets/settings_sheet.dart';
import 'package:mobile/features/transactions/domain/transactions_filter_request.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/linked_entries_view_model.dart';
import 'package:mobile/features/transactions/presentation/viewmodels/transactions_view_model.dart';
import 'package:mobile/features/transactions/presentation/views/transaction_detail_view.dart';
import 'package:mobile/features/transactions/presentation/views/transactions_view.dart';

/// Entry point. It only starts things up: config, dependencies, root widget.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on ConfigException {
    runApp(const ConfigErrorApp());
    return;
  }

  await initializeDateFormatting('pt_BR');
  await configureDependencies(config);

  // The router needs to know whether somebody is logged in before it starts.
  final session = getIt<SessionController>();
  await session.restore();

  runApp(
    TallyApp(
      router: createAppRouter(
        home: HomeView(
          createViewModel: () => getIt<HomeViewModel>(),
          onOpenSettings: (context, {required onLogout}) => unawaited(
            SettingsSheet.show(
              context,
              themeController: getIt<ThemeController>(),
              onOpenUsers: () => unawaited(context.push(AppRoutes.users)),
              onLogout: onLogout,
            ),
          ),
        ),
        login: LoginView(
          createViewModel: () => getIt<LoginViewModel>(),
          session: session,
        ),
        transactions: TransactionsView(
          createViewModel: () => getIt<TransactionsViewModel>(),
        ),
        entries: PlanningView(
          entriesBuilder: (initialMonth) => EntriesView(
            createViewModel: () => getIt<EntriesViewModel>(),
            initialMonth: initialMonth,
          ),
          recurrencesBuilder: (onProvisioned) => RecurrencesView(
            createViewModel: () => getIt<RecurrencesViewModel>(),
            onProvisioned: onProvisioned,
          ),
        ),
        accounts: AccountsView(
          createViewModel: () => getIt<AccountsViewModel>(),
          filterRequest: getIt<TransactionsFilterRequest>(),
        ),
        chat: ChatView(createViewModel: () => getIt<ChatViewModel>()),
        conversations: ConversationsView(
          createViewModel: () => getIt<ConversationsViewModel>(),
        ),
        users: UsersView(createViewModel: () => getIt<UsersViewModel>()),
        userDetail: (member) => UserDetailView(
          createViewModel: () => getIt<UsersViewModel>(),
          member: member,
        ),
        transactionDetail: (args) => TransactionDetailView(
          args: args,
          createLinkedViewModel: (id) =>
              getIt<LinkedEntriesViewModel>(param1: id),
        ),
        cardBill: (args) => CardBillView(
          args: args,
          createViewModel: (id) => getIt<CardBillViewModel>(param1: id),
        ),
        entryDetail: (args) => EntryDetailView(
          args: args,
          createLinkedViewModel: (id) =>
              getIt<LinkedTransactionsViewModel>(param1: id),
          createActionsViewModel: () => getIt<EntryActionsViewModel>(),
        ),
        initialLocation: session.isLoggedIn ? AppRoutes.home : AppRoutes.login,
        redirect: sessionRedirect(session),
        refreshListenable: session,
      ),
      themeController: getIt<ThemeController>(),
    ),
  );
}
