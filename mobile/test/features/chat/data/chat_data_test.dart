import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/network/api_endpoints.dart';
import 'package:mobile/core/network/sse_parser.dart';
import 'package:mobile/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:mobile/features/chat/data/mappers/chat_mappers.dart';
import 'package:mobile/features/chat/data/models/chat_event_dto.dart';
import 'package:mobile/features/chat/data/models/conversation_dto.dart';
import 'package:mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/chat_stream_event.dart';

import '../../../support/fake_dio.dart';
import '../../../support/fakes.dart';

/// Answers every request with [sse] as a `text/event-stream` (or [status]).
class SseAdapter implements HttpClientAdapter {
  SseAdapter(this.sse, {this.status = 200});

  final String sse;
  final int status;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = status == 200 ? sse : '';
    return ResponseBody(
      Stream.fromIterable([Uint8List.fromList(utf8.encode(body))]),
      status,
      headers: {
        Headers.contentTypeHeader: [
          status == 200 ? 'text/event-stream' : Headers.jsonContentType,
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const conversationJson = {
  'id': 'c1',
  'title': 'Gastos',
  'context_tokens': 1200,
  'token_limit': 50000,
  'total_input_tokens': 3000,
  'total_output_tokens': 400,
  'last_message_at': null,
  'created_at': '2026-11-10T12:00:00Z',
};

void main() {
  group('chat DTOs and mappers', () {
    test('a_conversation_maps_with_a_null_last_message_date', () {
      final entity = ConversationDto.fromJson(conversationJson).toEntity();

      expect(entity.id, 'c1');
      expect(entity.title, 'Gastos');
      expect(entity.contextTokens, 1200);
      expect(entity.tokenLimit, 50000);
      expect(entity.lastMessageAt, isNull);
      expect(entity.createdAt, DateTime.utc(2026, 11, 10, 12));
      expect(entity.activityAt, entity.createdAt);
    });

    test('a_page_keeps_total_limit_and_offset', () {
      final page = ConversationPageDto.fromJson({
        'items': [conversationJson],
        'total': 7,
        'limit': 30,
        'offset': 0,
      }).toEntity();

      expect(page.items, hasLength(1));
      expect(page.total, 7);
      expect(page.limit, 30);
    });

    test('a_detail_maps_roles_and_content', () {
      final detail = ConversationDetailDto.fromJson({
        'conversation': conversationJson,
        'messages': [
          {'id': 'm1', 'role': 'user', 'content': 'Oi'},
          {'id': 'm2', 'role': 'assistant', 'content': '**Olá**'},
        ],
      }).toEntity();

      expect(detail.messages.map((m) => m.role), [
        ChatRole.user,
        ChatRole.assistant,
      ]);
      expect(detail.messages.last.content, '**Olá**');
    });

    test('a_bad_conversation_payload_throws_a_format_exception', () {
      expect(
        () => ConversationDto.fromJson({...conversationJson, 'id': null}),
        throwsFormatException,
      );
    });

    test('the_four_event_names_map_to_events', () {
      ChatStreamEvent? map(String name, Map<String, dynamic> data) =>
          ChatEventDto(name: name, data: data).toEntity();

      expect(
        map('meta', {'conversation_id': 'c9', 'title': 'T', 'is_new': true}),
        const ChatMeta(conversationId: 'c9', title: 'T', isNew: true),
      );
      expect(map('token', {'text': 'oi'}), const ChatToken('oi'));
      expect(
        map('done', {
          'context_tokens': 10,
          'token_limit': 100,
          'total_input_tokens': 1,
          'total_output_tokens': 2,
        }),
        const ChatDone(contextTokens: 10, tokenLimit: 100),
      );
      expect(map('error', {'code': 'boom'}), const ChatStreamError('boom'));
    });

    test('an_unknown_event_name_is_ignored', () {
      expect(const ChatEventDto(name: 'ping', data: {}).toEntity(), isNull);
    });

    test('event_data_that_is_not_an_object_is_a_format_error', () {
      expect(
        () =>
            ChatEventDto.fromSse(const SseMessage(event: 'token', data: '[1]')),
        throwsFormatException,
      );
    });
  });

  group('ChatRemoteDataSource.send', () {
    const sse =
        'event: meta\ndata: {"conversation_id":"c1","title":"Gastos","is_new":true}\n\n'
        'event: token\ndata: {"text":"Olá "}\n\n'
        'event: token\ndata: {"text":"mundo"}\n\n'
        'event: done\ndata: {"context_tokens":10,"token_limit":100,'
        '"total_input_tokens":10,"total_output_tokens":5}\n\n';

    ChatRemoteDataSource build(HttpClientAdapter adapter) =>
        ChatRemoteDataSource(
          buildFakeDio(FakeHttpAdapter((_) => const FakeReply(200)))
            ..httpClientAdapter = adapter,
        );

    test('streams_the_events_in_order_and_posts_the_body', () async {
      final adapter = SseAdapter(sse);
      final results = await build(adapter)
          .send(message: 'Oi', conversationId: 'c1')
          .toList();

      expect(results.every((r) => r.isSuccess), isTrue);
      expect(results.map((r) => r.valueOrNull!.name), [
        'meta',
        'token',
        'token',
        'done',
      ]);
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, ApiEndpoints.chat.path);
      expect(request.data, {'message': 'Oi', 'conversation_id': 'c1'});
      expect(request.responseType, ResponseType.stream);
      expect(request.receiveTimeout, ChatRemoteDataSource.streamReceiveTimeout);
    });

    test('a_new_conversation_sends_a_null_conversation_id', () async {
      final adapter = SseAdapter(sse);
      await build(adapter).send(message: 'Oi').toList();

      expect(
        (adapter.requests.single.data
            as Map<String, dynamic>)['conversation_id'],
        isNull,
      );
    });

    test('409_becomes_conversation_full', () async {
      final results = await build(SseAdapter('', status: 409))
          .send(message: 'Oi', conversationId: 'c1')
          .toList();

      expect(results.single.failureOrNull, const ConversationFullFailure());
    });

    test('404_and_401_keep_their_failures', () async {
      final notFound = await build(SseAdapter('', status: 404))
          .send(message: 'Oi', conversationId: 'x')
          .toList();
      final unauthorized = await build(SseAdapter('', status: 401))
          .send(message: 'Oi')
          .toList();

      expect(notFound.single.failureOrNull, const NotFoundFailure());
      expect(unauthorized.single.failureOrNull, const UnauthorizedFailure());
    });

    test('event_data_that_is_not_json_ends_with_a_failure', () async {
      final results = await build(
        SseAdapter('event: token\ndata: not json\n\n'),
      ).send(message: 'Oi').toList();

      expect(results.single.failureOrNull, const UnknownFailure());
    });

    test('the_repository_maps_events_and_drops_unknown_ones', () async {
      final repository = ChatRepositoryImpl(
        build(SseAdapter('event: ping\ndata: {}\n\n$sse')),
      );
      final results = await repository.send(message: 'Oi').toList();

      expect(results.map((r) => r.valueOrNull), [
        const ChatMeta(conversationId: 'c1', title: 'Gastos', isNew: true),
        const ChatToken('Olá '),
        const ChatToken('mundo'),
        const ChatDone(contextTokens: 10, tokenLimit: 100),
      ]);
    });
  });

  group('ChatRemoteDataSource lists', () {
    test('list_sends_limit_and_offset', () async {
      final adapter = FakeHttpAdapter(
        (_) => const FakeReply(200, {
          'items': [conversationJson],
          'total': 1,
          'limit': 30,
          'offset': 0,
        }),
      );
      final result = await ChatRemoteDataSource(buildFakeDio(adapter))
          .list(offset: 0, limit: 30);

      expect(result.valueOrNull!.items, hasLength(1));
      expect(adapter.requests.single.path, '/tally/conversations');
      expect(adapter.requests.single.queryParameters, {
        'limit': 30,
        'offset': 0,
      });
    });

    test('get_puts_the_id_in_the_path_and_404_is_not_found', () async {
      final adapter = FakeHttpAdapter(
        (o) => o.path.endsWith('/c1')
            ? const FakeReply(200, {
                'conversation': conversationJson,
                'messages': [
                  {'id': 'm1', 'role': 'user', 'content': 'Oi'},
                ],
              })
            : const FakeReply(404, {'detail': 'Not found'}),
      );
      final remote = ChatRemoteDataSource(buildFakeDio(adapter));

      final ok = await remote.get('c1');
      final missing = await remote.get('zzz');

      expect(ok.valueOrNull!.messages.single.content, 'Oi');
      expect(adapter.requests.first.path, '/tally/conversations/c1');
      expect(missing.failureOrNull, const NotFoundFailure());
    });
  });
}
