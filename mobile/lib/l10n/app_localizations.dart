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
