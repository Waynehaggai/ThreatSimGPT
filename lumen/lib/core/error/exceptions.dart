/// Low-level exceptions thrown *within* the data layer only.
///
/// These never cross an architectural boundary — data sources throw them and
/// repository implementations catch them, mapping each to a typed `Failure`
/// (see `core/error/failures.dart`) before returning a `Result`.
class CacheException implements Exception {
  const CacheException(this.message, {this.cause});
  final String message;
  final Object? cause;
}

class ServerException implements Exception {
  const ServerException(this.message, {this.cause});
  final String message;
  final Object? cause;
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code, this.cause});
  final String message;
  final String? code;
  final Object? cause;
}

class DocumentParseException implements Exception {
  const DocumentParseException(this.message, {this.cause});
  final String message;
  final Object? cause;
}
