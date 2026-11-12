"""A calculator for the math the other tools do not already total (difference, percentage,
split, average), so the model never computes amounts in its head.

The expression is parsed with `ast` and walked by hand: only numbers, + - * / %, unary signs and
parentheses are accepted. Nothing is ever passed to `eval`. Every number is a `Decimal`, so
0.1 + 0.2 is exactly 0.3.
"""

import ast
import decimal

from langchain.tools import tool

from utils.money import round_to_cents

MAX_LENGTH = 200
# 28 significant digits for the math (rounding to cents is done by utils.money)
_CONTEXT = decimal.Context(prec=28, rounding=decimal.ROUND_HALF_EVEN)

_BINARY = {
    ast.Add: lambda a, b: a + b,
    ast.Sub: lambda a, b: a - b,
    ast.Mult: lambda a, b: a * b,
    ast.Div: lambda a, b: a / b,
    ast.Mod: lambda a, b: a % b,
}
_UNARY = {
    ast.UAdd: lambda a: +a,
    ast.USub: lambda a: -a,
}


def _evaluate(node: ast.AST) -> decimal.Decimal:
    if isinstance(node, ast.Expression):
        return _evaluate(node.body)
    if isinstance(node, ast.Constant) and type(node.value) in (int, float):
        # str() keeps what was written (0.1 stays 0.1, not 0.1000000000000000055...)
        value = decimal.Decimal(str(node.value))
        if not value.is_finite():
            raise ValueError("a number in the expression is too large")
        return value
    if isinstance(node, ast.BinOp) and type(node.op) in _BINARY:
        return _BINARY[type(node.op)](_evaluate(node.left), _evaluate(node.right))
    if isinstance(node, ast.UnaryOp) and type(node.op) in _UNARY:
        return _UNARY[type(node.op)](_evaluate(node.operand))
    raise ValueError(
        "only numbers, + - * / %, and parentheses are allowed "
        f"(found '{ast.unparse(node)}')"
    )


def calculate_expression(expression: str) -> decimal.Decimal:
    """The exact value of the expression. Raises ValueError for anything not allowed."""
    expression = expression.strip()
    if not expression:
        raise ValueError("the expression is empty")
    if len(expression) > MAX_LENGTH:
        raise ValueError(f"the expression is longer than {MAX_LENGTH} characters")
    if "," in expression:
        raise ValueError(
            "use '.' as the decimal separator and no thousands separator "
            "(1234.56, not 1.234,56)"
        )
    try:
        tree = ast.parse(expression, mode="eval")
    except SyntaxError:
        raise ValueError(f"'{expression}' is not a valid expression") from None
    with decimal.localcontext(_CONTEXT):
        try:
            return _evaluate(tree)
        except (decimal.DivisionByZero, decimal.InvalidOperation, ZeroDivisionError):
            raise ValueError("division by zero") from None
        except decimal.Overflow:
            raise ValueError("the result is too large") from None


@tool(
    "calculate",
    description=(
        "Exact calculator. Call it for ANY math the other tools did not already return: "
        "difference between two amounts, percentage, splitting a bill, average, sum of a few "
        "amounts. Never do math in your head. "
        "expression uses numbers with '.' as the decimal separator, + - * / % and parentheses, "
        "for example '(1250.40 - 980.10) / 2' or '320 / 1500 * 100'. "
        "The result is rounded to 2 decimal places."
    ),
)
def calculate(expression: str) -> str:
    try:
        value = calculate_expression(expression)
        rounded = round_to_cents(value)
    except ValueError as error:
        return f"Error: {error}"
    text = f"{expression.strip()} = {rounded}"
    if rounded != value:
        text += f" (rounded to 2 decimal places; exact value: {value.normalize()})"
    return text
