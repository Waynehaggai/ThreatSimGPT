import '../error/failures.dart';

/// A functional [Result] type used across every layer of Lumen.
///
/// Instead of throwing exceptions across architectural boundaries, repositories
/// and use cases return a [Result] that is either a [Success] carrying a value
/// or a [ResultFailure] carrying a typed [Failure]. This makes error handling
/// explicit and keeps the presentation layer free of `try/catch` noise.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;

  /// `true` when this result holds a value.
  bool get isSuccess => this is Success<T>;

  /// `true` when this result holds a [Failure].
  bool get isFailure => this is ResultFailure<T>;

  /// The value if [isSuccess], otherwise `null`.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        ResultFailure<T>() => null,
      };

  /// The failure if [isFailure], otherwise `null`.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(:final failure) => failure,
      };

  /// Pattern-matches on the result, requiring both branches to be handled.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        ResultFailure<T>(:final failure) => onFailure(failure),
      };

  /// Transforms the success value, propagating failures untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Result.success(transform(value)),
        ResultFailure<T>(:final failure) => Result.failure(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}
