import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('pt')];

  /// No description provided for @appName.
  ///
  /// In pt, this message translates to:
  /// **'Tally'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get navHome;

  /// No description provided for @navTransactions.
  ///
  /// In pt, this message translates to:
  /// **'Transações'**
  String get navTransactions;

  /// No description provided for @navEntries.
  ///
  /// In pt, this message translates to:
  /// **'Planejamento'**
  String get navEntries;

  /// No description provided for @navAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Contas'**
  String get navAccounts;

  /// No description provided for @navChat.
  ///
  /// In pt, this message translates to:
  /// **'Tally AI'**
  String get navChat;

  /// No description provided for @retry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retry;

  /// No description provided for @emptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nada por aqui ainda'**
  String get emptyTitle;

  /// No description provided for @emptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Quando houver dados, eles aparecem aqui.'**
  String get emptyMessage;

  /// No description provided for @comingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em construção'**
  String get comingSoon;

  /// No description provided for @comingSoonMessage.
  ///
  /// In pt, this message translates to:
  /// **'Esta tela chega nas próximas etapas.'**
  String get comingSoonMessage;

  /// No description provided for @offlineBanner.
  ///
  /// In pt, this message translates to:
  /// **'Você está sem conexão. Mostrando o que já foi carregado.'**
  String get offlineBanner;

  /// No description provided for @loadMoreError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar mais.'**
  String get loadMoreError;

  /// No description provided for @failureUnauthorized.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou, entre novamente.'**
  String get failureUnauthorized;

  /// No description provided for @failureNotFound.
  ///
  /// In pt, this message translates to:
  /// **'Não encontramos esse registro.'**
  String get failureNotFound;

  /// No description provided for @failureConflict.
  ///
  /// In pt, this message translates to:
  /// **'Esse registro já existe.'**
  String get failureConflict;

  /// No description provided for @failureValidation.
  ///
  /// In pt, this message translates to:
  /// **'Confira os dados informados e tente de novo.'**
  String get failureValidation;

  /// No description provided for @failureServer.
  ///
  /// In pt, this message translates to:
  /// **'Serviço indisponível. Tente novamente em instantes.'**
  String get failureServer;

  /// No description provided for @failureNetwork.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Verifique sua internet e tente de novo.'**
  String get failureNetwork;

  /// No description provided for @failureTimeout.
  ///
  /// In pt, this message translates to:
  /// **'A resposta demorou demais. Tente novamente.'**
  String get failureTimeout;

  /// No description provided for @failureUnknown.
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado. Tente novamente.'**
  String get failureUnknown;

  /// No description provided for @loginTitle.
  ///
  /// In pt, this message translates to:
  /// **'Entre na sua conta'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Veja o dinheiro da casa em um só lugar, sem planilha.'**
  String get loginSubtitle;

  /// No description provided for @loginEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get loginPassword;

  /// No description provided for @loginShowPassword.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar senha'**
  String get loginShowPassword;

  /// No description provided for @loginHidePassword.
  ///
  /// In pt, this message translates to:
  /// **'Ocultar senha'**
  String get loginHidePassword;

  /// No description provided for @loginSubmit.
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get loginSubmit;

  /// No description provided for @loginSubmitting.
  ///
  /// In pt, this message translates to:
  /// **'Entrando…'**
  String get loginSubmitting;

  /// No description provided for @loginSessionExpired.
  ///
  /// In pt, this message translates to:
  /// **'Sua sessão expirou, entre novamente.'**
  String get loginSessionExpired;

  /// No description provided for @loginWrongCredentials.
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou senha incorretos. Confira e tente de novo.'**
  String get loginWrongCredentials;

  /// No description provided for @loginMissingFields.
  ///
  /// In pt, this message translates to:
  /// **'Digite o e-mail e a senha para entrar.'**
  String get loginMissingFields;

  /// No description provided for @loginAdminNote.
  ///
  /// In pt, this message translates to:
  /// **'As contas são criadas por um administrador da casa, dentro do app.'**
  String get loginAdminNote;

  /// No description provided for @homeGreeting.
  ///
  /// In pt, this message translates to:
  /// **'Olá, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeRefresh.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar dados'**
  String get homeRefresh;

  /// No description provided for @homeProfileMenu.
  ///
  /// In pt, this message translates to:
  /// **'Abrir perfil e configurações'**
  String get homeProfileMenu;

  /// No description provided for @homeLogout.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get homeLogout;

  /// No description provided for @scopeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Quem aparece'**
  String get scopeLabel;

  /// No description provided for @scopeMe.
  ///
  /// In pt, this message translates to:
  /// **'Eu'**
  String get scopeMe;

  /// No description provided for @scopeHouse.
  ///
  /// In pt, this message translates to:
  /// **'Casa'**
  String get scopeHouse;

  /// No description provided for @monthPrevious.
  ///
  /// In pt, this message translates to:
  /// **'Mês anterior'**
  String get monthPrevious;

  /// No description provided for @monthNext.
  ///
  /// In pt, this message translates to:
  /// **'Próximo mês'**
  String get monthNext;

  /// No description provided for @homeAskTitle.
  ///
  /// In pt, this message translates to:
  /// **'Perguntar ao Tally'**
  String get homeAskTitle;

  /// No description provided for @homeAskSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Quanto cada pessoa da casa gastou?'**
  String get homeAskSubtitle;

  /// No description provided for @homeSpentIn.
  ///
  /// In pt, this message translates to:
  /// **'Gasto em {month}'**
  String homeSpentIn(String month);

  /// No description provided for @homeAverageUntil.
  ///
  /// In pt, this message translates to:
  /// **'Média de {average} por dia · até {date}'**
  String homeAverageUntil(String average, String date);

  /// No description provided for @homeAverage.
  ///
  /// In pt, this message translates to:
  /// **'Média de {average} por dia'**
  String homeAverage(String average);

  /// No description provided for @homeNoSpendYet.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum gasto neste mês ainda'**
  String get homeNoSpendYet;

  /// No description provided for @homeReceived.
  ///
  /// In pt, this message translates to:
  /// **'Recebido'**
  String get homeReceived;

  /// No description provided for @homeBalance.
  ///
  /// In pt, this message translates to:
  /// **'Saldo do mês'**
  String get homeBalance;

  /// No description provided for @planningTitle.
  ///
  /// In pt, this message translates to:
  /// **'Planejado × real'**
  String get planningTitle;

  /// No description provided for @planningPlanned.
  ///
  /// In pt, this message translates to:
  /// **'Despesas planejadas'**
  String get planningPlanned;

  /// No description provided for @planningReal.
  ///
  /// In pt, this message translates to:
  /// **'Já conciliado'**
  String get planningReal;

  /// No description provided for @planningBarLabel.
  ///
  /// In pt, this message translates to:
  /// **'Despesas conciliadas'**
  String get planningBarLabel;

  /// No description provided for @planningCount.
  ///
  /// In pt, this message translates to:
  /// **'{reconciled} de {total} lançamentos conciliados'**
  String planningCount(int reconciled, int total);

  /// No description provided for @attentionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Precisa de atenção'**
  String get attentionTitle;

  /// No description provided for @attentionUnreconciled.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 lançamento sem conciliar} other{{count} lançamentos sem conciliar}}'**
  String attentionUnreconciled(int count);

  /// No description provided for @attentionUnreconciledHint.
  ///
  /// In pt, this message translates to:
  /// **'Confira se já aparecem no extrato do banco.'**
  String get attentionUnreconciledHint;

  /// No description provided for @membersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gastos por pessoa'**
  String get membersTitle;

  /// No description provided for @membersCount.
  ///
  /// In pt, this message translates to:
  /// **'{count, plural, =1{1 pessoa} other{{count} pessoas}}'**
  String membersCount(int count);

  /// No description provided for @membersYou.
  ///
  /// In pt, this message translates to:
  /// **'{name} (você)'**
  String membersYou(String name);

  /// No description provided for @dailyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Gasto por dia'**
  String get dailyTitle;

  /// No description provided for @dailyAverage.
  ///
  /// In pt, this message translates to:
  /// **'Média {average}'**
  String dailyAverage(String average);

  /// No description provided for @dailyChartLabel.
  ///
  /// In pt, this message translates to:
  /// **'Gastos diários do mês'**
  String get dailyChartLabel;

  /// No description provided for @topExpensesTitle.
  ///
  /// In pt, this message translates to:
  /// **'Onde mais gastamos'**
  String get topExpensesTitle;

  /// No description provided for @topExpensesNoDescription.
  ///
  /// In pt, this message translates to:
  /// **'Sem descrição'**
  String get topExpensesNoDescription;

  /// No description provided for @upcomingTitle.
  ///
  /// In pt, this message translates to:
  /// **'Próximos lançamentos'**
  String get upcomingTitle;

  /// No description provided for @upcomingSeeAll.
  ///
  /// In pt, this message translates to:
  /// **'Ver todos'**
  String get upcomingSeeAll;

  /// No description provided for @upcomingEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum lançamento a vencer nos próximos dias.'**
  String get upcomingEmpty;

  /// No description provided for @upcomingToday.
  ///
  /// In pt, this message translates to:
  /// **'Vence hoje'**
  String get upcomingToday;

  /// No description provided for @upcomingInDays.
  ///
  /// In pt, this message translates to:
  /// **'{days, plural, =1{em 1 dia} other{em {days} dias}}'**
  String upcomingInDays(int days);

  /// No description provided for @noSpendTitle.
  ///
  /// In pt, this message translates to:
  /// **'Ainda não há gastos neste mês'**
  String get noSpendTitle;

  /// No description provided for @noSpendMessage.
  ///
  /// In pt, this message translates to:
  /// **'Quando o mês começar, as transações importadas aparecem aqui. Os lançamentos planejados já estão logo abaixo.'**
  String get noSpendMessage;

  /// No description provided for @transactionsSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar na descrição'**
  String get transactionsSearchHint;

  /// No description provided for @transactionsClearSearch.
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca'**
  String get transactionsClearSearch;

  /// No description provided for @transactionsFilterButton.
  ///
  /// In pt, this message translates to:
  /// **'Abrir filtros'**
  String get transactionsFilterButton;

  /// No description provided for @transactionsRemoveFilter.
  ///
  /// In pt, this message translates to:
  /// **'Remover filtro {label}'**
  String transactionsRemoveFilter(String label);

  /// No description provided for @transactionsShowing.
  ///
  /// In pt, this message translates to:
  /// **'Mostrando {shown} de {total}'**
  String transactionsShowing(int shown, int total);

  /// No description provided for @transactionsRefresh.
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get transactionsRefresh;

  /// No description provided for @transactionsLoadingMore.
  ///
  /// In pt, this message translates to:
  /// **'Carregando mais transações…'**
  String get transactionsLoadingMore;

  /// No description provided for @transactionsEnd.
  ///
  /// In pt, this message translates to:
  /// **'Fim da lista'**
  String get transactionsEnd;

  /// No description provided for @transactionsEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma transação encontrada'**
  String get transactionsEmptyTitle;

  /// No description provided for @transactionsEmptyFiltered.
  ///
  /// In pt, this message translates to:
  /// **'Tente outro termo de busca ou remova alguns filtros.'**
  String get transactionsEmptyFiltered;

  /// No description provided for @transactionsEmptyPlain.
  ///
  /// In pt, this message translates to:
  /// **'Quando houver transações, elas aparecem aqui.'**
  String get transactionsEmptyPlain;

  /// No description provided for @transactionsClearAll.
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca e filtros'**
  String get transactionsClearAll;

  /// No description provided for @transactionsNoBankTitle.
  ///
  /// In pt, this message translates to:
  /// **'{who} ainda não conectou um banco'**
  String transactionsNoBankTitle(String who);

  /// No description provided for @transactionsNoBankMessage.
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão, não há transações para mostrar. Conecte uma conta pelo Meu Pluggy para importar os dados automaticamente.'**
  String get transactionsNoBankMessage;

  /// No description provided for @transactionsSeeAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Ver contas e conexões'**
  String get transactionsSeeAccounts;

  /// No description provided for @transactionsTheHouse.
  ///
  /// In pt, this message translates to:
  /// **'A casa'**
  String get transactionsTheHouse;

  /// No description provided for @transactionsNoDescription.
  ///
  /// In pt, this message translates to:
  /// **'Sem descrição'**
  String get transactionsNoDescription;

  /// No description provided for @dayToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get dayToday;

  /// No description provided for @dayYesterday.
  ///
  /// In pt, this message translates to:
  /// **'Ontem'**
  String get dayYesterday;

  /// No description provided for @transactionPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get transactionPending;

  /// No description provided for @transactionPosted.
  ///
  /// In pt, this message translates to:
  /// **'Efetivada'**
  String get transactionPosted;

  /// No description provided for @filtersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar transações'**
  String get filtersTitle;

  /// No description provided for @filterPerson.
  ///
  /// In pt, this message translates to:
  /// **'Pessoa'**
  String get filterPerson;

  /// No description provided for @filterAccount.
  ///
  /// In pt, this message translates to:
  /// **'Conta ou cartão'**
  String get filterAccount;

  /// No description provided for @filterAllAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Todas'**
  String get filterAllAccounts;

  /// No description provided for @filterPeriod.
  ///
  /// In pt, this message translates to:
  /// **'Período'**
  String get filterPeriod;

  /// No description provided for @filterFrom.
  ///
  /// In pt, this message translates to:
  /// **'De'**
  String get filterFrom;

  /// No description provided for @filterTo.
  ///
  /// In pt, this message translates to:
  /// **'Até'**
  String get filterTo;

  /// No description provided for @filterDateHint.
  ///
  /// In pt, this message translates to:
  /// **'dd/mm/aaaa'**
  String get filterDateHint;

  /// No description provided for @filterDateInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Use o formato dd/mm/aaaa.'**
  String get filterDateInvalid;

  /// No description provided for @filterDatesOutOfOrder.
  ///
  /// In pt, this message translates to:
  /// **'A data inicial deve vir antes da final.'**
  String get filterDatesOutOfOrder;

  /// No description provided for @filterType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get filterType;

  /// No description provided for @filterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @filterDebit.
  ///
  /// In pt, this message translates to:
  /// **'Débito'**
  String get filterDebit;

  /// No description provided for @filterCredit.
  ///
  /// In pt, this message translates to:
  /// **'Crédito'**
  String get filterCredit;

  /// No description provided for @filterStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterAmount.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get filterAmount;

  /// No description provided for @filterMin.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo'**
  String get filterMin;

  /// No description provided for @filterMax.
  ///
  /// In pt, this message translates to:
  /// **'Máximo'**
  String get filterMax;

  /// No description provided for @filterAmountHint.
  ///
  /// In pt, this message translates to:
  /// **'0,00'**
  String get filterAmountHint;

  /// No description provided for @filterAmountInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Informe um valor válido.'**
  String get filterAmountInvalid;

  /// No description provided for @filterAmountsOutOfOrder.
  ///
  /// In pt, this message translates to:
  /// **'O mínimo deve ser menor que o máximo.'**
  String get filterAmountsOutOfOrder;

  /// No description provided for @filterApply.
  ///
  /// In pt, this message translates to:
  /// **'Aplicar filtros'**
  String get filterApply;

  /// No description provided for @filterReset.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get filterReset;

  /// No description provided for @chipDebits.
  ///
  /// In pt, this message translates to:
  /// **'Débitos'**
  String get chipDebits;

  /// No description provided for @chipCredits.
  ///
  /// In pt, this message translates to:
  /// **'Créditos'**
  String get chipCredits;

  /// No description provided for @chipPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendentes'**
  String get chipPending;

  /// No description provided for @chipPosted.
  ///
  /// In pt, this message translates to:
  /// **'Efetivadas'**
  String get chipPosted;

  /// No description provided for @chipMin.
  ///
  /// In pt, this message translates to:
  /// **'Mín. {amount}'**
  String chipMin(String amount);

  /// No description provided for @chipMax.
  ///
  /// In pt, this message translates to:
  /// **'Máx. {amount}'**
  String chipMax(String amount);

  /// No description provided for @chipFrom.
  ///
  /// In pt, this message translates to:
  /// **'De {date}'**
  String chipFrom(String date);

  /// No description provided for @chipTo.
  ///
  /// In pt, this message translates to:
  /// **'Até {date}'**
  String chipTo(String date);

  /// No description provided for @detailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Transação'**
  String get detailTitle;

  /// No description provided for @detailDate.
  ///
  /// In pt, this message translates to:
  /// **'Data'**
  String get detailDate;

  /// No description provided for @detailDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get detailDescription;

  /// No description provided for @detailCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get detailCategory;

  /// No description provided for @detailMerchant.
  ///
  /// In pt, this message translates to:
  /// **'Estabelecimento'**
  String get detailMerchant;

  /// No description provided for @detailAccount.
  ///
  /// In pt, this message translates to:
  /// **'Conta'**
  String get detailAccount;

  /// No description provided for @detailHolder.
  ///
  /// In pt, this message translates to:
  /// **'Titular'**
  String get detailHolder;

  /// No description provided for @detailType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get detailType;

  /// No description provided for @detailStatus.
  ///
  /// In pt, this message translates to:
  /// **'Status'**
  String get detailStatus;

  /// No description provided for @detailBalanceAfter.
  ///
  /// In pt, this message translates to:
  /// **'Saldo após'**
  String get detailBalanceAfter;

  /// No description provided for @detailMissing.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir esta transação.'**
  String get detailMissing;

  /// No description provided for @detailBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para a lista'**
  String get detailBack;

  /// No description provided for @entriesSearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar lançamento'**
  String get entriesSearchHint;

  /// No description provided for @entriesTabPlanned.
  ///
  /// In pt, this message translates to:
  /// **'Planejados'**
  String get entriesTabPlanned;

  /// No description provided for @entriesTabReconciled.
  ///
  /// In pt, this message translates to:
  /// **'Conciliados'**
  String get entriesTabReconciled;

  /// No description provided for @entriesTabCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelados'**
  String get entriesTabCancelled;

  /// No description provided for @entriesMonthAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get entriesMonthAll;

  /// No description provided for @entriesShowing.
  ///
  /// In pt, this message translates to:
  /// **'Mostrando {shown} de {total}'**
  String entriesShowing(int shown, int total);

  /// No description provided for @entriesLoadingMore.
  ///
  /// In pt, this message translates to:
  /// **'Carregando mais lançamentos…'**
  String get entriesLoadingMore;

  /// No description provided for @entriesEnd.
  ///
  /// In pt, this message translates to:
  /// **'Fim da lista'**
  String get entriesEnd;

  /// No description provided for @entriesEmptyTitlePlanned.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum lançamento planejado'**
  String get entriesEmptyTitlePlanned;

  /// No description provided for @entriesEmptyTitleReconciled.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum lançamento conciliado'**
  String get entriesEmptyTitleReconciled;

  /// No description provided for @entriesEmptyTitleCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum lançamento cancelado'**
  String get entriesEmptyTitleCancelled;

  /// No description provided for @entriesEmptyInMonth.
  ///
  /// In pt, this message translates to:
  /// **'{title} em {month}'**
  String entriesEmptyInMonth(String title, String month);

  /// No description provided for @entriesEmptyPlain.
  ///
  /// In pt, this message translates to:
  /// **'Quando houver lançamentos aqui, eles aparecem nesta lista.'**
  String get entriesEmptyPlain;

  /// No description provided for @entriesEmptyFiltered.
  ///
  /// In pt, this message translates to:
  /// **'Tente outro termo de busca, outro mês ou remova alguns filtros.'**
  String get entriesEmptyFiltered;

  /// No description provided for @entryStatusPlanned.
  ///
  /// In pt, this message translates to:
  /// **'Planejado'**
  String get entryStatusPlanned;

  /// No description provided for @entryStatusOverdue.
  ///
  /// In pt, this message translates to:
  /// **'Vencido'**
  String get entryStatusOverdue;

  /// No description provided for @entryStatusReconciled.
  ///
  /// In pt, this message translates to:
  /// **'Conciliado'**
  String get entryStatusReconciled;

  /// No description provided for @entryStatusCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelado'**
  String get entryStatusCancelled;

  /// No description provided for @entryTypeRevenue.
  ///
  /// In pt, this message translates to:
  /// **'Receita'**
  String get entryTypeRevenue;

  /// No description provided for @entryTypeExpense.
  ///
  /// In pt, this message translates to:
  /// **'Despesa'**
  String get entryTypeExpense;

  /// No description provided for @entryPayDebit.
  ///
  /// In pt, this message translates to:
  /// **'Débito'**
  String get entryPayDebit;

  /// No description provided for @entryPayCredit.
  ///
  /// In pt, this message translates to:
  /// **'Crédito'**
  String get entryPayCredit;

  /// No description provided for @entryDue.
  ///
  /// In pt, this message translates to:
  /// **'Venc. {date}'**
  String entryDue(String date);

  /// No description provided for @entryRef.
  ///
  /// In pt, this message translates to:
  /// **'Ref. {month}'**
  String entryRef(String month);

  /// No description provided for @entriesFiltersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Filtrar lançamentos'**
  String get entriesFiltersTitle;

  /// No description provided for @entriesFilterPayment.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento'**
  String get entriesFilterPayment;

  /// No description provided for @entriesFilterDue.
  ///
  /// In pt, this message translates to:
  /// **'Vencimento'**
  String get entriesFilterDue;

  /// No description provided for @chipRevenues.
  ///
  /// In pt, this message translates to:
  /// **'Receitas'**
  String get chipRevenues;

  /// No description provided for @chipExpenses.
  ///
  /// In pt, this message translates to:
  /// **'Despesas'**
  String get chipExpenses;

  /// No description provided for @chipDueFrom.
  ///
  /// In pt, this message translates to:
  /// **'Venc. de {date}'**
  String chipDueFrom(String date);

  /// No description provided for @chipDueTo.
  ///
  /// In pt, this message translates to:
  /// **'Venc. até {date}'**
  String chipDueTo(String date);

  /// No description provided for @entryDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento'**
  String get entryDetailTitle;

  /// No description provided for @entryDetailReference.
  ///
  /// In pt, this message translates to:
  /// **'Mês de referência'**
  String get entryDetailReference;

  /// No description provided for @entryDetailDue.
  ///
  /// In pt, this message translates to:
  /// **'Vencimento'**
  String get entryDetailDue;

  /// No description provided for @entryDetailInstallment.
  ///
  /// In pt, this message translates to:
  /// **'Parcela'**
  String get entryDetailInstallment;

  /// No description provided for @entryDetailInstallmentOf.
  ///
  /// In pt, this message translates to:
  /// **'{number} de {total}'**
  String entryDetailInstallmentOf(int number, int total);

  /// No description provided for @entryDetailNotes.
  ///
  /// In pt, this message translates to:
  /// **'Observações'**
  String get entryDetailNotes;

  /// No description provided for @entryDetailPayment.
  ///
  /// In pt, this message translates to:
  /// **'Pagamento'**
  String get entryDetailPayment;

  /// No description provided for @entryDetailMissing.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível abrir este lançamento.'**
  String get entryDetailMissing;

  /// No description provided for @entryTimelineCreated.
  ///
  /// In pt, this message translates to:
  /// **'Criado'**
  String get entryTimelineCreated;

  /// No description provided for @entryTimelineCreatedBy.
  ///
  /// In pt, this message translates to:
  /// **'{date} · por {name}'**
  String entryTimelineCreatedBy(String date, String name);

  /// No description provided for @entryTimelinePlanned.
  ///
  /// In pt, this message translates to:
  /// **'Planejado'**
  String get entryTimelinePlanned;

  /// No description provided for @entryTimelineDueOn.
  ///
  /// In pt, this message translates to:
  /// **'Vence em {date}'**
  String entryTimelineDueOn(String date);

  /// No description provided for @entryTimelineNoDue.
  ///
  /// In pt, this message translates to:
  /// **'Sem data de vencimento'**
  String get entryTimelineNoDue;

  /// No description provided for @entryTimelineReconciled.
  ///
  /// In pt, this message translates to:
  /// **'Conciliado'**
  String get entryTimelineReconciled;

  /// No description provided for @entryTimelineReconciledText.
  ///
  /// In pt, this message translates to:
  /// **'Vinculado a uma transação do banco.'**
  String get entryTimelineReconciledText;

  /// No description provided for @entryTimelineCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Cancelado'**
  String get entryTimelineCancelled;

  /// No description provided for @entryTimelineCancelledText.
  ///
  /// In pt, this message translates to:
  /// **'Não será cobrado nem conciliado.'**
  String get entryTimelineCancelledText;

  /// No description provided for @entryTimelineWaiting.
  ///
  /// In pt, this message translates to:
  /// **'Aguardando conciliação'**
  String get entryTimelineWaiting;

  /// No description provided for @entryTimelineWaitingText.
  ///
  /// In pt, this message translates to:
  /// **'Quando a transação aparecer no banco, ela será ligada a este lançamento.'**
  String get entryTimelineWaitingText;

  /// No description provided for @linkedTransactionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Transação do banco'**
  String get linkedTransactionTitle;

  /// No description provided for @linkedEntryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento vinculado'**
  String get linkedEntryTitle;

  /// No description provided for @linkedEntryNone.
  ///
  /// In pt, this message translates to:
  /// **'Sem lançamento'**
  String get linkedEntryNone;

  /// No description provided for @linkedEntryNoneText.
  ///
  /// In pt, this message translates to:
  /// **'Esta transação ainda não foi ligada a nada que vocês planejaram.'**
  String get linkedEntryNoneText;

  /// No description provided for @linkedTransactionNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma transação ligada a este lançamento ainda.'**
  String get linkedTransactionNone;

  /// No description provided for @linkedLoadError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar o vínculo.'**
  String get linkedLoadError;

  /// No description provided for @accountsTotalTitle.
  ///
  /// In pt, this message translates to:
  /// **'Saldo total em contas'**
  String get accountsTotalTitle;

  /// No description provided for @accountsBills.
  ///
  /// In pt, this message translates to:
  /// **'Faturas abertas nos cartões: {amount}'**
  String accountsBills(String amount);

  /// No description provided for @accountsNoCards.
  ///
  /// In pt, this message translates to:
  /// **'Sem cartões conectados'**
  String get accountsNoCards;

  /// No description provided for @accountsTabBanks.
  ///
  /// In pt, this message translates to:
  /// **'Contas bancárias'**
  String get accountsTabBanks;

  /// No description provided for @accountsTabCards.
  ///
  /// In pt, this message translates to:
  /// **'Cartões de crédito'**
  String get accountsTabCards;

  /// No description provided for @accountBalanceLabel.
  ///
  /// In pt, this message translates to:
  /// **'Saldo atual'**
  String get accountBalanceLabel;

  /// No description provided for @accountBillLabel.
  ///
  /// In pt, this message translates to:
  /// **'Fatura atual'**
  String get accountBillLabel;

  /// No description provided for @accountSubBank.
  ///
  /// In pt, this message translates to:
  /// **'Conta •••• {number}'**
  String accountSubBank(String number);

  /// No description provided for @accountSubCard.
  ///
  /// In pt, this message translates to:
  /// **'Cartão •••• {number}'**
  String accountSubCard(String number);

  /// No description provided for @accountCardUsed.
  ///
  /// In pt, this message translates to:
  /// **'Usado {percent}%'**
  String accountCardUsed(int percent);

  /// No description provided for @accountCardLimit.
  ///
  /// In pt, this message translates to:
  /// **'Limite {amount}'**
  String accountCardLimit(String amount);

  /// No description provided for @accountCardAvailable.
  ///
  /// In pt, this message translates to:
  /// **'Disponível {amount}'**
  String accountCardAvailable(String amount);

  /// No description provided for @accountSeeTransactions.
  ///
  /// In pt, this message translates to:
  /// **'Ver transações'**
  String get accountSeeTransactions;

  /// No description provided for @accountSalaryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conta salário'**
  String get accountSalaryTitle;

  /// No description provided for @accountSalaryText.
  ///
  /// In pt, this message translates to:
  /// **'TEDs que saem dela para suas contas contam como recebido'**
  String get accountSalaryText;

  /// No description provided for @accountSalaryBank.
  ///
  /// In pt, this message translates to:
  /// **'Banco {code}'**
  String accountSalaryBank(String code);

  /// No description provided for @accountSalaryEditCode.
  ///
  /// In pt, this message translates to:
  /// **'Alterar código do banco'**
  String get accountSalaryEditCode;

  /// No description provided for @salaryConfirmOnTitle.
  ///
  /// In pt, this message translates to:
  /// **'Marcar como conta salário?'**
  String get salaryConfirmOnTitle;

  /// No description provided for @salaryConfirmOnText.
  ///
  /// In pt, this message translates to:
  /// **'Os TEDs que saem de {account} para as suas contas passam a contar como recebido. As transferências da casa serão reclassificadas, o que pode levar alguns instantes.'**
  String salaryConfirmOnText(String account);

  /// No description provided for @salaryConfirmOffTitle.
  ///
  /// In pt, this message translates to:
  /// **'Desmarcar conta salário?'**
  String get salaryConfirmOffTitle;

  /// No description provided for @salaryConfirmOffText.
  ///
  /// In pt, this message translates to:
  /// **'Os TEDs que saem de {account} para as suas contas voltam a ser transferências internas. As transferências da casa serão reclassificadas, o que pode levar alguns instantes.'**
  String salaryConfirmOffText(String account);

  /// No description provided for @salaryConfirmCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get salaryConfirmCancel;

  /// No description provided for @salaryConfirmOk.
  ///
  /// In pt, this message translates to:
  /// **'Confirmar'**
  String get salaryConfirmOk;

  /// No description provided for @bankCodeDialogTitle.
  ///
  /// In pt, this message translates to:
  /// **'Código do banco'**
  String get bankCodeDialogTitle;

  /// No description provided for @bankCodeDialogText.
  ///
  /// In pt, this message translates to:
  /// **'O código de 3 dígitos do banco da conta salário (por exemplo, 001 para o Banco do Brasil). Os TEDs com o seu CPF vindos desse banco passam a contar como recebido.'**
  String get bankCodeDialogText;

  /// No description provided for @bankCodeDialogLabel.
  ///
  /// In pt, this message translates to:
  /// **'Código do banco'**
  String get bankCodeDialogLabel;

  /// No description provided for @bankCodeDialogCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get bankCodeDialogCancel;

  /// No description provided for @bankCodeDialogConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get bankCodeDialogConfirm;

  /// No description provided for @accountsEmptyNoBankTitle.
  ///
  /// In pt, this message translates to:
  /// **'{who} ainda não conectou nenhum banco'**
  String accountsEmptyNoBankTitle(String who);

  /// No description provided for @accountsEmptyNoBankText.
  ///
  /// In pt, this message translates to:
  /// **'Conecte um banco pelo Meu Pluggy para ver contas e cartões aqui.'**
  String get accountsEmptyNoBankText;

  /// No description provided for @accountsEmptyBanks.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conta bancária'**
  String get accountsEmptyBanks;

  /// No description provided for @accountsEmptyCards.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cartão de crédito'**
  String get accountsEmptyCards;

  /// No description provided for @accountsEmptyKindText.
  ///
  /// In pt, this message translates to:
  /// **'Não há itens deste tipo conectados para esta seleção.'**
  String get accountsEmptyKindText;

  /// No description provided for @accountsTotalsError.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar os totais.'**
  String get accountsTotalsError;

  /// No description provided for @configErrorTitle.
  ///
  /// In pt, this message translates to:
  /// **'Configuração ausente'**
  String get configErrorTitle;

  /// No description provided for @configErrorMessage.
  ///
  /// In pt, this message translates to:
  /// **'O app não foi iniciado com uma URL de API válida. Rode com --dart-define=API_BASE_URL=<url>.'**
  String get configErrorMessage;

  /// No description provided for @failureConversationFull.
  ///
  /// In pt, this message translates to:
  /// **'Esta conversa atingiu o limite. Inicie uma nova conversa.'**
  String get failureConversationFull;

  /// No description provided for @chatNewConversation.
  ///
  /// In pt, this message translates to:
  /// **'Nova conversa'**
  String get chatNewConversation;

  /// No description provided for @chatHistory.
  ///
  /// In pt, this message translates to:
  /// **'Histórico de conversas'**
  String get chatHistory;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte sobre o dinheiro da casa'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptySubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Eu consulto transações, lançamentos, contas e cartões e respondo em linguagem simples.'**
  String get chatEmptySubtitle;

  /// No description provided for @chatSuggestion1.
  ///
  /// In pt, this message translates to:
  /// **'Quanto gastei este mês?'**
  String get chatSuggestion1;

  /// No description provided for @chatSuggestion2.
  ///
  /// In pt, this message translates to:
  /// **'Quanto cada pessoa da casa gastou?'**
  String get chatSuggestion2;

  /// No description provided for @chatSuggestion3.
  ///
  /// In pt, this message translates to:
  /// **'Quais são meus próximos lançamentos?'**
  String get chatSuggestion3;

  /// No description provided for @chatSuggestion4.
  ///
  /// In pt, this message translates to:
  /// **'Qual o saldo das nossas contas?'**
  String get chatSuggestion4;

  /// No description provided for @chatSuggestion5.
  ///
  /// In pt, this message translates to:
  /// **'Quanto gastei em mercado?'**
  String get chatSuggestion5;

  /// No description provided for @chatSuggestion6.
  ///
  /// In pt, this message translates to:
  /// **'Quais cartões temos e qual o limite?'**
  String get chatSuggestion6;

  /// No description provided for @chatInputHint.
  ///
  /// In pt, this message translates to:
  /// **'Pergunte ao Tally…'**
  String get chatInputHint;

  /// No description provided for @chatSend.
  ///
  /// In pt, this message translates to:
  /// **'Enviar mensagem'**
  String get chatSend;

  /// No description provided for @chatCaption.
  ///
  /// In pt, this message translates to:
  /// **'O Tally AI pode errar. Confira os valores importantes.'**
  String get chatCaption;

  /// No description provided for @chatHistorySaved.
  ///
  /// In pt, this message translates to:
  /// **'O histórico das conversas fica salvo e você pode continuar depois.'**
  String get chatHistorySaved;

  /// No description provided for @chatTyping.
  ///
  /// In pt, this message translates to:
  /// **'Digitando… consultando seus dados'**
  String get chatTyping;

  /// No description provided for @chatErrorMessage.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui responder agora.'**
  String get chatErrorMessage;

  /// No description provided for @chatErrorRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get chatErrorRetry;

  /// No description provided for @chatWarning.
  ///
  /// In pt, this message translates to:
  /// **'A conversa está chegando ao limite. Considere iniciar uma nova conversa.'**
  String get chatWarning;

  /// No description provided for @chatFullTitle.
  ///
  /// In pt, this message translates to:
  /// **'Conversa cheia'**
  String get chatFullTitle;

  /// No description provided for @chatFullMessage.
  ///
  /// In pt, this message translates to:
  /// **'Esta conversa atingiu o limite e agora é só de leitura.'**
  String get chatFullMessage;

  /// No description provided for @chatStartNew.
  ///
  /// In pt, this message translates to:
  /// **'Iniciar nova conversa'**
  String get chatStartNew;

  /// No description provided for @chatCounter.
  ///
  /// In pt, this message translates to:
  /// **'{count}/{max}'**
  String chatCounter(int count, int max);

  /// No description provided for @chatYou.
  ///
  /// In pt, this message translates to:
  /// **'Você'**
  String get chatYou;

  /// No description provided for @chatAssistant.
  ///
  /// In pt, this message translates to:
  /// **'Tally AI'**
  String get chatAssistant;

  /// No description provided for @conversationsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get conversationsTitle;

  /// No description provided for @conversationsBack.
  ///
  /// In pt, this message translates to:
  /// **'Voltar ao chat'**
  String get conversationsBack;

  /// No description provided for @conversationsEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma conversa ainda'**
  String get conversationsEmptyTitle;

  /// No description provided for @conversationsEmptyMessage.
  ///
  /// In pt, this message translates to:
  /// **'Quando você perguntar algo ao Tally AI, a conversa aparece aqui.'**
  String get conversationsEmptyMessage;

  /// No description provided for @conversationUntitled.
  ///
  /// In pt, this message translates to:
  /// **'Conversa sem título'**
  String get conversationUntitled;

  /// No description provided for @conversationUsage.
  ///
  /// In pt, this message translates to:
  /// **'{percent}% do limite'**
  String conversationUsage(int percent);

  /// No description provided for @failureNoRecurrences.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre ao menos uma recorrência antes de provisionar o mês.'**
  String get failureNoRecurrences;

  /// No description provided for @planningSectionEntries.
  ///
  /// In pt, this message translates to:
  /// **'Lançamentos'**
  String get planningSectionEntries;

  /// No description provided for @planningSectionRecurrences.
  ///
  /// In pt, this message translates to:
  /// **'Recorrências'**
  String get planningSectionRecurrences;

  /// No description provided for @commonCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @formRequired.
  ///
  /// In pt, this message translates to:
  /// **'Preencha este campo.'**
  String get formRequired;

  /// No description provided for @formAmountInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Digite um valor maior que zero.'**
  String get formAmountInvalid;

  /// No description provided for @formDueDayInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Digite um dia de 1 a 31.'**
  String get formDueDayInvalid;

  /// No description provided for @formInstallmentsInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Preencha as duas parcelas, com a atual menor ou igual ao total.'**
  String get formInstallmentsInvalid;

  /// No description provided for @formOptional.
  ///
  /// In pt, this message translates to:
  /// **'Opcional'**
  String get formOptional;

  /// No description provided for @entryNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo lançamento'**
  String get entryNew;

  /// No description provided for @entryEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar lançamento'**
  String get entryEditTitle;

  /// No description provided for @entryFormSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar lançamento'**
  String get entryFormSave;

  /// No description provided for @entryFormDescription.
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get entryFormDescription;

  /// No description provided for @entryFormDescriptionHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Conta de luz'**
  String get entryFormDescriptionHint;

  /// No description provided for @entryFormType.
  ///
  /// In pt, this message translates to:
  /// **'Tipo'**
  String get entryFormType;

  /// No description provided for @entryFormPayment.
  ///
  /// In pt, this message translates to:
  /// **'Forma de pagamento'**
  String get entryFormPayment;

  /// No description provided for @entryFormCategory.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get entryFormCategory;

  /// No description provided for @entryFormCategoryHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Moradia'**
  String get entryFormCategoryHint;

  /// No description provided for @entryFormAmount.
  ///
  /// In pt, this message translates to:
  /// **'Valor'**
  String get entryFormAmount;

  /// No description provided for @entryFormMonth.
  ///
  /// In pt, this message translates to:
  /// **'Mês de referência'**
  String get entryFormMonth;

  /// No description provided for @entryFormDue.
  ///
  /// In pt, this message translates to:
  /// **'Vencimento'**
  String get entryFormDue;

  /// No description provided for @entryFormAccount.
  ///
  /// In pt, this message translates to:
  /// **'Conta ou cartão'**
  String get entryFormAccount;

  /// No description provided for @entryFormNoAccount.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma'**
  String get entryFormNoAccount;

  /// No description provided for @entryFormInstallments.
  ///
  /// In pt, this message translates to:
  /// **'Parcelas'**
  String get entryFormInstallments;

  /// No description provided for @entryFormInstallmentCurrent.
  ///
  /// In pt, this message translates to:
  /// **'Parcela atual'**
  String get entryFormInstallmentCurrent;

  /// No description provided for @entryFormInstallmentTotal.
  ///
  /// In pt, this message translates to:
  /// **'Total de parcelas'**
  String get entryFormInstallmentTotal;

  /// No description provided for @entryFormInstallmentsHint.
  ///
  /// In pt, this message translates to:
  /// **'Preencha as duas, ou deixe as duas em branco.'**
  String get entryFormInstallmentsHint;

  /// No description provided for @entryFormNotes.
  ///
  /// In pt, this message translates to:
  /// **'Observações'**
  String get entryFormNotes;

  /// No description provided for @entryFormNotesHint.
  ///
  /// In pt, this message translates to:
  /// **'Algo que ajude a lembrar'**
  String get entryFormNotesHint;

  /// No description provided for @entryActionEdit.
  ///
  /// In pt, this message translates to:
  /// **'Editar'**
  String get entryActionEdit;

  /// No description provided for @entryActionCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar lançamento'**
  String get entryActionCancel;

  /// No description provided for @entryActionReopen.
  ///
  /// In pt, this message translates to:
  /// **'Reativar lançamento'**
  String get entryActionReopen;

  /// No description provided for @entryActionDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lançamento'**
  String get entryActionDelete;

  /// No description provided for @entryReconciledLocked.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento conciliado não pode ser editado nem excluído. Desfaça a conciliação antes.'**
  String get entryReconciledLocked;

  /// No description provided for @entryDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lançamento?'**
  String get entryDeleteTitle;

  /// No description provided for @entryDeleteText.
  ///
  /// In pt, this message translates to:
  /// **'\"{name}\" sai da lista. Essa ação não pode ser desfeita.'**
  String entryDeleteText(String name);

  /// No description provided for @entryDeleteConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get entryDeleteConfirm;

  /// No description provided for @entrySaved.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento salvo.'**
  String get entrySaved;

  /// No description provided for @entryCancelledDone.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento cancelado.'**
  String get entryCancelledDone;

  /// No description provided for @entryReopenedDone.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento reativado.'**
  String get entryReopenedDone;

  /// No description provided for @entryDeletedDone.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento excluído.'**
  String get entryDeletedDone;

  /// No description provided for @recurrencesIntro.
  ///
  /// In pt, this message translates to:
  /// **'Itens que se repetem todo mês. O Tally cria o lançamento no mês certo para vocês.'**
  String get recurrencesIntro;

  /// No description provided for @recurrencesEmptyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma recorrência ainda'**
  String get recurrencesEmptyTitle;

  /// No description provided for @recurrencesEmptyText.
  ///
  /// In pt, this message translates to:
  /// **'Cadastre aluguel, assinaturas e salários para não digitar todo mês.'**
  String get recurrencesEmptyText;

  /// No description provided for @recurrenceNew.
  ///
  /// In pt, this message translates to:
  /// **'Nova recorrência'**
  String get recurrenceNew;

  /// No description provided for @recurrenceEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar recorrência'**
  String get recurrenceEditTitle;

  /// No description provided for @recurrenceFormSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar recorrência'**
  String get recurrenceFormSave;

  /// No description provided for @recurrenceFormDay.
  ///
  /// In pt, this message translates to:
  /// **'Dia do mês'**
  String get recurrenceFormDay;

  /// No description provided for @recurrenceFormDayHint.
  ///
  /// In pt, this message translates to:
  /// **'Todo mês neste dia. Em meses mais curtos vale o último dia.'**
  String get recurrenceFormDayHint;

  /// No description provided for @recurrenceDay.
  ///
  /// In pt, this message translates to:
  /// **'Todo dia {day}'**
  String recurrenceDay(int day);

  /// No description provided for @recurrenceNoDay.
  ///
  /// In pt, this message translates to:
  /// **'Sem dia fixo'**
  String get recurrenceNoDay;

  /// No description provided for @recurrenceDeleteAction.
  ///
  /// In pt, this message translates to:
  /// **'Excluir recorrência'**
  String get recurrenceDeleteAction;

  /// No description provided for @recurrenceDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir recorrência?'**
  String get recurrenceDeleteTitle;

  /// No description provided for @recurrenceDeleteText.
  ///
  /// In pt, this message translates to:
  /// **'\"{name}\" deixa de gerar lançamentos. Os que já foram criados continuam.'**
  String recurrenceDeleteText(String name);

  /// No description provided for @recurrenceSaved.
  ///
  /// In pt, this message translates to:
  /// **'Recorrência salva.'**
  String get recurrenceSaved;

  /// No description provided for @recurrenceDeletedDone.
  ///
  /// In pt, this message translates to:
  /// **'Recorrência excluída.'**
  String get recurrenceDeletedDone;

  /// No description provided for @provisionButton.
  ///
  /// In pt, this message translates to:
  /// **'Provisionar {month}'**
  String provisionButton(String month);

  /// No description provided for @provisionTitle.
  ///
  /// In pt, this message translates to:
  /// **'Provisionar o próximo mês?'**
  String get provisionTitle;

  /// No description provided for @provisionText.
  ///
  /// In pt, this message translates to:
  /// **'O Tally vai criar os lançamentos de {month} a partir das recorrências cadastradas. Quem já tem lançamento nesse mês não é duplicado.'**
  String provisionText(String month);

  /// No description provided for @provisionConfirm.
  ///
  /// In pt, this message translates to:
  /// **'Provisionar'**
  String get provisionConfirm;

  /// No description provided for @provisionCreated.
  ///
  /// In pt, this message translates to:
  /// **'{created, plural, =1{1 lançamento criado em {month}.} other{{created} lançamentos criados em {month}.}}'**
  String provisionCreated(int created, String month);

  /// No description provided for @provisionNothingNew.
  ///
  /// In pt, this message translates to:
  /// **'Tudo já estava provisionado em {month}.'**
  String provisionNothingNew(String month);

  /// No description provided for @recurrenceFormDescriptionHint.
  ///
  /// In pt, this message translates to:
  /// **'Ex.: Aluguel'**
  String get recurrenceFormDescriptionHint;

  /// No description provided for @recurrenceFormDayExample.
  ///
  /// In pt, this message translates to:
  /// **'5'**
  String get recurrenceFormDayExample;

  /// No description provided for @homeSettings.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get homeSettings;

  /// No description provided for @failureEmailExists.
  ///
  /// In pt, this message translates to:
  /// **'Já existe um usuário com esse e-mail.'**
  String get failureEmailExists;

  /// No description provided for @settingsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeLight.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In pt, this message translates to:
  /// **'Escuro'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get settingsThemeSystem;

  /// No description provided for @settingsHousehold.
  ///
  /// In pt, this message translates to:
  /// **'Casa'**
  String get settingsHousehold;

  /// No description provided for @settingsUsers.
  ///
  /// In pt, this message translates to:
  /// **'Usuários'**
  String get settingsUsers;

  /// No description provided for @settingsUsersHint.
  ///
  /// In pt, this message translates to:
  /// **'Quem usa o Tally nesta casa'**
  String get settingsUsersHint;

  /// No description provided for @usersTitle.
  ///
  /// In pt, this message translates to:
  /// **'Usuários'**
  String get usersTitle;

  /// No description provided for @usersNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo usuário'**
  String get usersNew;

  /// No description provided for @usersAddedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Usuário criado.'**
  String get usersAddedNotice;

  /// No description provided for @userDetailTitle.
  ///
  /// In pt, this message translates to:
  /// **'Usuário'**
  String get userDetailTitle;

  /// No description provided for @userEditAction.
  ///
  /// In pt, this message translates to:
  /// **'Editar dados'**
  String get userEditAction;

  /// No description provided for @userEditTitle.
  ///
  /// In pt, this message translates to:
  /// **'Editar usuário'**
  String get userEditTitle;

  /// No description provided for @userNewTitle.
  ///
  /// In pt, this message translates to:
  /// **'Novo usuário'**
  String get userNewTitle;

  /// No description provided for @userFieldFirstName.
  ///
  /// In pt, this message translates to:
  /// **'Nome'**
  String get userFieldFirstName;

  /// No description provided for @userFieldLastName.
  ///
  /// In pt, this message translates to:
  /// **'Sobrenome'**
  String get userFieldLastName;

  /// No description provided for @userFieldSurname.
  ///
  /// In pt, this message translates to:
  /// **'Apelido'**
  String get userFieldSurname;

  /// No description provided for @userFieldSurnameHelp.
  ///
  /// In pt, this message translates to:
  /// **'É o nome que aparece nos filtros e nas telas.'**
  String get userFieldSurnameHelp;

  /// No description provided for @userFieldEmail.
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get userFieldEmail;

  /// No description provided for @userFieldPassword.
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get userFieldPassword;

  /// No description provided for @userFieldPasswordHelp.
  ///
  /// In pt, this message translates to:
  /// **'Mínimo de 8 caracteres.'**
  String get userFieldPasswordHelp;

  /// No description provided for @userNotInformed.
  ///
  /// In pt, this message translates to:
  /// **'Não informado'**
  String get userNotInformed;

  /// No description provided for @userSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get userSave;

  /// No description provided for @userCreate.
  ///
  /// In pt, this message translates to:
  /// **'Criar usuário'**
  String get userCreate;

  /// No description provided for @userSavedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Dados salvos.'**
  String get userSavedNotice;

  /// No description provided for @userEmailInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Digite um e-mail válido.'**
  String get userEmailInvalid;

  /// No description provided for @userPasswordShort.
  ///
  /// In pt, this message translates to:
  /// **'Use ao menos 8 caracteres.'**
  String get userPasswordShort;

  /// No description provided for @userPluggySection.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais da Pluggy'**
  String get userPluggySection;

  /// No description provided for @userPluggyAction.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais da Pluggy'**
  String get userPluggyAction;

  /// No description provided for @userPluggyIntro.
  ///
  /// In pt, this message translates to:
  /// **'Cada pessoa usa a própria aplicação da Pluggy. Consulte o Client ID e o Client Secret dela no portal da Pluggy.'**
  String get userPluggyIntro;

  /// No description provided for @userPluggyHidden.
  ///
  /// In pt, this message translates to:
  /// **'Por segurança, as credenciais atuais não são exibidas.'**
  String get userPluggyHidden;

  /// No description provided for @pluggyClientId.
  ///
  /// In pt, this message translates to:
  /// **'Client ID'**
  String get pluggyClientId;

  /// No description provided for @pluggyClientSecret.
  ///
  /// In pt, this message translates to:
  /// **'Client Secret'**
  String get pluggyClientSecret;

  /// No description provided for @pluggyClientIdInvalid.
  ///
  /// In pt, this message translates to:
  /// **'Digite um Client ID válido (formato UUID).'**
  String get pluggyClientIdInvalid;

  /// No description provided for @pluggySave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar credenciais'**
  String get pluggySave;

  /// No description provided for @pluggyConfirmTitle.
  ///
  /// In pt, this message translates to:
  /// **'Alterar as credenciais?'**
  String get pluggyConfirmTitle;

  /// No description provided for @pluggyConfirmMessage.
  ///
  /// In pt, this message translates to:
  /// **'Se as credenciais estiverem erradas, o Tally deixa de importar os dados bancários desta pessoa e o sistema passa a funcionar mal. Confira no portal da Pluggy antes de continuar.'**
  String get pluggyConfirmMessage;

  /// No description provided for @pluggyConfirmOk.
  ///
  /// In pt, this message translates to:
  /// **'Alterar credenciais'**
  String get pluggyConfirmOk;

  /// No description provided for @pluggySavedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Credenciais atualizadas.'**
  String get pluggySavedNotice;

  /// No description provided for @userPasswordAction.
  ///
  /// In pt, this message translates to:
  /// **'Alterar senha'**
  String get userPasswordAction;

  /// No description provided for @userPasswordIntro.
  ///
  /// In pt, this message translates to:
  /// **'Defina uma nova senha para esta pessoa. Ela passa a valer no próximo login.'**
  String get userPasswordIntro;

  /// No description provided for @userPasswordSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar senha'**
  String get userPasswordSave;

  /// No description provided for @userPasswordSavedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Senha alterada.'**
  String get userPasswordSavedNotice;

  /// No description provided for @recurrencesTabActive.
  ///
  /// In pt, this message translates to:
  /// **'Ativas'**
  String get recurrencesTabActive;

  /// No description provided for @recurrencesTabCancelled.
  ///
  /// In pt, this message translates to:
  /// **'Canceladas'**
  String get recurrencesTabCancelled;

  /// No description provided for @recurrenceFormOwner.
  ///
  /// In pt, this message translates to:
  /// **'Dono'**
  String get recurrenceFormOwner;

  /// No description provided for @recurrenceCancelAction.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar recorrência'**
  String get recurrenceCancelAction;

  /// No description provided for @recurrenceReactivateAction.
  ///
  /// In pt, this message translates to:
  /// **'Reativar'**
  String get recurrenceReactivateAction;

  /// No description provided for @recurrenceCancelTitle.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar a recorrência?'**
  String get recurrenceCancelTitle;

  /// No description provided for @recurrenceCancelText.
  ///
  /// In pt, this message translates to:
  /// **'Ela deixa de criar lançamentos nos próximos meses. Os lançamentos já criados continuam. Você pode reativá-la depois.'**
  String get recurrenceCancelText;

  /// No description provided for @recurrenceCancelledNotice.
  ///
  /// In pt, this message translates to:
  /// **'Recorrência cancelada.'**
  String get recurrenceCancelledNotice;

  /// No description provided for @recurrenceReactivatedNotice.
  ///
  /// In pt, this message translates to:
  /// **'Recorrência reativada.'**
  String get recurrenceReactivatedNotice;

  /// No description provided for @recurrencesEmptyCancelledTitle.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma recorrência cancelada'**
  String get recurrencesEmptyCancelledTitle;

  /// No description provided for @recurrencesEmptyCancelledText.
  ///
  /// In pt, this message translates to:
  /// **'As recorrências canceladas aparecem aqui e podem ser reativadas.'**
  String get recurrencesEmptyCancelledText;

  /// No description provided for @linkEntryAction.
  ///
  /// In pt, this message translates to:
  /// **'Vincular lançamento'**
  String get linkEntryAction;

  /// No description provided for @linkEntryShort.
  ///
  /// In pt, this message translates to:
  /// **'Vincular'**
  String get linkEntryShort;

  /// No description provided for @linkEntryIntro.
  ///
  /// In pt, this message translates to:
  /// **'Escolha um lançamento planejado do mesmo tipo da transação.'**
  String get linkEntryIntro;

  /// No description provided for @linkEntrySearchHint.
  ///
  /// In pt, this message translates to:
  /// **'Buscar pela descrição'**
  String get linkEntrySearchHint;

  /// No description provided for @linkEntryNone.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum lançamento planejado encontrado.'**
  String get linkEntryNone;

  /// No description provided for @linkEntryDone.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento vinculado.'**
  String get linkEntryDone;

  /// No description provided for @unlinkEntryAction.
  ///
  /// In pt, this message translates to:
  /// **'Desvincular'**
  String get unlinkEntryAction;

  /// No description provided for @unlinkEntryTitle.
  ///
  /// In pt, this message translates to:
  /// **'Desvincular o lançamento?'**
  String get unlinkEntryTitle;

  /// No description provided for @unlinkEntryText.
  ///
  /// In pt, this message translates to:
  /// **'O lançamento volta para planejado, a não ser que tenha outra transação vinculada.'**
  String get unlinkEntryText;

  /// No description provided for @unlinkEntryDone.
  ///
  /// In pt, this message translates to:
  /// **'Lançamento desvinculado.'**
  String get unlinkEntryDone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
