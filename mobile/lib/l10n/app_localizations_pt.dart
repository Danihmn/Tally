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
  String get transactionsSearchHint => 'Buscar na descrição';

  @override
  String get transactionsSearchLabel => 'Buscar nas transações';

  @override
  String get transactionsClearSearch => 'Limpar busca';

  @override
  String get transactionsFilterButton => 'Abrir filtros';

  @override
  String transactionsRemoveFilter(String label) {
    return 'Remover filtro $label';
  }

  @override
  String transactionsShowing(int shown, int total) {
    return 'Mostrando $shown de $total';
  }

  @override
  String get transactionsRefresh => 'Atualizar';

  @override
  String get transactionsLoadingMore => 'Carregando mais transações…';

  @override
  String get transactionsEnd => 'Fim da lista';

  @override
  String get transactionsEmptyTitle => 'Nenhuma transação encontrada';

  @override
  String get transactionsEmptyFiltered =>
      'Tente outro termo de busca ou remova alguns filtros.';

  @override
  String get transactionsEmptyPlain =>
      'Quando houver transações, elas aparecem aqui.';

  @override
  String get transactionsClearAll => 'Limpar busca e filtros';

  @override
  String transactionsNoBankTitle(String who) {
    return '$who ainda não conectou um banco';
  }

  @override
  String get transactionsNoBankMessage =>
      'Sem conexão, não há transações para mostrar. Conecte uma conta pelo Meu Pluggy para importar os dados automaticamente.';

  @override
  String get transactionsSeeAccounts => 'Ver contas e conexões';

  @override
  String get transactionsTheHouse => 'A casa';

  @override
  String get transactionsNoDescription => 'Sem descrição';

  @override
  String get dayToday => 'Hoje';

  @override
  String get dayYesterday => 'Ontem';

  @override
  String get transactionPending => 'Pendente';

  @override
  String get transactionPosted => 'Efetivada';

  @override
  String get filtersTitle => 'Filtrar transações';

  @override
  String get filterPerson => 'Pessoa';

  @override
  String get filterAccount => 'Conta ou cartão';

  @override
  String get filterAllAccounts => 'Todas';

  @override
  String get filterPeriod => 'Período';

  @override
  String get filterFrom => 'De';

  @override
  String get filterTo => 'Até';

  @override
  String get filterDateHint => 'dd/mm/aaaa';

  @override
  String get filterDateInvalid => 'Use o formato dd/mm/aaaa.';

  @override
  String get filterDatesOutOfOrder => 'A data inicial deve vir antes da final.';

  @override
  String get filterType => 'Tipo';

  @override
  String get filterAll => 'Todos';

  @override
  String get filterDebit => 'Débito';

  @override
  String get filterCredit => 'Crédito';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterAmount => 'Valor';

  @override
  String get filterMin => 'Mínimo';

  @override
  String get filterMax => 'Máximo';

  @override
  String get filterAmountHint => '0,00';

  @override
  String get filterAmountInvalid => 'Informe um valor válido.';

  @override
  String get filterAmountsOutOfOrder => 'O mínimo deve ser menor que o máximo.';

  @override
  String get filterApply => 'Aplicar filtros';

  @override
  String get filterReset => 'Limpar';

  @override
  String get chipDebits => 'Débitos';

  @override
  String get chipCredits => 'Créditos';

  @override
  String get chipPending => 'Pendentes';

  @override
  String get chipPosted => 'Efetivadas';

  @override
  String chipMin(String amount) {
    return 'Mín. $amount';
  }

  @override
  String chipMax(String amount) {
    return 'Máx. $amount';
  }

  @override
  String chipFrom(String date) {
    return 'De $date';
  }

  @override
  String chipTo(String date) {
    return 'Até $date';
  }

  @override
  String get detailTitle => 'Transação';

  @override
  String get detailDate => 'Data';

  @override
  String get detailDescription => 'Descrição';

  @override
  String get detailCategory => 'Categoria';

  @override
  String get detailMerchant => 'Estabelecimento';

  @override
  String get detailAccount => 'Conta';

  @override
  String get detailHolder => 'Titular';

  @override
  String get detailType => 'Tipo';

  @override
  String get detailStatus => 'Status';

  @override
  String get detailBalanceAfter => 'Saldo após';

  @override
  String get detailMissing => 'Não foi possível abrir esta transação.';

  @override
  String get detailBack => 'Voltar para a lista';

  @override
  String get entriesSearchHint => 'Buscar lançamento';

  @override
  String get entriesTabPlanned => 'Planejados';

  @override
  String get entriesTabReconciled => 'Conciliados';

  @override
  String get entriesTabCancelled => 'Cancelados';

  @override
  String get entriesMonthAll => 'Todos';

  @override
  String entriesShowing(int shown, int total) {
    return 'Mostrando $shown de $total';
  }

  @override
  String get entriesLoadingMore => 'Carregando mais lançamentos…';

  @override
  String get entriesEnd => 'Fim da lista';

  @override
  String get entriesEmptyTitlePlanned => 'Nenhum lançamento planejado';

  @override
  String get entriesEmptyTitleReconciled => 'Nenhum lançamento conciliado';

  @override
  String get entriesEmptyTitleCancelled => 'Nenhum lançamento cancelado';

  @override
  String entriesEmptyInMonth(String title, String month) {
    return '$title em $month';
  }

  @override
  String get entriesEmptyPlain =>
      'Quando houver lançamentos aqui, eles aparecem nesta lista.';

  @override
  String get entriesEmptyFiltered =>
      'Tente outro termo de busca, outro mês ou remova alguns filtros.';

  @override
  String get entryStatusPlanned => 'Planejado';

  @override
  String get entryStatusOverdue => 'Vencido';

  @override
  String get entryStatusReconciled => 'Conciliado';

  @override
  String get entryStatusCancelled => 'Cancelado';

  @override
  String get entryTypeRevenue => 'Receita';

  @override
  String get entryTypeExpense => 'Despesa';

  @override
  String get entryPayDebit => 'Débito';

  @override
  String get entryPayCredit => 'Crédito';

  @override
  String entryDue(String date) {
    return 'Venc. $date';
  }

  @override
  String entryRef(String month) {
    return 'Ref. $month';
  }

  @override
  String get entriesFiltersTitle => 'Filtrar lançamentos';

  @override
  String get entriesFilterPayment => 'Pagamento';

  @override
  String get entriesFilterDue => 'Vencimento';

  @override
  String get chipRevenues => 'Receitas';

  @override
  String get chipExpenses => 'Despesas';

  @override
  String chipDueFrom(String date) {
    return 'Venc. de $date';
  }

  @override
  String chipDueTo(String date) {
    return 'Venc. até $date';
  }

  @override
  String get entryDetailTitle => 'Lançamento';

  @override
  String get entryDetailReference => 'Mês de referência';

  @override
  String get entryDetailDue => 'Vencimento';

  @override
  String get entryDetailInstallment => 'Parcela';

  @override
  String entryDetailInstallmentOf(int number, int total) {
    return '$number de $total';
  }

  @override
  String get entryDetailNotes => 'Observações';

  @override
  String get entryDetailPayment => 'Pagamento';

  @override
  String get entryDetailMissing => 'Não foi possível abrir este lançamento.';

  @override
  String get entryTimelineCreated => 'Criado';

  @override
  String entryTimelineCreatedBy(String date, String name) {
    return '$date · por $name';
  }

  @override
  String get entryTimelinePlanned => 'Planejado';

  @override
  String entryTimelineDueOn(String date) {
    return 'Vence em $date';
  }

  @override
  String get entryTimelineNoDue => 'Sem data de vencimento';

  @override
  String get entryTimelineReconciled => 'Conciliado';

  @override
  String get entryTimelineReconciledText =>
      'Vinculado a uma transação do banco.';

  @override
  String get entryTimelineCancelled => 'Cancelado';

  @override
  String get entryTimelineCancelledText => 'Não será cobrado nem conciliado.';

  @override
  String get entryTimelineWaiting => 'Aguardando conciliação';

  @override
  String get entryTimelineWaitingText =>
      'Quando a transação aparecer no banco, ela será ligada a este lançamento.';

  @override
  String get linkedTransactionTitle => 'Transação do banco';

  @override
  String get linkedEntryTitle => 'Lançamento vinculado';

  @override
  String get linkedEntryNone => 'Sem lançamento';

  @override
  String get linkedEntryNoneText =>
      'Esta transação ainda não foi ligada a nada que vocês planejaram.';

  @override
  String get linkedTransactionNone =>
      'Nenhuma transação ligada a este lançamento ainda.';

  @override
  String get linkedLoadError => 'Não foi possível carregar o vínculo.';

  @override
  String get accountsTotalTitle => 'Saldo total em contas';

  @override
  String accountsBills(String amount) {
    return 'Faturas abertas nos cartões: $amount';
  }

  @override
  String get accountsNoCards => 'Sem cartões conectados';

  @override
  String get accountsTabBanks => 'Contas bancárias';

  @override
  String get accountsTabCards => 'Cartões de crédito';

  @override
  String get accountBalanceLabel => 'Saldo atual';

  @override
  String get accountBillLabel => 'Fatura atual';

  @override
  String accountSubBank(String number) {
    return 'Conta •••• $number';
  }

  @override
  String accountSubCard(String number) {
    return 'Cartão •••• $number';
  }

  @override
  String accountCardUsed(int percent) {
    return 'Usado $percent%';
  }

  @override
  String accountCardLimit(String amount) {
    return 'Limite $amount';
  }

  @override
  String accountCardAvailable(String amount) {
    return 'Disponível $amount';
  }

  @override
  String get accountSeeTransactions => 'Ver transações';

  @override
  String accountsEmptyNoBankTitle(String who) {
    return '$who ainda não conectou nenhum banco';
  }

  @override
  String get accountsEmptyNoBankText =>
      'Conecte um banco pelo Meu Pluggy para ver contas e cartões aqui.';

  @override
  String get accountsEmptyBanks => 'Nenhuma conta bancária';

  @override
  String get accountsEmptyCards => 'Nenhum cartão de crédito';

  @override
  String get accountsEmptyKindText =>
      'Não há itens deste tipo conectados para esta seleção.';

  @override
  String get accountsTotalsError => 'Não foi possível carregar os totais.';

  @override
  String get configErrorTitle => 'Configuração ausente';

  @override
  String get configErrorMessage =>
      'O app não foi iniciado com uma URL de API válida. Rode com --dart-define=API_BASE_URL=<url>.';
}
