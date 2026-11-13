import 'dart:typed_data';

/// Saves a downloaded attachment where the user chooses. Throws only
/// `AttachmentFailure`.
abstract interface class AttachmentFileSaver {
  /// Suggests [name] for the file. Completes with `false` when the user
  /// gives up saving.
  Future<bool> save({
    required String name,
    required String contentType,
    required Uint8List bytes,
  });
}
