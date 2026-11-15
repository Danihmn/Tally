import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/sse_parser.dart';

Stream<List<int>> bytes(List<String> chunks) =>
    Stream.fromIterable([for (final c in chunks) utf8.encode(c)]);

void main() {
  group('parseSse', () {
    test('reads_event_and_data_blocks_separated_by_blank_lines', () async {
      final messages = await parseSse(
        bytes([
          'event: meta\ndata: {"a":1}\n\nevent: token\ndata: {"text":"oi"}\n\n',
        ]),
      ).toList();

      expect(messages.map((m) => m.event), ['meta', 'token']);
      expect(messages.map((m) => m.data), ['{"a":1}', '{"text":"oi"}']);
    });

    test('a_block_split_across_chunks_is_joined', () async {
      final messages = await parseSse(
        bytes(['event: tok', 'en\nda', 'ta: {"text":"x"}\n', '\n']),
      ).toList();

      expect(messages.single.event, 'token');
      expect(messages.single.data, '{"text":"x"}');
    });

    test('a_utf8_character_cut_between_chunks_is_decoded', () async {
      final all = utf8.encode('event: token\ndata: ação\n\n');
      final cut = all.indexOf(0xC3) + 1; // between the two bytes of "ç"
      final messages = await parseSse(
        Stream.fromIterable([all.sublist(0, cut), all.sublist(cut)]),
      ).toList();

      expect(messages.single.data, 'ação');
    });

    test('handles_crlf_and_the_optional_space_after_the_colon', () async {
      final messages = await parseSse(
        bytes(['event:done\r\ndata:{"n":1}\r\n\r\n']),
      ).toList();

      expect(messages.single.event, 'done');
      expect(messages.single.data, '{"n":1}');
    });

    test('several_data_lines_are_joined_with_a_newline', () async {
      final messages = await parseSse(
        bytes(['event: token\ndata: a\ndata: b\n\n']),
      ).toList();

      expect(messages.single.data, 'a\nb');
    });

    test('comments_and_blocks_without_data_are_ignored', () async {
      final messages = await parseSse(
        bytes([': ping\n\nevent: x\n\nevent: token\ndata: ok\n\n']),
      ).toList();

      expect(messages.map((m) => m.data), ['ok']);
    });

    test('a_final_block_without_the_closing_blank_line_is_delivered', () async {
      final messages = await parseSse(bytes(['event: done\ndata: {}']))
          .toList();

      expect(messages.single.event, 'done');
    });

    test('a_block_without_event_name_is_a_message', () async {
      final messages = await parseSse(bytes(['data: hi\n\n'])).toList();

      expect(messages.single.event, 'message');
    });
  });
}
