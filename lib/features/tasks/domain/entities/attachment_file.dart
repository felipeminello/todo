/// A file on the device, chosen by the user to become an attachment.
final class AttachmentFile {
  const AttachmentFile({
    required this.name,
    required this.size,
    required this.openRead,
  });

  /// The file's own name, with extension and without any directory.
  final String name;

  /// In bytes.
  final int size;

  /// Starts reading the content. Each call reads it from the beginning.
  final Stream<List<int>> Function() openRead;
}
