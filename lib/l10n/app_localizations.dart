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

  /// Título do aplicativo
  ///
  /// In pt, this message translates to:
  /// **'Minhas Tarefas'**
  String get appTitle;

  /// Rótulo de acessibilidade do indicador de carregamento
  ///
  /// In pt, this message translates to:
  /// **'Carregando'**
  String get loadingLabel;

  /// Rótulo de acessibilidade da barra exibida enquanto uma tarefa criada ou editada é salva
  ///
  /// In pt, this message translates to:
  /// **'Salvando'**
  String get savingLabel;

  /// Título da tela de login
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignInTitle;

  /// Título da tela de cadastro
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authSignUpTitle;

  /// Rótulo do campo de e-mail
  ///
  /// In pt, this message translates to:
  /// **'E-mail'**
  String get authEmailLabel;

  /// Rótulo do campo de senha
  ///
  /// In pt, this message translates to:
  /// **'Senha'**
  String get authPasswordLabel;

  /// Dica do botão que exibe a senha digitada
  ///
  /// In pt, this message translates to:
  /// **'Mostrar senha'**
  String get authShowPassword;

  /// Dica do botão que volta a ocultar a senha digitada
  ///
  /// In pt, this message translates to:
  /// **'Ocultar senha'**
  String get authHidePassword;

  /// Botão que envia o login
  ///
  /// In pt, this message translates to:
  /// **'Entrar'**
  String get authSignInButton;

  /// Botão que envia o cadastro
  ///
  /// In pt, this message translates to:
  /// **'Criar conta'**
  String get authSignUpButton;

  /// Alterna do login para o cadastro
  ///
  /// In pt, this message translates to:
  /// **'Não tem conta? Criar conta'**
  String get authSwitchToSignUp;

  /// Alterna do cadastro para o login
  ///
  /// In pt, this message translates to:
  /// **'Já tem conta? Entrar'**
  String get authSwitchToSignIn;

  /// Erro de validação: e-mail vazio
  ///
  /// In pt, this message translates to:
  /// **'Informe o e-mail'**
  String get authEmailRequired;

  /// Erro de validação: e-mail malformado
  ///
  /// In pt, this message translates to:
  /// **'E-mail inválido'**
  String get authEmailInvalid;

  /// Erro de validação: senha vazia
  ///
  /// In pt, this message translates to:
  /// **'Informe a senha'**
  String get authPasswordRequired;

  /// Login recusado; não revela se o e-mail existe
  ///
  /// In pt, this message translates to:
  /// **'E-mail ou senha incorretos.'**
  String get authErrorInvalidCredentials;

  /// Cadastro recusado: e-mail já cadastrado
  ///
  /// In pt, this message translates to:
  /// **'Este e-mail já está em uso.'**
  String get authErrorEmailInUse;

  /// Cadastro recusado: senha fraca
  ///
  /// In pt, this message translates to:
  /// **'Senha fraca. Use pelo menos 6 caracteres.'**
  String get authErrorWeakPassword;

  /// Provedor recusou o formato do e-mail
  ///
  /// In pt, this message translates to:
  /// **'E-mail inválido.'**
  String get authErrorInvalidEmail;

  /// Falha de rede no login ou cadastro
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Verifique a internet e tente de novo.'**
  String get authErrorNetwork;

  /// Falha inesperada no login ou cadastro
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir. Tente de novo.'**
  String get authErrorUnknown;

  /// Dica do botão de logout
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get signOutTooltip;

  /// Dica do botão que recarrega as tarefas
  ///
  /// In pt, this message translates to:
  /// **'Atualizar'**
  String get refreshTooltip;

  /// Dica do botão que cria uma tarefa
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get addTaskTooltip;

  /// Título do estado vazio
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma tarefa ainda'**
  String get tasksEmptyTitle;

  /// Convite do estado vazio
  ///
  /// In pt, this message translates to:
  /// **'Use o botão + para criar a primeira tarefa.'**
  String get tasksEmptyMessage;

  /// Cabeçalho do bloco de tarefas sem data
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get tasksUndatedHeader;

  /// Rótulo do destaque de atraso
  ///
  /// In pt, this message translates to:
  /// **'Atrasada'**
  String get tasksOverdueLabel;

  /// Rótulo do destaque do dia de hoje na linha do tempo
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get tasksTodayLabel;

  /// Anúncio do leitor de tela para o dia de hoje
  ///
  /// In pt, this message translates to:
  /// **'{date}, hoje'**
  String tasksDayTodaySemantics(String date);

  /// Resumo no cabeçalho com a quantidade de tarefas pendentes e concluídas
  ///
  /// In pt, this message translates to:
  /// **'{pending, plural, =1{1 pendente} other{{pending} pendentes}} · {completed, plural, =1{1 concluída} other{{completed} concluídas}}'**
  String tasksSummary(int pending, int completed);

  /// Anúncio do leitor de tela para um dia atrasado
  ///
  /// In pt, this message translates to:
  /// **'{date}, tarefas atrasadas'**
  String tasksDayOverdueSemantics(String date);

  /// Cabeçalho da lista de concluídas com a quantidade
  ///
  /// In pt, this message translates to:
  /// **'Concluídas ({count})'**
  String tasksCompletedHeader(int count);

  /// Rótulo da caixa de seleção de uma tarefa pendente
  ///
  /// In pt, this message translates to:
  /// **'Marcar como concluída'**
  String get taskMarkDone;

  /// Rótulo da caixa de seleção de uma tarefa concluída
  ///
  /// In pt, this message translates to:
  /// **'Marcar como pendente'**
  String get taskMarkPending;

  /// Dica do botão de excluir
  ///
  /// In pt, this message translates to:
  /// **'Excluir tarefa'**
  String get taskDeleteTooltip;

  /// Título da confirmação de exclusão
  ///
  /// In pt, this message translates to:
  /// **'Excluir tarefa?'**
  String get taskDeleteDialogTitle;

  /// Mensagem da confirmação de exclusão
  ///
  /// In pt, this message translates to:
  /// **'\"{title}\" será excluída permanentemente.'**
  String taskDeleteDialogMessage(String title);

  /// Ação de cancelar
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancelAction;

  /// Ação de excluir
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get deleteAction;

  /// Ação de repetir após falha
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get retryAction;

  /// Falha ao carregar as tarefas
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar as tarefas.'**
  String get tasksLoadError;

  /// Falha de rede numa operação de tarefa
  ///
  /// In pt, this message translates to:
  /// **'Sem conexão. Verifique a internet e tente de novo.'**
  String get taskErrorNetwork;

  /// Servidor recusou o acesso às tarefas
  ///
  /// In pt, this message translates to:
  /// **'Sem permissão para acessar as tarefas. Entre novamente.'**
  String get taskErrorPermission;

  /// A tarefa foi excluída em outro lugar
  ///
  /// In pt, this message translates to:
  /// **'Esta tarefa não existe mais.'**
  String get taskErrorNotFound;

  /// Falha inesperada numa operação de tarefa
  ///
  /// In pt, this message translates to:
  /// **'Algo deu errado. Tente de novo.'**
  String get taskErrorUnknown;

  /// Título do formulário de criação
  ///
  /// In pt, this message translates to:
  /// **'Nova tarefa'**
  String get taskFormNewTitle;

  /// Título do formulário de edição
  ///
  /// In pt, this message translates to:
  /// **'Editar tarefa'**
  String get taskFormEditTitle;

  /// Rótulo do campo de título
  ///
  /// In pt, this message translates to:
  /// **'Título'**
  String get taskFormTitleLabel;

  /// Rótulo do campo de descrição
  ///
  /// In pt, this message translates to:
  /// **'Descrição'**
  String get taskFormDescriptionLabel;

  /// Erro de validação: título vazio
  ///
  /// In pt, this message translates to:
  /// **'Informe o título'**
  String get taskFormTitleRequired;

  /// Valor exibido quando a tarefa não tem data
  ///
  /// In pt, this message translates to:
  /// **'Sem data'**
  String get taskFormNoDueDate;

  /// Botão que abre o seletor de data
  ///
  /// In pt, this message translates to:
  /// **'Escolher data'**
  String get taskFormPickDate;

  /// Dica do botão que remove a data
  ///
  /// In pt, this message translates to:
  /// **'Remover data'**
  String get taskFormClearDate;

  /// Botão que salva a tarefa
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get taskFormSave;

  /// Cabeçalho do widget de tela inicial com as tarefas do dia
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get widgetHeader;

  /// Mensagem do widget de tela inicial quando não há tarefa de hoje nem atrasada
  ///
  /// In pt, this message translates to:
  /// **'Nada para hoje'**
  String get widgetEmpty;

  /// Mensagem do widget de tela inicial quando o app ficou fechado além do período que o widget conhece
  ///
  /// In pt, this message translates to:
  /// **'Abra o app para atualizar'**
  String get widgetStale;

  /// Mensagem do widget de tela inicial quando não há usuário conectado
  ///
  /// In pt, this message translates to:
  /// **'Entre no app para ver suas tarefas'**
  String get widgetSignedOut;

  /// Agrupamento do widget de tela inicial para a única tarefa de hoje que não coube
  ///
  /// In pt, this message translates to:
  /// **'1 tarefa pendente'**
  String get widgetPendingOne;

  /// Agrupamento do widget de tela inicial para as tarefas de hoje que não couberam. O widget nativo troca {count} pelo número, então o app passa o próprio marcador
  ///
  /// In pt, this message translates to:
  /// **'{count} tarefas pendentes'**
  String widgetPendingOther(String count);

  /// Agrupamento do widget de tela inicial quando há uma única tarefa atrasada
  ///
  /// In pt, this message translates to:
  /// **'1 tarefa atrasada'**
  String get widgetOverdueOne;

  /// Agrupamento do widget de tela inicial para as tarefas atrasadas. O widget nativo troca {count} pelo número, então o app passa o próprio marcador
  ///
  /// In pt, this message translates to:
  /// **'{count} tarefas atrasadas'**
  String widgetOverdueOther(String count);
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
