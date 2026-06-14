class PersistenceException implements Exception {
  final String message;
  final Object? cause;

  PersistenceException(this.message, {this.cause});

  @override
  String toString() => 'PersistenceException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Thrown when a file-backed request body (multipart file row / binary body)
/// can't be read at send time — e.g. the file was moved or deleted. Pure (no
/// dart:io) so it can cross the data→network boundary; the repository maps it
/// to a NetworkFailure so the user sees a real error response.
class FileBodyException implements Exception {
  final String path;
  final Object? cause;

  FileBodyException(this.path, {this.cause});

  @override
  String toString() => 'Could not read file: $path${cause != null ? ' ($cause)' : ''}';
}
