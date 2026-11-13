import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('runs_only_the_last_action_after_the_delay', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        final calls = <String>[];
        debouncer.run(() => calls.add('a'));
        async.elapse(const Duration(milliseconds: 200));
        debouncer.run(() => calls.add('b'));
        async.elapse(const Duration(milliseconds: 299));
        expect(calls, isEmpty);
        async.elapse(const Duration(milliseconds: 2));
        expect(calls, ['b']);
      });
    });

    test('cancel_prevents_the_pending_action', () {
      fakeAsync((async) {
        final debouncer = Debouncer();
        var ran = false;
        debouncer.run(() => ran = true);
        debouncer.cancel();
        async.elapse(const Duration(seconds: 1));
        expect(ran, isFalse);
      });
    });
  });
}
