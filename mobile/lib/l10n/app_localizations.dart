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
