import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/core/ui/widgets/brand_button.dart';
import 'package:todo/features/tasks/domain/entities/attachment_file.dart';
import 'package:todo/features/tasks/domain/usecases/add_task_attachment.dart';
import 'package:todo/features/tasks/presentation/widgets/task_attachment_tile.dart';
import 'package:todo/features/tasks/presentation/widgets/task_attachments_section.dart';

import '../../../../helpers/fake_attachment_files.dart';
import '../../../../helpers/fake_task_attachment_remote_data_source.dart';
import '../../../../helpers/localized_app.dart';
import '../../../../helpers/task_attachments_bloc_factory.dart';

void main() {
  late FakeTaskAttachmentRemoteDataSource dataSource;
  late FakeAttachmentFiles files;
  const network = AttachmentRemoteException(AttachmentErrorKind.network);

  Future<String> store(String taskId, String name, List<int> bytes) async {
    final stored = await dataSource.upload(
      taskId,
      name: name,
      size: bytes.length,
      openRead: () => Stream.value(bytes),
    );
    return stored.id;
  }

  Future<void> pump(
    WidgetTester tester, {
    String taskId = 't1',
    Size? size,
    bool settle = true,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    await tester.pumpWidget(
      localizedApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: TaskAttachmentsSection(
              taskId: taskId,
              createBloc: taskAttachmentsBlocFactory(dataSource, files),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  BrandButton addButton(WidgetTester tester) =>
      tester.widget(find.byKey(const Key('task-attachments-add')));

  setUp(() {
    dataSource = FakeTaskAttachmentRemoteDataSource();
    files = FakeAttachmentFiles();
  });

  testWidgets('a task without attachments says so', (tester) async {
    await pump(tester);

    expect(find.text('Anexos'), findsOneWidget);
    expect(find.text('Nenhum anexo'), findsOneWidget);
    expect(find.byType(TaskAttachmentTile), findsNothing);
  });

  testWidgets('lists the attachments of its task with name and size', (
    tester,
  ) async {
    await store('t1', 'Contrato.pdf', List.filled(1536, 0));
    await store('t1', 'foto.png', [1, 2, 3]);
    await store('t2', 'de outra tarefa.txt', [1]);
    await pump(tester);

    expect(find.text('Contrato.pdf'), findsOneWidget);
    expect(find.text('1,5 KB'), findsOneWidget);
    expect(find.text('foto.png'), findsOneWidget);
    expect(find.text('3 B'), findsOneWidget);
    expect(find.text('de outra tarefa.txt'), findsNothing);
    expect(find.text('Nenhum anexo'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Contrato.pdf')).dy,
      lessThan(tester.getTopLeft(find.text('foto.png')).dy),
    );
  });

  testWidgets('shows a spinner and blocks attaching while loading', (
    tester,
  ) async {
    dataSource.gate = Completer();
    await pump(tester, settle: false);
    await tester.pump();

    expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    dataSource.gate?.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nenhum anexo'), findsOneWidget);
    expect(addButton(tester).onPressed, isNotNull);
  });

  group('attaching', () {
    testWidgets(
      'the attachment shows with the name of the file that was uploaded',
      (tester) async {
        files.nextPick = attachmentFile('Relatório final.PDF', [1, 2, 3, 4]);
        await pump(tester);

        await tester.tap(find.text('Anexar arquivo'));
        await tester.pumpAndSettle();

        expect(find.text('Relatório final.PDF'), findsOneWidget);
        expect(find.text('4 B'), findsOneWidget);
        expect(find.text('Nenhum anexo'), findsNothing);
        // In storage the file has another name, in the folder of its task.
        final stored = dataSource.storedNames('t1').single;
        expect(stored, isNot('Relatório final.PDF'));
        expect(dataSource.content('t1', stored), [1, 2, 3, 4]);
      },
    );

    testWidgets('a bar shows and the button waits while the file is sent', (
      tester,
    ) async {
      files.nextPick = attachmentFile('a.txt', [1]);
      await pump(tester);
      dataSource.gate = Completer();

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Enviando anexo'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
      expect(find.text('a.txt'), findsNothing);

      dataSource.gate?.complete();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Enviando anexo'), findsNothing);
      expect(find.text('a.txt'), findsOneWidget);
      expect(addButton(tester).onPressed, isNotNull);
    });

    testWidgets('the list does not jump when the bar shows', (tester) async {
      await store('t1', 'antes.txt', [1]);
      files.nextPick = attachmentFile('a.txt', [1]);
      await pump(tester);
      final before = tester.getTopLeft(find.text('antes.txt'));
      dataSource.gate = Completer();

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pump();
      await tester.pump();

      expect(tester.getTopLeft(find.text('antes.txt')), before);
      dataSource.gate?.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('giving up choosing a file changes nothing', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum anexo'), findsOneWidget);
      expect(find.byKey(const Key('task-attachments-failure')), findsNothing);
    });

    testWidgets('a file over 25 MB is refused with the limit', (tester) async {
      files.nextPick = AttachmentFile(
        name: 'video.mp4',
        size: AddTaskAttachment.maxBytes + 1,
        openRead: () => const Stream.empty(),
      );
      await pump(tester);

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('O arquivo passa do limite de 25 MB.'), findsOneWidget);
      expect(find.text('video.mp4'), findsNothing);
      expect(dataSource.storedNames('t1'), isEmpty);
    });

    testWidgets('an empty file is refused', (tester) async {
      files.nextPick = attachmentFile('vazio.txt', []);
      await pump(tester);

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(find.text('O arquivo está vazio.'), findsOneWidget);
    });

    testWidgets('a failed upload says why, until the next attempt', (
      tester,
    ) async {
      files.nextPick = attachmentFile('a.txt', [1]);
      await pump(tester);
      dataSource.failNext = network;

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('a.txt'), findsNothing);

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-attachments-failure')), findsNothing);
      expect(find.text('a.txt'), findsOneWidget);
    });

    testWidgets('a full task says the limit was reached', (tester) async {
      files.nextPick = attachmentFile('a.txt', [1]);
      await pump(tester);
      dataSource.failNext = const AttachmentRemoteException(
        AttachmentErrorKind.limitReached,
      );

      await tester.tap(find.text('Anexar arquivo'));
      await tester.pumpAndSettle();

      expect(
        find.text('Esta tarefa já atingiu o limite de anexos.'),
        findsOneWidget,
      );
    });
  });

  group('downloading', () {
    testWidgets('saves the file under the name it was uploaded with', (
      tester,
    ) async {
      await store('t1', 'Contrato.pdf', [5, 6, 7]);
      await pump(tester);

      await tester.tap(find.byTooltip('Baixar Contrato.pdf'));
      await tester.pumpAndSettle();

      expect(files.saved.single.name, 'Contrato.pdf');
      expect(files.saved.single.bytes, [5, 6, 7]);
      expect(find.text('Contrato.pdf'), findsOneWidget);
      expect(find.byKey(const Key('task-attachments-failure')), findsNothing);
    });

    testWidgets('a spinner replaces the buttons while it downloads', (
      tester,
    ) async {
      await store('t1', 'Contrato.pdf', [5]);
      await store('t1', 'outro.txt', [6]);
      await pump(tester);
      dataSource.gate = Completer();

      await tester.tap(find.byTooltip('Baixar Contrato.pdf'));
      await tester.pump();

      expect(find.bySemanticsLabel('Processando Contrato.pdf'), findsOneWidget);
      expect(find.byTooltip('Baixar Contrato.pdf'), findsNothing);
      expect(find.byTooltip('Excluir Contrato.pdf'), findsNothing);
      expect(find.byTooltip('Baixar outro.txt'), findsOneWidget);

      dataSource.gate?.complete();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Baixar Contrato.pdf'), findsOneWidget);
    });

    testWidgets('a failed download says why', (tester) async {
      await store('t1', 'Contrato.pdf', [5]);
      await pump(tester);
      dataSource.failNext = network;

      await tester.tap(find.byTooltip('Baixar Contrato.pdf'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(files.saved, isEmpty);
      expect(find.text('Contrato.pdf'), findsOneWidget);
    });

    testWidgets('an attachment deleted elsewhere leaves the list', (
      tester,
    ) async {
      final id = await store('t1', 'Contrato.pdf', [5]);
      await pump(tester);
      await dataSource.delete('t1', id);

      await tester.tap(find.byTooltip('Baixar Contrato.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('A tarefa ou o anexo não existe mais.'), findsOneWidget);
      expect(find.text('Contrato.pdf'), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('asks for confirmation naming the attachment', (tester) async {
      await store('t1', 'Contrato.pdf', [5]);
      await pump(tester);

      await tester.tap(find.byTooltip('Excluir Contrato.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir anexo?'), findsOneWidget);
      expect(
        find.text('"Contrato.pdf" será excluído permanentemente.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Contrato.pdf'), findsOneWidget);
      expect(dataSource.storedNames('t1'), hasLength(1));
    });

    testWidgets('confirming deletes the file and removes it from the list', (
      tester,
    ) async {
      await store('t1', 'Contrato.pdf', [5]);
      await store('t1', 'fica.txt', [6]);
      await pump(tester);

      await tester.tap(find.byTooltip('Excluir Contrato.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Contrato.pdf'), findsNothing);
      expect(find.text('fica.txt'), findsOneWidget);
      expect(dataSource.storedNames('t1'), hasLength(1));
    });

    testWidgets('deleting the last one shows the empty message', (
      tester,
    ) async {
      await store('t1', 'Contrato.pdf', [5]);
      await pump(tester);

      await tester.tap(find.byTooltip('Excluir Contrato.pdf'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum anexo'), findsOneWidget);
    });

    testWidgets('a failed deletion says why and keeps the attachment', (
      tester,
    ) async {
      await store('t1', 'Contrato.pdf', [5]);
      await pump(tester);

      await tester.tap(find.byTooltip('Excluir Contrato.pdf'));
      await tester.pumpAndSettle();
      dataSource.failNext = network;
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sem conexão. Verifique a internet e tente de novo.'),
        findsOneWidget,
      );
      expect(find.text('Contrato.pdf'), findsOneWidget);
    });
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await store('t1', 'Contrato.pdf', [5]);
    dataSource.failNext = network;
    await pump(tester);

    expect(find.text('Não foi possível carregar os anexos.'), findsOneWidget);
    expect(
      find.text('Sem conexão. Verifique a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(addButton(tester).onPressed, isNull);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Contrato.pdf'), findsOneWidget);
    expect(find.text('Não foi possível carregar os anexos.'), findsNothing);
  });

  testWidgets('another task gets its own attachments', (tester) async {
    await store('t1', 'da primeira.txt', [1]);
    await store('t2', 'da segunda.txt', [2]);
    await pump(tester);
    expect(find.text('da primeira.txt'), findsOneWidget);

    await pump(tester, taskId: 't2');

    expect(find.text('da primeira.txt'), findsNothing);
    expect(find.text('da segunda.txt'), findsOneWidget);
  });

  testWidgets('fits a 360 px phone with a long file name', (tester) async {
    await store(
      't1',
      'Comprovante de pagamento do condomínio referente a novembro de 2026 '
          '(segunda via).pdf',
      [1],
    );
    await pump(tester, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(TaskAttachmentTile), findsOneWidget);
  });

  testWidgets('buttons are at least 48 px tall and wide', (tester) async {
    await store('t1', 'Contrato.pdf', [5]);
    await pump(tester);

    for (final finder in [
      find.byTooltip('Baixar Contrato.pdf'),
      find.byTooltip('Excluir Contrato.pdf'),
      find.byKey(const Key('task-attachments-add')),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });
}
