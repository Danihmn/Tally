import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_mask_formatter.dart';

void main() {
  const formatter = DateMaskFormatter();

  String type(String text) => formatter
      .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text))
      .text;

  group('DateMaskFormatter', () {
    test('puts_the_slashes_while_the_digits_are_typed', () {
      expect(type('1'), '1');
      expect(type('12'), '12');
      expect(type('121'), '12/1');
      expect(type('1211'), '12/11');
      expect(type('12112'), '12/11/2');
      expect(type('12112026'), '12/11/2026');
    });

    test('never_allows_more_than_eight_digits', () {
      expect(type('121120261234'), '12/11/2026');
    });

    test('anything_that_is_not_a_digit_is_dropped', () {
      expect(type('12a/b11-2026'), '12/11/2026');
      expect(type('abc'), '');
    });

    test('a_pasted_date_with_slashes_keeps_its_shape', () {
      expect(type('12/11/2026'), '12/11/2026');
    });

    test('the_cursor_goes_to_the_end', () {
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '1211'),
      );

      expect(value.selection.baseOffset, 5);
    });

    test('an_empty_text_stays_empty', () {
      expect(type(''), '');
    });
  });
}
