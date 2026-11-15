import 'package:equatable/equatable.dart';

/// Expected error, already translated from HTTP/Dio details.
///
/// It carries no raw server text: the API sends English `detail` messages, and
/// the UI shows pt-BR text chosen by the failure type.
sealed class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// 401. On login it means wrong credentials, elsewhere an expired session.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure();
}

/// 404.
final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// 409: the record already exists.
final class ConflictFailure extends Failure {
  const ConflictFailure();
}

/// 422. [fields] are the request fields the API rejected (for example `amount`).
final class ValidationFailure extends Failure {
  const ValidationFailure({this.fields = const []});

  final List<String> fields;

  @override
  List<Object?> get props => [fields];
}

/// 409 on a chat message: the conversation reached its token limit and only
/// a new conversation can go on.
final class ConversationFullFailure extends Failure {
  const ConversationFullFailure();
}

/// 5xx, including 503 when the AI or a service is down.
final class ServerUnavailableFailure extends Failure {
  const ServerUnavailableFailure();
}

/// No connection to the server.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The server took too long to answer.
final class TimeoutFailure extends Failure {
  const TimeoutFailure();
}

/// Anything else (unexpected status, bad payload, bug).
final class UnknownFailure extends Failure {
  const UnknownFailure();
}
