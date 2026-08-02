import '../../core/result/result.dart';

/// Base contract for a use case (interactor) that returns a [Result].
///
/// Use cases encapsulate a single unit of application business logic and are the
/// only thing view models call. They keep view models thin and business rules
/// testable in isolation from Flutter.
abstract interface class UseCase<Output, Input> {
  Future<Result<Output>> call(Input input);
}

/// Marker for use cases that take no parameters.
class NoParams {
  const NoParams();
}
