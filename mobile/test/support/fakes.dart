import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:mobile/core/storage/preferences_storage.dart';
import 'package:mobile/core/storage/secure_storage.dart';

/// In-memory [SecureStorage] for tests.
class FakeSecureStorage implements SecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// In-memory [PreferencesStorage] for tests.
class FakePreferencesStorage implements PreferencesStorage {
  final Map<String, Object> values = {};

  @override
  String? getString(String key) => values[key] as String?;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// What a [FakeHttpAdapter] answers for one request.
class FakeReply {
  const FakeReply(this.status, [this.body]);

  final int status;
  final Object? body;
}

/// Dio adapter that never touches the network. Records every request.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.reply);

  final FakeReply Function(RequestOptions options) reply;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final result = reply(options);
    return ResponseBody.fromString(
      jsonEncode(result.body ?? <String, Object?>{}),
      result.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
