import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/config_error_app.dart';
import 'package:mobile/app/di/injection.dart';
import 'package:mobile/app/router/app_router.dart';
import 'package:mobile/app/theme/theme_controller.dart';
import 'package:mobile/core/config/app_config.dart';

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

  runApp(
    TallyApp(
      router: createAppRouter(),
      themeController: getIt<ThemeController>(),
    ),
  );
}
