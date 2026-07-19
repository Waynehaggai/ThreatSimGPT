/// Typed failures returned through [Result] instead of thrown exceptions.
///
/// Every failure carries a human-readable [message] and an optional [cause]
/// (the originating error/exception) so the UI can show something meaningful
/// while logs retain the technical detail.
sealed class Failure {
  const Failure(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

/// A failure originating from local persistence (Isar/Hive/secure storage).
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause});
}

/// A failure talking to Firebase / any remote backend.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause});
}

/// The device is offline and the requested operation needs connectivity.
final class OfflineFailure extends Failure {
  const OfflineFailure([super.message = 'No internet connection available.']);
}

/// Authentication / authorization failure.
final class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.cause});
}

/// A document could not be imported, parsed, or rendered.
final class DocumentFailure extends Failure {
  const DocumentFailure(super.message, {super.cause});
}

/// OCR failed to extract text from a scanned document.
final class OcrFailure extends Failure {
  const OcrFailure(super.message, {super.cause});
}

/// A synchronization conflict that could not be automatically resolved.
final class SyncConflictFailure extends Failure {
  const SyncConflictFailure(super.message, {super.cause});
}

/// Validation failure for user-supplied input.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Fallback for anything unclassified.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message, {super.cause});
}
