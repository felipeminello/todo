// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Minhas Tarefas';

  @override
  String get loadingLabel => 'Carregando';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get authSignUpTitle => 'Criar conta';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authSignInButton => 'Entrar';

  @override
  String get authSignUpButton => 'Criar conta';

  @override
  String get authSwitchToSignUp => 'Não tem conta? Criar conta';

  @override
  String get authSwitchToSignIn => 'Já tem conta? Entrar';

  @override
  String get authEmailRequired => 'Informe o e-mail';

  @override
  String get authEmailInvalid => 'E-mail inválido';

  @override
  String get authPasswordRequired => 'Informe a senha';

  @override
  String get authErrorInvalidCredentials => 'E-mail ou senha incorretos.';

  @override
  String get authErrorEmailInUse => 'Este e-mail já está em uso.';

  @override
  String get authErrorWeakPassword =>
      'Senha fraca. Use pelo menos 6 caracteres.';

  @override
  String get authErrorInvalidEmail => 'E-mail inválido.';

  @override
  String get authErrorNetwork =>
      'Sem conexão. Verifique a internet e tente de novo.';

  @override
  String get authErrorUnknown => 'Não foi possível concluir. Tente de novo.';

  @override
  String get signOutTooltip => 'Sair';

  @override
  String get refreshTooltip => 'Atualizar';

  @override
  String get addTaskTooltip => 'Nova tarefa';

  @override
  String get tasksEmptyTitle => 'Nenhuma tarefa ainda';

  @override
  String get tasksEmptyMessage => 'Use o botão + para criar a primeira tarefa.';

  @override
  String get tasksUndatedHeader => 'Sem data';

  @override
  String get tasksOverdueLabel => 'Atrasada';

  @override
  String get tasksTodayLabel => 'Hoje';

  @override
  String tasksDayTodaySemantics(String date) {
    return '$date, hoje';
  }

  @override
  String tasksSummary(int pending, int completed) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending pendentes',
      one: '1 pendente',
    );
    String _temp1 = intl.Intl.pluralLogic(
      completed,
      locale: localeName,
      other: '$completed concluídas',
      one: '1 concluída',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String tasksDayOverdueSemantics(String date) {
    return '$date, tarefas atrasadas';
  }

  @override
  String tasksCompletedHeader(int count) {
    return 'Concluídas ($count)';
  }

  @override
  String get taskMarkDone => 'Marcar como concluída';

  @override
  String get taskMarkPending => 'Marcar como pendente';

  @override
  String get taskDeleteTooltip => 'Excluir tarefa';

  @override
  String get taskDeleteDialogTitle => 'Excluir tarefa?';

  @override
  String taskDeleteDialogMessage(String title) {
    return '\"$title\" será excluída permanentemente.';
  }

  @override
  String get cancelAction => 'Cancelar';

  @override
  String get deleteAction => 'Excluir';

  @override
  String get retryAction => 'Tentar de novo';

  @override
  String get tasksLoadError => 'Não foi possível carregar as tarefas.';

  @override
  String get taskErrorNetwork =>
      'Sem conexão. Verifique a internet e tente de novo.';

  @override
  String get taskErrorPermission =>
      'Sem permissão para acessar as tarefas. Entre novamente.';

  @override
  String get taskErrorNotFound => 'Esta tarefa não existe mais.';

  @override
  String get taskErrorUnknown => 'Algo deu errado. Tente de novo.';

  @override
  String get taskFormNewTitle => 'Nova tarefa';

  @override
  String get taskFormEditTitle => 'Editar tarefa';

  @override
  String get taskFormTitleLabel => 'Título';

  @override
  String get taskFormDescriptionLabel => 'Descrição';

  @override
  String get taskFormTitleRequired => 'Informe o título';

  @override
  String get taskFormNoDueDate => 'Sem data';

  @override
  String get taskFormPickDate => 'Escolher data';

  @override
  String get taskFormClearDate => 'Remover data';

  @override
  String get taskFormSave => 'Salvar';

  @override
  String get widgetHeader => 'Hoje';

  @override
  String get widgetEmpty => 'Nada para hoje';

  @override
  String get widgetStale => 'Abra o app para atualizar';

  @override
  String get widgetSignedOut => 'Entre no app para ver suas tarefas';
}
