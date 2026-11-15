import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_endpoints.dart';

void main() {
  const httpMethods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};

  group('ApiEndpoints', () {
    test('lists_at_least_one_endpoint', () {
      expect(ApiEndpoints.all, isNotEmpty);
    });

    test('has_no_endpoint_with_the_same_method_and_path', () {
      final keys = ApiEndpoints.all.map((e) => e.toString()).toList();
      expect(keys.toSet().length, keys.length);
    });

    test('every_path_starts_with_a_slash', () {
      for (final endpoint in ApiEndpoints.all) {
        expect(endpoint.path, startsWith('/'), reason: '$endpoint');
      }
    });

    test('no_path_ends_with_a_slash_or_has_a_query_string', () {
      for (final endpoint in ApiEndpoints.all) {
        expect(endpoint.path, isNot(endsWith('/')), reason: '$endpoint');
        expect(endpoint.path, isNot(contains('?')), reason: '$endpoint');
      }
    });

    test('every_method_is_a_known_http_method', () {
      for (final endpoint in ApiEndpoints.all) {
        expect(httpMethods, contains(endpoint.method), reason: '$endpoint');
      }
    });

    test('every_endpoint_says_which_feature_uses_it', () {
      for (final endpoint in ApiEndpoints.all) {
        expect(endpoint.usedBy.trim(), isNotEmpty, reason: '$endpoint');
      }
    });

    test('lists_the_three_tally_chat_endpoints', () {
      expect(ApiEndpoints.all, contains(ApiEndpoints.chat));
      expect(ApiEndpoints.all, contains(ApiEndpoints.conversations));
      expect(ApiEndpoints.all, contains(ApiEndpoints.conversation));
      expect(ApiEndpoints.chat.toString(), 'POST /tally/chat');
      expect(ApiEndpoints.conversations.toString(), 'GET /tally/conversations');
      expect(
        ApiEndpoints.conversation.toString(),
        'GET /tally/conversations/{id}',
      );
    });

    test('prints_as_method_and_path', () {
      expect(
        ApiEndpoints.totalExpenses.toString(),
        'GET /transactions/total-expenses',
      );
    });
  });
}
