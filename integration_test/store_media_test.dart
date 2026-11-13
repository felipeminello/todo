// Sets up the App Store and Google Play screens on an iOS simulator or on this
// Mac. Run it through `python3 tool/store_media/capture.py`, which reads the
// @@ markers printed here and takes the screenshots and recordings.
//
// Nothing goes through Firebase: the app runs over the in-memory fakes of the
// tests, signed in and with sample tasks around today's date.
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo/app/app.dart';
import 'package:todo/app/theme/google_fonts_typography.dart';
import 'package:todo/core/time/calendar_date.dart';
import 'package:todo/core/time/clock.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/features/auth/data/models/user_model.dart';
import 'package:todo/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:todo/features/auth/domain/usecases/restore_session.dart';
import 'package:todo/features/auth/domain/usecases/sign_in.dart';
import 'package:todo/features/auth/domain/usecases/sign_out.dart';
import 'package:todo/features/auth/domain/usecases/sign_up.dart';
import 'package:todo/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:todo/features/tasks/data/datasources/task_attachment_remote_data_source.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';
import 'package:todo/features/tasks/data/repositories/task_attachment_repository_impl.dart';
import 'package:todo/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:todo/features/tasks/data/widget/noop_task_widget_publisher.dart';
import 'package:todo/features/tasks/domain/entities/task.dart';
import 'package:todo/features/tasks/domain/usecases/add_task.dart';
import 'package:todo/features/tasks/domain/usecases/build_task_timeline.dart';
import 'package:todo/features/tasks/domain/usecases/clear_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/delete_task.dart';
import 'package:todo/features/tasks/domain/usecases/get_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/publish_widget_tasks.dart';
import 'package:todo/features/tasks/domain/usecases/toggle_task.dart';
import 'package:todo/features/tasks/domain/usecases/update_task.dart';
import 'package:todo/features/tasks/presentation/bloc/tasks_bloc.dart';
import 'package:todo/features/tasks/presentation/widgets/add_task_button.dart';
import 'package:todo/features/tasks/presentation/widgets/task_tile.dart';
import 'package:todo/features/tasks/presentation/widgets/task_timeline_view.dart';

import '../test/helpers/fake_attachment_files.dart';
import '../test/helpers/fake_auth_remote_data_source.dart';
import '../test/helpers/fake_task_attachment_remote_data_source.dart';
import '../test/helpers/fake_task_remote_data_source.dart';
import '../test/helpers/recording_link_opener.dart';
import '../test/helpers/task_attachments_bloc_factory.dart';

/// Scenes to run, comma separated; every scene when empty.
const _scenes = String.fromEnvironment('SCENE');

/// On macOS the app is drawn off screen, at the size and scale of a Retina
/// window, and the screenshots come from the render tree.
const _mac = bool.fromEnvironment('MAC');
const _macWindow = Size(1040, 680);

/// The Mac previews: 1760 × 1000 pixels of content, which compose.py puts in
/// a window over a 1920 × 1080 background. At 1.5x the window is wide enough
/// for the two-pane layout.
const _macPreviewRatio = 1.5;
const _macPreviewPixels = Size(1760, 1000);

/// The Google Play screens are drawn off screen too, running on this Mac as
/// if it were Android, on a 1080 × 2400 phone with the status and gesture
/// bars drawn on top.
const _android = bool.fromEnvironment('ANDROID');
const _androidRatio = 2.625;
const _androidScreen = Size(1080, 2400);
const _androidStatusBar = 28.0;
const _androidNavigationBar = 20.0;

const _offscreen = _mac || _android;

final _boundary = GlobalKey();

const _user = UserModel(id: 'uid-demo', email: 'voce@exemplo.com.br');

/// Sample tasks, relative to today. Undated ones are created a little apart
/// so they keep this order on screen (most recent first).
List<Task> _sampleTasks(DateTime now) {
  final today = CalendarDate.fromLocal(now);
  final utc = now.toUtc();
  var created = 0;
  Task task(
    String title, {
    String description = '',
    int? inDays,
    Duration? completedAgo,
  }) {
    created++;
    return Task(
      id: 'sample-$created',
      title: title,
      description: description,
      dueDate: inDays == null ? null : today.addDays(inDays),
      createdAt: utc.subtract(Duration(days: 30 - created)),
      completedAt: completedAgo == null ? null : utc.subtract(completedAgo),
    );
  }

  return [
    task('Trocar a lâmpada da varanda'),
    task(
      'Terminar o livro do clube de leitura',
      description: 'Faltam os capítulos 9 a 12.',
    ),
    task(
      _passport,
      description:
          'Separar os documentos antes de agendar:\n'
          '- RG e CPF\n'
          '- Título de eleitor\n'
          '- Comprovante da taxa paga\n'
          '\n'
          'Agendamento: https://www.gov.br/pf',
    ),
    task(
      'Pagar a conta de luz',
      description: 'O débito automático ainda não está ativo.',
      inDays: -2,
    ),
    task(
      _meeting,
      description:
          'Às 10h, com o time de produto.\n'
          '\n'
          '- Revisar as metas do trimestre\n'
          '- Definir as prioridades do mês\n'
          '- Combinar as férias do time\n'
          '\n'
          'Sala: https://meet.exemplo.com.br/planejamento',
      inDays: 0,
    ),
    task(_report, inDays: 0),
    task(
      'Consulta no dentista',
      description: 'Às 14h30. Levar a carteirinha do convênio.',
      inDays: 1,
    ),
    task(
      'Aniversário da Ana',
      description: 'Comprar o presente e reservar o restaurante.',
      inDays: 3,
    ),
    task('Levar o carro para a revisão', inDays: 3),
    task('Renovar o seguro do carro', inDays: 8),
    task(
      'Planejar as férias',
      description: 'Pesquisar passagens e hospedagem.',
      inDays: 20,
    ),
    task(
      'Responder o e-mail do contador',
      completedAgo: const Duration(days: 1),
    ),
    task(
      'Agendar a vistoria do apartamento',
      completedAgo: const Duration(hours: 5),
    ),
    task('Comprar ração do gato', completedAgo: const Duration(hours: 1)),
  ];
}

const _passport = 'Renovar o passaporte';
const _meeting = 'Reunião de planejamento';
const _report = 'Enviar o relatório mensal';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  // The screens show the app as released, without the debug banner.
  WidgetsApp.debugAllowBannerOverride = false;

  // `screenshots` scripts the phone and tablet flow, which on the Mac has
  // another layout: there the screenshots come from the `mac` scene. The
  // previews are recorded on the iOS simulators and on the Mac; Google Play
  // takes a YouTube link instead of a file.
  void scene(String name, Future<void> Function(_Director d) body) {
    final wrongDevice = switch (name) {
      'mac' => !_mac,
      'screenshots' => _mac,
      _ => _android,
    };
    testWidgets(
      name,
      skip:
          wrongDevice ||
          (_scenes.isNotEmpty && !_scenes.split(',').contains(name)),
      timeout: const Timeout(Duration(minutes: 5)),
      variant: _android
          ? TargetPlatformVariant.only(TargetPlatform.android)
          : const DefaultTestVariant(),
      (tester) => body(_Director(tester)),
    );
  }

  scene('screenshots', (d) async {
    await d.start();
    await d.shot('01_linha_do_tempo');

    await d.openTask(_passport);
    await d.shot('02_detalhes');
    await d.closeTask();

    await d.openNewTask();
    await d.type(find.byKey(const Key('task-form-title')), 'Comprar ingressos');
    await d.type(
      find.byKey(const Key('task-form-description')),
      'Show de sábado, 2 inteiras e 1 meia.',
    );
    await d.pickDate(daysFromToday: 2);
    d.hideKeyboard();
    await d.shot('03_nova_tarefa');

    await d.start();
    await d.toggle(_report);
    await d.showCompleted();
    await d.shot('04_concluidas');

    d.tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await d.start();
    await d.shot('05_escuro');
    d.tester.platformDispatcher.clearPlatformBrightnessTestValue();

    await d.start(signedIn: false);
    await d.type(find.byType(TextFormField).first, _user.email);
    await d.type(find.byType(TextFormField).last, 'senha-secreta');
    await d.shot('06_entrar');
  });

  scene('mac', (d) async {
    // The list beside the panel that creates and edits tasks.
    await d.start();
    await d.openNewTask();
    await d.type(find.byKey(const Key('task-form-title')), 'Comprar ingressos');
    await d.type(
      find.byKey(const Key('task-form-description')),
      'Show de sábado, 2 inteiras e 1 meia.',
    );
    await d.pickDate(daysFromToday: 2);
    await d.shot('01_paineis');

    // The details take the list's place.
    await d.start();
    await d.openTask(_meeting);
    await d.shot('02_detalhes');

    // Editing from the details fills the panel.
    await d.tap(find.text('Editar'));
    await d.shot('03_editar');

    d.tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await d.start();
    await d.showCompleted();
    await d.shot('04_escuro');
    d.tester.platformDispatcher.clearPlatformBrightnessTestValue();

    await d.start(signedIn: false);
    await d.type(find.byType(TextFormField).first, _user.email);
    await d.type(find.byType(TextFormField).last, 'senha-secreta');
    await d.shot('05_entrar');
  });

  // Creating tasks, with and without a date.
  scene('preview_1_organize', (d) async {
    await d.start(preview: true);
    await d.record('preview_1_organize', () async {
      await d.openNewTask();
      await d.typeSlowly(
        find.byKey(const Key('task-form-title')),
        'Comprar ingressos do show',
      );
      await d.typeSlowly(
        find.byKey(const Key('task-form-description')),
        'Sábado, 2 inteiras e 1 meia.',
      );
      await d.pickDate(daysFromToday: 2);
      await d.tap(find.byKey(const Key('task-form-save')), after: 1000);
      // Where it landed in the timeline, then back to the top.
      await d.reveal('Comprar ingressos do show', after: 1800);
      await d.scrollToTop();

      await d.openNewTask();
      await d.typeSlowly(
        find.byKey(const Key('task-form-title')),
        'Ligar para a escola',
      );
      await d.tap(find.byKey(const Key('task-form-save')), after: 2200);
    });
  });

  // Reading a task, checking tasks off and finding them among the completed.
  scene('preview_2_dia_a_dia', (d) async {
    await d.start(preview: true);
    await d.record('preview_2_dia_a_dia', () async {
      await d.openTask(_meeting, after: 3200);
      await d.closeTask();
      await d.toggle(_meeting, after: 1100);
      await d.toggle(_report, after: 1100);
      await d.toggle('Pagar a conta de luz', after: 1300);
      await d.showCompleted(after: 3800);
    });
  });
}

/// Scripted interactions and the markers the capture script reads.
class _Director {
  _Director(this.tester);

  final WidgetTester tester;

  bool get _wide =>
      find.byType(AddTaskButton).evaluate().isEmpty &&
      find.widgetWithText(BrandButton, 'Nova tarefa').evaluate().isNotEmpty;

  /// Opens the app from scratch with the sample tasks, signed in unless
  /// [signedIn] is false. [preview] sizes the Mac window for the previews.
  Future<void> start({bool signedIn = true, bool preview = false}) async {
    if (_mac) {
      tester.view
        ..devicePixelRatio = preview ? _macPreviewRatio : 2
        ..physicalSize = preview ? _macPreviewPixels : _macWindow * 2;
    }
    if (_android) {
      const insets = FakeViewPadding(
        top: _androidStatusBar * _androidRatio,
        bottom: _androidNavigationBar * _androidRatio,
      );
      tester.view
        ..devicePixelRatio = _androidRatio
        ..physicalSize = _androidScreen
        ..padding = insets
        ..viewPadding = insets;
    }
    final tasks = FakeTaskRemoteDataSource();
    for (final task in _sampleTasks(DateTime.now())) {
      await tasks.create(TaskModel.fromEntity(task));
    }
    final attachments = FakeTaskAttachmentRemoteDataSource();
    final authBackend = FakeAuthBackend()
      ..savedSession = signedIn ? _user : null;
    final dark =
        tester.platformDispatcher.platformBrightness == Brightness.dark;

    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              TodoApp(
                key: UniqueKey(),
                createAuthBloc: () => _authBloc(authBackend),
                createTasksBloc: () => _tasksBloc(tasks, attachments),
                createTaskAttachmentsBloc: taskAttachmentsBlocFactory(
                  attachments,
                  FakeAttachmentFiles(),
                ),
                clearWidgetTasks: const ClearWidgetTasks(
                  NoopTaskWidgetPublisher(),
                ),
                linkOpener: RecordingLinkOpener(),
                typography: const GoogleFontsTypography(),
              ),
              if (_android) _AndroidSystemBars(dark: dark),
            ],
          ),
        ),
      ),
    );
    // Manrope and Inter are downloaded on first use; until then the
    // platform font shows.
    await pause(300);
    await GoogleFonts.pendingFonts();
    await pause(1500);
  }

  AuthBloc _authBloc(FakeAuthBackend backend) {
    final repository = AuthRepositoryImpl(FakeAuthRemoteDataSource(backend));
    return AuthBloc(
      restoreSession: RestoreSession(repository),
      signIn: SignIn(repository),
      signUp: SignUp(repository),
      signOut: SignOut(repository),
    );
  }

  TasksBloc _tasksBloc(
    TaskRemoteDataSource dataSource,
    TaskAttachmentRemoteDataSource attachments,
  ) {
    const clock = SystemClock();
    final repository = TaskRepositoryImpl(dataSource);
    return TasksBloc(
      getTasks: GetTasks(repository),
      addTask: AddTask(repository, clock),
      updateTask: UpdateTask(repository),
      deleteTask: DeleteTask(
        repository,
        TaskAttachmentRepositoryImpl(attachments),
      ),
      toggleTask: ToggleTask(repository, clock),
      buildTimeline: const BuildTaskTimeline(),
      publishWidgetTasks: PublishWidgetTasks(
        const NoopTaskWidgetPublisher(),
        clock,
      ),
      clock: clock,
    );
  }

  Future<void> pause(int ms) async {
    await tester.pump();
    await Future<void>.delayed(Duration(milliseconds: ms));
  }

  static var _pointer = 1000;
  static var _mouseAdded = false;
  Offset _mouse = Offset.zero;

  /// Sends a pointer event as if it came from the device, without the
  /// crosshair the `WidgetTester` would draw on screen.
  void _send(PointerEvent event) {
    final binding = tester.binding as LiveTestWidgetsFlutterBinding;
    binding.shouldPropagateDevicePointerEvents = true;
    try {
      binding.handlePointerEventForSource(
        event,
        source: TestBindingEventSource.device,
      );
    } finally {
      binding.shouldPropagateDevicePointerEvents = false;
    }
  }

  /// On the Mac the mouse glides to the target first, so hover effects show
  /// in the previews.
  Future<void> _moveMouse(Offset target) async {
    if (!_mouseAdded) {
      _mouseAdded = true;
      _mouse = target;
      _send(PointerAddedEvent(kind: PointerDeviceKind.mouse, position: target));
    }
    const steps = 10;
    final from = _mouse;
    for (var i = 1; i <= steps; i++) {
      final next = Offset.lerp(from, target, i / steps)!;
      _send(
        PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: next,
          delta: next - _mouse,
        ),
      );
      _mouse = next;
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
  }

  /// Taps like a finger (a click on the Mac).
  Future<void> tap(Finder finder, {int after = 900}) async {
    final position = tester.getCenter(finder.first);
    final kind = _mac ? PointerDeviceKind.mouse : PointerDeviceKind.touch;
    if (_mac) await _moveMouse(position);
    final pointer = _pointer++;
    _send(
      PointerDownEvent(
        kind: kind,
        pointer: pointer,
        position: position,
        buttons: kPrimaryButton,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 90));
    _send(PointerUpEvent(kind: kind, pointer: pointer, position: position));
    await pause(after);
  }

  /// Types [text] into a field at once.
  Future<void> type(Finder finder, String text) async {
    _setText(finder, text);
    await pause(500);
  }

  /// Types [text] one letter at a time, for the previews.
  Future<void> typeSlowly(Finder finder, String text) async {
    await tap(finder, after: 300);
    for (var i = 1; i <= text.length; i++) {
      _setText(finder, text.substring(0, i));
      await pause(55);
    }
    await pause(500);
  }

  void _setText(Finder finder, String text) {
    // `enterText` waits for frames this scene's live binding does not
    // deliver and hangs; updating the field directly has the same effect as
    // typing.
    final field = tester.state<EditableTextState>(
      find.descendant(of: finder, matching: find.byType(EditableText)).first,
    );
    field.userUpdateTextEditingValue(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
  }

  void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  /// The floating button on phones, the header button in wide windows.
  Future<void> openNewTask() async {
    final fab = find.byType(AddTaskButton);
    await tap(
      fab.evaluate().isNotEmpty
          ? fab
          : find.widgetWithText(BrandButton, 'Nova tarefa'),
      after: 1000,
    );
  }

  /// Picks the day [daysFromToday] after today in the date picker.
  Future<void> pickDate({required int daysFromToday}) async {
    await tap(find.text('Escolher data'), after: 1000);
    final day = DateTime.now().add(Duration(days: daysFromToday));
    if (day.month != DateTime.now().month) {
      await tap(find.byTooltip('Próximo mês'), after: 700);
    }
    await tap(
      find.descendant(
        of: find.byType(CalendarDatePicker),
        matching: find.text('${day.day}'),
      ),
      after: 700,
    );
    await tap(find.text('OK'), after: 900);
  }

  Future<void> openTask(String title, {int after = 1200}) =>
      tap(find.text(title), after: after);

  /// Back to the list: the sheet closes on phones, the details on wide
  /// windows.
  Future<void> closeTask() async {
    final back = find.text(_wide ? 'Voltar' : 'Fechar');
    await tap(back, after: 900);
  }

  /// Checks [title] off (or back on).
  Future<void> toggle(String title, {int after = 900}) async {
    final tile = find.ancestor(
      of: find.text(title),
      matching: find.byType(TaskTile),
    );
    await tap(
      find.descendant(of: tile.first, matching: find.byType(Checkbox)),
      after: after,
    );
  }

  ScrollPosition get _listPosition => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(TaskTimelineView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  /// Scrolls the list until the task [title] is in the middle of it.
  Future<void> reveal(String title, {int after = 900}) async {
    // The list builds lazily: scroll down until the tile exists.
    for (var i = 0; i < 6 && find.text(title).evaluate().isEmpty; i++) {
      final position = _listPosition;
      await position.animateTo(
        min(
          position.pixels + position.viewportDimension * 0.5,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeIn,
      );
      await pause(50);
    }
    await Scrollable.ensureVisible(
      tester.element(find.text(title).first),
      alignment: 0.5,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
    );
    await pause(after);
  }

  Future<void> scrollToTop({int after = 900}) async {
    await _listPosition.animateTo(
      0,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
    );
    await pause(after);
  }

  /// Scrolls to the completed tasks and opens them. The list builds lazily,
  /// so their header only exists once it is near the screen.
  Future<void> showCompleted({int after = 900}) async {
    Future<void> toBottom() async {
      final position = _listPosition;
      await position.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
      await pause(400);
    }

    await toBottom();
    await tap(find.textContaining('Concluídas ('), after: 500);
    await toBottom();
    await pause(after);
  }

  /// Runs [body] inside a recording named [name]. The capture script starts
  /// recording at REC_START and keeps from a little before BEGIN to a little
  /// after END.
  Future<void> record(String name, Future<void> Function() body) async {
    _marker('REC_START $name');
    final frames = _offscreen ? _FrameRecorder(name, _boundary) : null;
    frames?.start();
    // simctl takes a moment to start.
    await pause(_offscreen ? 600 : 3000);
    _marker('BEGIN $name');
    await pause(900);
    await body();
    _marker('END $name');
    await pause(900);
    await frames?.stop();
    if (frames != null) _marker('FRAMES $name ${frames.directory.path}');
    _marker('REC_STOP $name');
    // Room for simctl to finish the file before the next scene.
    await pause(_offscreen ? 300 : 3000);
  }

  /// [settle] lets animations finish; the capture script needs the screen
  /// still for a moment after the marker.
  Future<void> shot(String name, {int settle = 900}) async {
    await pause(settle);
    if (_offscreen) {
      final boundary =
          _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: tester.view.devicePixelRatio),
      );
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      // The sandbox keeps the file out of the capture script's reach, so the
      // PNG goes through the log, in lines of base64.
      final encoded = base64Encode(bytes!.buffer.asUint8List());
      for (var i = 0; i < encoded.length; i += 4000) {
        _marker(
          'DATA $name ${encoded.substring(i, min(i + 4000, encoded.length))}',
        );
      }
      _marker('SHOT $name');
      await pause(300);
      return;
    }
    _marker('SHOT $name');
    // simctl can take a few seconds to answer, more on the iPad.
    await pause(4000);
  }
}

void _marker(String text) {
  // ignore: avoid_print
  print('@@$text t=${DateTime.now().millisecondsSinceEpoch}');
}

/// Saves what [boundary] shows, as fast as it can, as PNGs named after the
/// time they were taken (in ms since the epoch). They go to the app's
/// temporary folder, which on the Mac is inside its sandbox container, where
/// the capture script picks them up.
class _FrameRecorder {
  _FrameRecorder(String name, this.boundary)
    : directory = Directory('${Directory.systemTemp.path}/store_media/$name');

  final GlobalKey boundary;
  final Directory directory;
  bool _running = false;
  Future<void>? _loop;

  void start() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    directory.createSync(recursive: true);
    _running = true;
    _loop = _run();
  }

  Future<void> _run() async {
    final pending = <Future<void>>[];
    while (_running) {
      final render =
          boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (render == null || render.debugNeedsPaint) {
        await Future<void>.delayed(const Duration(milliseconds: 8));
        continue;
      }
      final taken = DateTime.now().millisecondsSinceEpoch;
      final image = await render.toImage(
        pixelRatio: _macPreviewPixels.width / render.size.width,
      );
      pending.add(_save(image, taken));
      // Encoding runs off the UI thread; a few at a time keeps up with the
      // screen without piling up memory.
      if (pending.length >= 4) {
        await pending.removeAt(0);
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await Future.wait(pending);
  }

  Future<void> _save(ui.Image image, int taken) async {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return;
    await File('${directory.path}/$taken.png')
        .writeAsBytes(bytes.buffer.asUint8List());
  }

  Future<void> stop() async {
    _running = false;
    await _loop;
  }
}

/// The status bar and the gesture bar of a full screen Android, over the
/// app, which reaches under them.
class _AndroidSystemBars extends StatelessWidget {
  const _AndroidSystemBars({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : const Color(0xFF1B1B1F);
    const iconSize = 17.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: Column(
          children: [
            SizedBox(
              height: _androidStatusBar,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Text(
                      '9:41',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.signal_wifi_4_bar, size: iconSize, color: color),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.signal_cellular_4_bar,
                      size: iconSize,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.battery_full, size: iconSize, color: color),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              height: _androidNavigationBar,
              child: Center(
                child: Container(
                  width: 108,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
