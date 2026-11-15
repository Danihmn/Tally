import 'package:equatable/equatable.dart';

/// The credentials of a person's Pluggy application. Sent to the API and never
/// kept: the app does not store or show the secret.
class PluggyCredentials extends Equatable {
  const PluggyCredentials({required this.clientId, required this.clientSecret});

  final String clientId;
  final String clientSecret;

  @override
  List<Object?> get props => [clientId, clientSecret];
}
