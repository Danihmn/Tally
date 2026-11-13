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
import 'package:mobile/features/auth/presentation/viewmodels/login_view_model.dart';
import 'package:mobile/features/auth/presentation/views/login_view.dart';
import 'package:mobile/features/home/presentation/views/home_view.dart';

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
        home: const HomeView(),
        login: LoginView(
          createViewModel: () => getIt<LoginViewModel>(),
          session: session,
        ),
        initialLocation: session.isLoggedIn ? AppRoutes.home : AppRoutes.login,
        redirect: sessionRedirect(session),
        refreshListenable: session,
      ),
      themeController: getIt<ThemeController>(),
    ),
  );
}
