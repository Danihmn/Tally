import 'package:equatable/equatable.dart';

/// One Tally IA conversation, with how much of its token limit is used.
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.title,
    required this.contextTokens,
    required this.tokenLimit,
    required this.totalInputTokens,
    required this.totalOutputTokens,
    required this.createdAt,
    this.lastMessageAt,
  });

  final String id;
  final String title;

  /// Size of the current context (what the model reads on the next turn).
  final int contextTokens;
  final int tokenLimit;
  final int totalInputTokens;
  final int totalOutputTokens;

  /// `null` until the first answer is saved.
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  /// The last activity, for ordering and for the "when" label.
  DateTime get activityAt => lastMessageAt ?? createdAt;

  TokenUsage get usage =>
      TokenUsage(contextTokens: contextTokens, tokenLimit: tokenLimit);

  @override
  List<Object?> get props => [
    id,
    title,
    contextTokens,
    tokenLimit,
    totalInputTokens,
    totalOutputTokens,
    lastMessageAt,
    createdAt,
  ];
}

/// How full the context of a conversation is.
///
/// Warns from 80% and blocks at 100%: a blocked conversation is read-only and
/// the user starts a new one.
class TokenUsage extends Equatable {
  const TokenUsage({required this.contextTokens, required this.tokenLimit});

  static const empty = TokenUsage(contextTokens: 0, tokenLimit: 0);

  final int contextTokens;
  final int tokenLimit;

  /// 0..1 (above 1 when over the limit). 0 when the limit is unknown.
  double get ratio => tokenLimit > 0 ? contextTokens / tokenLimit : 0;

  /// At least 80% used, but not full yet.
  bool get isWarning =>
      tokenLimit > 0 && contextTokens * 10 >= tokenLimit * 8 && !isFull;

  /// The limit was reached.
  bool get isFull => tokenLimit > 0 && contextTokens >= tokenLimit;

  @override
  List<Object?> get props => [contextTokens, tokenLimit];
}
