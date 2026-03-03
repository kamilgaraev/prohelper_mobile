sealed class Result<T, E extends Exception> {
  const Result();

  factory Result.success(T data) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T? get dataOrNull => isSuccess ? (this as Success<T, E>).data : null;
  E? get errorOrNull => isFailure ? (this as Failure<T, E>).error : null;
}

class Success<T, E extends Exception> extends Result<T, E> {
  final T data;
  const Success(this.data);
}

class Failure<T, E extends Exception> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}
