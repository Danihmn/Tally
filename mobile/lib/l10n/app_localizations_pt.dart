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
  String get loginTitle => 'Entre na sua conta';

  @override
  String get loginSubtitle =>
      'Veja o dinheiro da casa em um só lugar, sem planilha.';

  @override
  String get loginEmail => 'E-mail';

  @override
  String get loginPassword => 'Senha';

  @override
  String get loginShowPassword => 'Mostrar senha';

  @override
  String get loginHidePassword => 'Ocultar senha';

  @override
  String get loginSubmit => 'Entrar';

  @override
  String get loginSubmitting => 'Entrando…';

  @override
  String get loginSessionExpired => 'Sua sessão expirou, entre novamente.';

  @override
  String get loginWrongCredentials =>
      'E-mail ou senha incorretos. Confira e tente de novo.';

  @override
  String get loginMissingFields => 'Digite o e-mail e a senha para entrar.';

  @override
  String get loginAdminNote =>
      'As contas são criadas por um administrador da casa, dentro do app.';

  @override
  String homeGreeting(String name) {
    return 'Olá, $name';
  }

  @override
  String get homeRefresh => 'Atualizar dados';

  @override
  String get homeProfileMenu => 'Abrir perfil e configurações';

  @override
  String get homeLogout => 'Sair';

  @override
  String get scopeLabel => 'Quem aparece';

  @override
  String get scopeMe => 'Eu';

  @override
  String get scopeHouse => 'Casa';

  @override
  String get monthPrevious => 'Mês anterior';

  @override
  String get monthNext => 'Próximo mês';

  @override
  String get homeAskTitle => 'Perguntar ao Tally';

  @override
  String get homeAskSubtitle => 'Quanto cada pessoa da casa gastou?';

  @override
  String homeSpentIn(String month) {
    return 'Gasto em $month';
  }

  @override
  String homeAverageUntil(String average, String date) {
    return 'Média de $average por dia · até $date';
  }

  @override
  String homeAverage(String average) {
    return 'Média de $average por dia';
  }

  @override
  String get homeNoSpendYet => 'Nenhum gasto neste mês ainda';

  @override
  String get homeReceived => 'Recebido';

  @override
  String get homeBalance => 'Saldo do mês';

  @override
  String get planningTitle => 'Planejado × real';

  @override
  String get planningPlanned => 'Despesas planejadas';

  @override
  String get planningReal => 'Já conciliado';

  @override
  String get planningBarLabel => 'Despesas conciliadas';

  @override
  String planningCount(int reconciled, int total) {
    return '$reconciled de $total lançamentos conciliados';
  }

  @override
  String get attentionTitle => 'Precisa de atenção';

  @override
  String attentionUnreconciled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lançamentos sem conciliar',
      one: '1 lançamento sem conciliar',
    );
    return '$_temp0';
  }

  @override
  String get attentionUnreconciledHint =>
      'Confira se já aparecem no extrato do banco.';

  @override
  String get membersTitle => 'Gastos por pessoa';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String membersYou(String name) {
    return '$name (você)';
  }

  @override
  String get dailyTitle => 'Gasto por dia';

  @override
  String dailyAverage(String average) {
    return 'Média $average';
  }

  @override
  String get dailyChartLabel => 'Gastos diários do mês';

  @override
  String get topExpensesTitle => 'Onde mais gastamos';

  @override
  String get topExpensesNoDescription => 'Sem descrição';

  @override
  String get upcomingTitle => 'Próximos lançamentos';

  @override
  String get upcomingSeeAll => 'Ver todos';

  @override
  String get upcomingEmpty => 'Nenhum lançamento a vencer nos próximos dias.';

  @override
  String get upcomingToday => 'Vence hoje';

  @override
  String upcomingInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'em $days dias',
      one: 'em 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get noSpendTitle => 'Ainda não há gastos neste mês';

  @override
  String get noSpendMessage =>
      'Quando o mês começar, as transações importadas aparecem aqui. Os lançamentos planejados já estão logo abaixo.';

  @override
  String get configErrorTitle => 'Configuração ausente';

  @override
  String get configErrorMessage =>
      'O app não foi iniciado com uma URL de API válida. Rode com --dart-define=API_BASE_URL=<url>.';
}
