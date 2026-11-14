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
  /// **'Lançamentos'**
  String get navEntries;

  /// No description provided for @navAccounts.
  ///
  /// In pt, this message translates to:
  /// **'Contas'**
  String get navAccounts;

  /// No description provided for @navChat.
  ///
  /// In pt, this message translates to:
  /// **'Tally IA'**
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
