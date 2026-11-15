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
  String get navEntries => 'Planejamento';

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
  String get accountSalaryTitle => 'Conta salário';

  @override
  String get accountSalaryText =>
      'TEDs que saem dela para suas contas contam como recebido';

  @override
  String accountSalaryBank(String code) {
    return 'Banco $code';
  }

  @override
  String get accountSalaryEditCode => 'Alterar código do banco';

  @override
  String get salaryConfirmOnTitle => 'Marcar como conta salário?';

  @override
  String salaryConfirmOnText(String account) {
    return 'Os TEDs que saem de $account para as suas contas passam a contar como recebido. As transferências da casa serão reclassificadas, o que pode levar alguns instantes.';
  }

  @override
  String get salaryConfirmOffTitle => 'Desmarcar conta salário?';

  @override
  String salaryConfirmOffText(String account) {
    return 'Os TEDs que saem de $account para as suas contas voltam a ser transferências internas. As transferências da casa serão reclassificadas, o que pode levar alguns instantes.';
  }

  @override
  String get salaryConfirmCancel => 'Cancelar';

  @override
  String get salaryConfirmOk => 'Confirmar';

  @override
  String get bankCodeDialogTitle => 'Código do banco';

  @override
  String get bankCodeDialogText =>
      'O código de 3 dígitos do banco da conta salário (por exemplo, 001 para o Banco do Brasil). Os TEDs com o seu CPF vindos desse banco passam a contar como recebido.';

  @override
  String get bankCodeDialogLabel => 'Código do banco';

  @override
  String get bankCodeDialogCancel => 'Cancelar';

  @override
  String get bankCodeDialogConfirm => 'Salvar';

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

  @override
  String get failureConversationFull =>
      'Esta conversa atingiu o limite. Inicie uma nova conversa.';

  @override
  String get chatNewConversation => 'Nova conversa';

  @override
  String get chatHistory => 'Histórico de conversas';

  @override
  String get chatEmptyTitle => 'Pergunte sobre o dinheiro da casa';

  @override
  String get chatEmptySubtitle =>
      'Eu consulto transações, lançamentos, contas e cartões e respondo em linguagem simples.';

  @override
  String get chatSuggestion1 => 'Quanto gastei este mês?';

  @override
  String get chatSuggestion2 => 'Quanto cada pessoa da casa gastou?';

  @override
  String get chatSuggestion3 => 'Quais são meus próximos lançamentos?';

  @override
  String get chatSuggestion4 => 'Qual o saldo das nossas contas?';

  @override
  String get chatSuggestion5 => 'Quanto gastei em mercado?';

  @override
  String get chatSuggestion6 => 'Quais cartões temos e qual o limite?';

  @override
  String get chatInputHint => 'Pergunte ao Tally…';

  @override
  String get chatSend => 'Enviar mensagem';

  @override
  String get chatCaption =>
      'O Tally IA pode errar. Confira os valores importantes.';

  @override
  String get chatHistorySaved =>
      'O histórico das conversas fica salvo e você pode continuar depois.';

  @override
  String get chatTyping => 'Digitando… consultando seus dados';

  @override
  String get chatErrorMessage => 'Não consegui responder agora.';

  @override
  String get chatErrorRetry => 'Tentar de novo';

  @override
  String get chatWarning =>
      'A conversa está chegando ao limite. Considere iniciar uma nova conversa.';

  @override
  String get chatFullTitle => 'Conversa cheia';

  @override
  String get chatFullMessage =>
      'Esta conversa atingiu o limite e agora é só de leitura.';

  @override
  String get chatStartNew => 'Iniciar nova conversa';

  @override
  String chatCounter(int count, int max) {
    return '$count/$max';
  }

  @override
  String get chatYou => 'Você';

  @override
  String get chatAssistant => 'Tally IA';

  @override
  String get conversationsTitle => 'Histórico';

  @override
  String get conversationsBack => 'Voltar ao chat';

  @override
  String get conversationsEmptyTitle => 'Nenhuma conversa ainda';

  @override
  String get conversationsEmptyMessage =>
      'Quando você perguntar algo ao Tally IA, a conversa aparece aqui.';

  @override
  String get conversationUntitled => 'Conversa sem título';

  @override
  String conversationUsage(int percent) {
    return '$percent% do limite';
  }

  @override
  String get failureNoRecurrences =>
      'Cadastre ao menos uma recorrência antes de provisionar o mês.';

  @override
  String get planningSectionEntries => 'Lançamentos';

  @override
  String get planningSectionRecurrences => 'Recorrências';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get formRequired => 'Preencha este campo.';

  @override
  String get formAmountInvalid => 'Digite um valor maior que zero.';

  @override
  String get formDueDayInvalid => 'Digite um dia de 1 a 31.';

  @override
  String get formInstallmentsInvalid =>
      'Preencha as duas parcelas, com a atual menor ou igual ao total.';

  @override
  String get formOptional => 'Opcional';

  @override
  String get entryNew => 'Novo lançamento';

  @override
  String get entryEditTitle => 'Editar lançamento';

  @override
  String get entryFormSave => 'Salvar lançamento';

  @override
  String get entryFormDescription => 'Descrição';

  @override
  String get entryFormDescriptionHint => 'Ex.: Conta de luz';

  @override
  String get entryFormType => 'Tipo';

  @override
  String get entryFormPayment => 'Forma de pagamento';

  @override
  String get entryFormCategory => 'Categoria';

  @override
  String get entryFormCategoryHint => 'Ex.: Moradia';

  @override
  String get entryFormAmount => 'Valor';

  @override
  String get entryFormMonth => 'Mês de referência';

  @override
  String get entryFormDue => 'Vencimento';

  @override
  String get entryFormAccount => 'Conta ou cartão';

  @override
  String get entryFormNoAccount => 'Nenhuma';

  @override
  String get entryFormInstallments => 'Parcelas';

  @override
  String get entryFormInstallmentCurrent => 'Parcela atual';

  @override
  String get entryFormInstallmentTotal => 'Total de parcelas';

  @override
  String get entryFormInstallmentsHint =>
      'Preencha as duas, ou deixe as duas em branco.';

  @override
  String get entryFormNotes => 'Observações';

  @override
  String get entryFormNotesHint => 'Algo que ajude a lembrar';

  @override
  String get entryActionEdit => 'Editar';

  @override
  String get entryActionCancel => 'Cancelar lançamento';

  @override
  String get entryActionReopen => 'Reativar lançamento';

  @override
  String get entryActionDelete => 'Excluir lançamento';

  @override
  String get entryReconciledLocked =>
      'Lançamento conciliado não pode ser editado nem excluído. Desfaça a conciliação antes.';

  @override
  String get entryDeleteTitle => 'Excluir lançamento?';

  @override
  String entryDeleteText(String name) {
    return '\"$name\" sai da lista. Essa ação não pode ser desfeita.';
  }

  @override
  String get entryDeleteConfirm => 'Excluir';

  @override
  String get entrySaved => 'Lançamento salvo.';

  @override
  String get entryCancelledDone => 'Lançamento cancelado.';

  @override
  String get entryReopenedDone => 'Lançamento reativado.';

  @override
  String get entryDeletedDone => 'Lançamento excluído.';

  @override
  String get recurrencesIntro =>
      'Itens que se repetem todo mês. O Tally cria o lançamento no mês certo para vocês.';

  @override
  String get recurrencesEmptyTitle => 'Nenhuma recorrência ainda';

  @override
  String get recurrencesEmptyText =>
      'Cadastre aluguel, assinaturas e salários para não digitar todo mês.';

  @override
  String get recurrenceNew => 'Nova recorrência';

  @override
  String get recurrenceEditTitle => 'Editar recorrência';

  @override
  String get recurrenceFormSave => 'Salvar recorrência';

  @override
  String get recurrenceFormDay => 'Dia do mês';

  @override
  String get recurrenceFormDayHint =>
      'Todo mês neste dia. Em meses mais curtos vale o último dia.';

  @override
  String recurrenceDay(int day) {
    return 'Todo dia $day';
  }

  @override
  String get recurrenceNoDay => 'Sem dia fixo';

  @override
  String get recurrenceDeleteAction => 'Excluir recorrência';

  @override
  String get recurrenceDeleteTitle => 'Excluir recorrência?';

  @override
  String recurrenceDeleteText(String name) {
    return '\"$name\" deixa de gerar lançamentos. Os que já foram criados continuam.';
  }

  @override
  String get recurrenceSaved => 'Recorrência salva.';

  @override
  String get recurrenceDeletedDone => 'Recorrência excluída.';

  @override
  String provisionButton(String month) {
    return 'Provisionar $month';
  }

  @override
  String get provisionTitle => 'Provisionar o próximo mês?';

  @override
  String provisionText(String month) {
    return 'O Tally vai criar os lançamentos de $month a partir das recorrências cadastradas. Quem já tem lançamento nesse mês não é duplicado.';
  }

  @override
  String get provisionConfirm => 'Provisionar';

  @override
  String provisionCreated(int created, String month) {
    String _temp0 = intl.Intl.pluralLogic(
      created,
      locale: localeName,
      other: '$created lançamentos criados em $month.',
      one: '1 lançamento criado em $month.',
    );
    return '$_temp0';
  }

  @override
  String provisionNothingNew(String month) {
    return 'Tudo já estava provisionado em $month.';
  }

  @override
  String get recurrenceFormDescriptionHint => 'Ex.: Aluguel';

  @override
  String get recurrenceFormDayExample => '5';

  @override
  String get homeSettings => 'Configurações';

  @override
  String get failureEmailExists => 'Já existe um usuário com esse e-mail.';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemeSystem => 'Sistema';

  @override
  String get settingsHousehold => 'Casa';

  @override
  String get settingsUsers => 'Usuários';

  @override
  String get settingsUsersHint => 'Quem usa o Tally nesta casa';

  @override
  String get usersTitle => 'Usuários';

  @override
  String get usersNew => 'Novo usuário';

  @override
  String get usersAddedNotice => 'Usuário criado.';

  @override
  String get userDetailTitle => 'Usuário';

  @override
  String get userEditAction => 'Editar dados';

  @override
  String get userEditTitle => 'Editar usuário';

  @override
  String get userNewTitle => 'Novo usuário';

  @override
  String get userFieldFirstName => 'Nome';

  @override
  String get userFieldLastName => 'Sobrenome';

  @override
  String get userFieldSurname => 'Apelido';

  @override
  String get userFieldSurnameHelp =>
      'É o nome que aparece nos filtros e nas telas.';

  @override
  String get userFieldEmail => 'E-mail';

  @override
  String get userFieldPassword => 'Senha';

  @override
  String get userFieldPasswordHelp => 'Mínimo de 8 caracteres.';

  @override
  String get userNotInformed => 'Não informado';

  @override
  String get userSave => 'Salvar';

  @override
  String get userCreate => 'Criar usuário';

  @override
  String get userSavedNotice => 'Dados salvos.';

  @override
  String get userEmailInvalid => 'Digite um e-mail válido.';

  @override
  String get userPasswordShort => 'Use ao menos 8 caracteres.';

  @override
  String get userPluggySection => 'Credenciais da Pluggy';

  @override
  String get userPluggyAction => 'Credenciais da Pluggy';

  @override
  String get userPluggyIntro =>
      'Cada pessoa usa a própria aplicação da Pluggy. Consulte o Client ID e o Client Secret dela no portal da Pluggy.';

  @override
  String get userPluggyHidden =>
      'Por segurança, as credenciais atuais não são exibidas.';

  @override
  String get pluggyClientId => 'Client ID';

  @override
  String get pluggyClientSecret => 'Client Secret';

  @override
  String get pluggyClientIdInvalid =>
      'Digite um Client ID válido (formato UUID).';

  @override
  String get pluggySave => 'Salvar credenciais';

  @override
  String get pluggyConfirmTitle => 'Alterar as credenciais?';

  @override
  String get pluggyConfirmMessage =>
      'Se as credenciais estiverem erradas, o Tally deixa de importar os dados bancários desta pessoa e o sistema passa a funcionar mal. Confira no portal da Pluggy antes de continuar.';

  @override
  String get pluggyConfirmOk => 'Alterar credenciais';

  @override
  String get pluggySavedNotice => 'Credenciais atualizadas.';
}
