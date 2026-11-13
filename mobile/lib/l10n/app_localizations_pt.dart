// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Tally';

  @override
  String get navHome => 'Início';

  @override
  String get navTransactions => 'Transações';

  @override
  String get navEntries => 'Lançamentos';

  @override
  String get navAccounts => 'Contas';

  @override
  String get navChat => 'Tally IA';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get emptyTitle => 'Nada por aqui ainda';

  @override
  String get emptyMessage => 'Quando houver dados, eles aparecem aqui.';

  @override
  String get comingSoon => 'Em construção';

  @override
  String get comingSoonMessage => 'Esta tela chega nas próximas etapas.';

  @override
  String get offlineBanner =>
      'Você está sem conexão. Mostrando o que já foi carregado.';

  @override
  String get loadMoreError => 'Não foi possível carregar mais.';

  @override
  String get failureUnauthorized => 'Sua sessão expirou, entre novamente.';

  @override
  String get failureNotFound => 'Não encontramos esse registro.';

  @override
  String get failureConflict => 'Esse registro já existe.';

  @override
  String get failureValidation =>
      'Confira os dados informados e tente de novo.';

  @override
  String get failureServer =>
      'Serviço indisponível. Tente novamente em instantes.';

  @override
  String get failureNetwork =>
      'Sem conexão. Verifique sua internet e tente de novo.';

  @override
  String get failureTimeout => 'A resposta demorou demais. Tente novamente.';

  @override
  String get failureUnknown => 'Algo deu errado. Tente novamente.';

  @override
  String get configErrorTitle => 'Configuração ausente';

  @override
  String get configErrorMessage =>
      'O app não foi iniciado com uma URL de API válida. Rode com --dart-define=API_BASE_URL=<url>.';
}
