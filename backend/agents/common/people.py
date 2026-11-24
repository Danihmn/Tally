"""The prompt text that says who is talking: shared by every agent."""

from typing import Protocol

from domain.entities import User


class _HasPeople(Protocol):
    user: User
    partner_names: tuple[str, ...]


def people_prompt(context: _HasPeople) -> str:
    """Who is talking and who the partner is: the tools name each owner by nickname (first name if none)."""
    me = context.user.display_name
    text = (
        f"You are talking to {me}. In the tool results, the owner column uses these names: "
        f'"eu", "meu", "minha", "gastei" mean {me}.'
    )
    if not context.partner_names:
        return text + " No other person is in the household yet."
    partners = " and ".join(context.partner_names)
    return (
        f"{text} The other person in the household is {partners}: "
        '"ele", "ela", "meu marido", "minha esposa", "meu parceiro", "minha parceira" '
        f"mean {partners}."
    )
