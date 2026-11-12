import unittest
from decimal import Decimal

from agents.tools.calculator import calculate, calculate_expression, round_to_cents


class CalculateExpressionTests(unittest.TestCase):
    def test_basic_operations_and_precedence(self):
        cases = {
            "1 + 2 * 3": Decimal("7"),
            "(1 + 2) * 3": Decimal("9"),
            "10 - 4 - 3": Decimal("3"),
            "1500 / 4": Decimal("375"),
            "17 % 5": Decimal("2"),
            "-5 + +2": Decimal("-3"),
            "-(2 - 10)": Decimal("8"),
        }
        for expression, expected in cases.items():
            with self.subTest(expression=expression):
                self.assertEqual(calculate_expression(expression), expected)

    def test_decimals_are_exact(self):
        self.assertEqual(calculate_expression("0.1 + 0.2"), Decimal("0.3"))
        self.assertEqual(calculate_expression("1250.40 - 980.10"), Decimal("270.30"))

    def test_division_by_zero_is_an_error(self):
        for expression in ("1 / 0", "5 % 0", "0 / 0"):
            with self.subTest(expression=expression):
                with self.assertRaises(ValueError):
                    calculate_expression(expression)

    def test_anything_but_numbers_and_arithmetic_is_rejected(self):
        for expression in (
            "2 ** 3",
            "abs(-1)",
            "__import__('os')",
            "x + 1",
            "'1' + '2'",
            "True + 1",
            "[1, 2]",
            "1 if 1 else 2",
            "1 < 2",
            "7 // 2",
        ):
            with self.subTest(expression=expression):
                with self.assertRaises(ValueError):
                    calculate_expression(expression)

    def test_comma_as_decimal_separator_is_rejected_with_a_hint(self):
        with self.assertRaises(ValueError) as error:
            calculate_expression("1.234,56 + 1")

        self.assertIn("'.' as the decimal separator", str(error.exception))

    def test_empty_long_or_invalid_expressions_are_rejected(self):
        for expression in ("", "   ", "1 +" , "1" + "+1" * 150):
            with self.subTest(expression=expression[:10]):
                with self.assertRaises(ValueError):
                    calculate_expression(expression)

    def test_a_number_too_large_for_a_float_is_rejected(self):
        with self.assertRaises(ValueError):
            calculate_expression("1e400")


class RoundToCentsTests(unittest.TestCase):
    def test_rounds_half_up(self):
        self.assertEqual(round_to_cents(Decimal("2.345")), Decimal("2.35"))
        self.assertEqual(round_to_cents(Decimal("-2.345")), Decimal("-2.35"))
        self.assertEqual(round_to_cents(Decimal("2.344")), Decimal("2.34"))

    def test_never_returns_negative_zero(self):
        self.assertEqual(str(round_to_cents(Decimal("-0.001"))), "0.00")


class CalculateToolTests(unittest.TestCase):
    def test_result_is_rounded_to_cents(self):
        self.assertEqual(calculate.func("(1250.40 - 980.10) / 2"), "(1250.40 - 980.10) / 2 = 135.15")

    def test_an_inexact_result_also_shows_the_exact_value(self):
        result = calculate.func("100 / 3")

        self.assertTrue(result.startswith("100 / 3 = 33.33 (rounded"))
        self.assertIn("exact value: 33.333333", result)

    def test_errors_are_returned_as_text_for_the_model_to_retry(self):
        result = calculate.func("abs(-1)")

        self.assertTrue(result.startswith("Error:"))

    def test_the_only_argument_is_the_expression(self):
        self.assertEqual(list(calculate.args), ["expression"])


if __name__ == "__main__":
    unittest.main()
