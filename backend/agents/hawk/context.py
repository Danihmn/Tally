from dataclasses import dataclass

from agents.common.context import AgentContext


@dataclass(slots=True)
class HawkContext(AgentContext):
    """Hawk's context: the shared `user`, plus what only its prompt needs."""

    # Display names (nickname, else first name) of the other household members, loaded once
    # per request, so the prompt can say who "ele"/"ela" is (the tools name owners the same way)
    partner_names: tuple[str, ...] = ()
