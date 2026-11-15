import 'dart:convert';

/// One Server-Sent Event: the `event:` name and the joined `data:` lines.
class SseMessage {
  const SseMessage({required this.event, required this.data});

  /// `message` when the block had no `event:` line (the SSE default).
  final String event;
  final String data;

  @override
  String toString() => 'SseMessage($event, $data)';
}

/// Parses a `text/event-stream` body into [SseMessage]s.
///
/// Blocks are separated by a blank line. Comment lines (`:`) are ignored and
/// a block with no `data:` line is dropped. A final block without the closing
/// blank line is still delivered. Bytes are decoded as UTF-8 across chunk
/// boundaries.
Stream<SseMessage> parseSse(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = <String>[];
  final lines = const LineSplitter().bind(utf8.decoder.bind(bytes));
  await for (final line in lines) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield SseMessage(event: event, data: data.join('\n'));
      }
      event = 'message';
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else {
      final colon = line.indexOf(':');
      final field = colon == -1 ? line : line.substring(0, colon);
      var value = colon == -1 ? '' : line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') {
        event = value;
      } else if (field == 'data') {
        data.add(value);
      }
    }
  }
  if (data.isNotEmpty) yield SseMessage(event: event, data: data.join('\n'));
}
