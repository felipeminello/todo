import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/error/failure.dart';
import 'package:todo/features/tasks/data/files/file_picker_attachment_files.dart';

final class _PickedFile extends PlatformFile {
  _PickedFile(this.name, this._bytes, {this.knownLength = true});

  @override
  final String name;
  final List<int> _bytes;
  final bool knownLength;

  @override
  Uri get uri => Uri.file('/tmp/$name');

  // Not read by the app, and its type is not exported by the plugin.
  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => knownLength ? _bytes.length : null;

  @override
  Future<int?> length() async => lengthSync();

  @override
  Future<Uint8List> readAsBytes() async => Uint8List.fromList(_bytes);

  @override
  Stream<Uint8List> readAsByteStream() =>
      Stream.value(Uint8List.fromList(_bytes));
}

/// Answers the plugin calls the way the system dialogs would.
final class _FakePlatform extends FilePickerPlatform {
  PlatformFile? picked;
  Object? failure;
  bool acceptSave = true;
  final saved = <({String fileName, String mimeType, Uint8List bytes})>[];

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (failure case final Object failure) throw failure;
    return picked;
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (failure case final Object failure) throw failure;
    if (!acceptSave) return null;
    saved.add((fileName: fileName, mimeType: mimeType, bytes: bytes));
    return Uri.file('/tmp/$fileName');
  }
}

void main() {
  const files = FilePickerAttachmentFiles();
  late _FakePlatform platform;
  late FilePickerPlatform original;
  final unknown = throwsA(
    const AttachmentFailure(AttachmentFailureReason.unknown),
  );

  setUp(() {
    original = FilePickerPlatform.instance;
    FilePickerPlatform.instance = platform = _FakePlatform();
  });

  tearDown(() => FilePickerPlatform.instance = original);

  group('pick', () {
    test('returns the chosen file with its name, size and content', () async {
      platform.picked = _PickedFile('Relatório final.PDF', [1, 2, 3]);

      final file = await files.pick();

      expect(file?.name, 'Relatório final.PDF');
      expect(file?.size, 3);
      expect(await file?.openRead().expand((chunk) => chunk).toList(), [
        1,
        2,
        3,
      ]);
    });

    test('returns nothing when the user gives up', () async {
      expect(await files.pick(), isNull);
    });

    test('a file whose size cannot be read fails', () {
      platform.picked = _PickedFile('a.txt', [1], knownLength: false);

      expect(files.pick(), unknown);
    });

    test('a plugin error becomes a failure', () {
      platform.failure = PlatformException(code: 'ENTITLEMENT_NOT_FOUND');

      expect(files.pick(), unknown);
    });
  });

  group('save', () {
    final bytes = Uint8List.fromList([4, 5]);

    test('offers the attachment name and hands over the content', () async {
      final saved = await files.save(
        name: 'Relatório final.PDF',
        contentType: 'application/pdf',
        bytes: bytes,
      );

      expect(saved, isTrue);
      expect(platform.saved, [
        (
          fileName: 'Relatório final.PDF',
          mimeType: 'application/pdf',
          bytes: bytes,
        ),
      ]);
    });

    test('reports when the user gives up', () async {
      platform.acceptSave = false;

      final saved = await files.save(
        name: 'a.txt',
        contentType: 'text/plain',
        bytes: bytes,
      );

      expect(saved, isFalse);
    });

    test('characters a file name cannot have are replaced', () async {
      await files.save(
        name: 'ata 10:30 <final>?.txt',
        contentType: 'text/plain',
        bytes: bytes,
      );

      expect(platform.saved.single.fileName, 'ata 10_30 _final__.txt');
    });

    test('a plugin error becomes a failure', () {
      platform.failure = const IllegalCharacterInFileNameException('bad');

      expect(
        files.save(name: 'a.txt', contentType: 'text/plain', bytes: bytes),
        unknown,
      );
    });
  });
}
