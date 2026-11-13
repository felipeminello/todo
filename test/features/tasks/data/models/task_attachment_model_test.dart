import 'package:flutter_test/flutter_test.dart';
import 'package:todo/features/tasks/data/models/task_attachment_model.dart';
import 'package:todo/features/tasks/domain/entities/task_attachment.dart';

void main() {
  const json = {
    'id': '2a1bb3f1-c4cf-4c75-96f1-4ef1a14bffc2.pdf',
    'name': 'Relatório final.PDF',
    'size': 4105,
    'contentType': 'application/pdf',
    'createdAt': '2026-11-13T01:12:06.000Z',
  };

  test('reads what the API sends', () {
    expect(
      TaskAttachmentModel.fromJson(json).toEntity(),
      TaskAttachment(
        id: '2a1bb3f1-c4cf-4c75-96f1-4ef1a14bffc2.pdf',
        name: 'Relatório final.PDF',
        size: 4105,
        contentType: 'application/pdf',
        createdAt: DateTime.utc(2026, 11, 13, 1, 12, 6),
      ),
    );
  });

  test('the instant is kept in UTC', () {
    final model = TaskAttachmentModel.fromJson({
      ...json,
      'createdAt': '2026-11-12T22:12:06-03:00',
    });

    expect(model.createdAt, DateTime.utc(2026, 11, 13, 1, 12, 6));
    expect(model.createdAt.isUtc, isTrue);
  });

  test('a missing content type falls back to a generic one', () {
    final model = TaskAttachmentModel.fromJson(
      {...json}..remove('contentType'),
    );

    expect(model.contentType, 'application/octet-stream');
  });

  for (final field in ['id', 'name', 'size', 'createdAt']) {
    test('rejects an attachment without $field', () {
      expect(
        () => TaskAttachmentModel.fromJson({...json}..remove(field)),
        throwsFormatException,
      );
    });
  }

  test('rejects wrong types and non-objects', () {
    expect(
      () => TaskAttachmentModel.fromJson({...json, 'size': '4105'}),
      throwsFormatException,
    );
    expect(
      () => TaskAttachmentModel.fromJson({...json, 'createdAt': 'ontem'}),
      throwsFormatException,
    );
    expect(() => TaskAttachmentModel.fromJson('x'), throwsFormatException);
    expect(() => TaskAttachmentModel.fromJson(null), throwsFormatException);
  });
}
