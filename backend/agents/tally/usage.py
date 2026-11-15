"""Token accounting of one chat turn. The checkpointer does not store counts: each AI message carries
the usage the model reported, and we add it up."""

from dataclasses import dataclass

from langchain_core.messages import AIMessage, BaseMessage
from langchain_core.messages.utils import count_tokens_approximately


@dataclass(frozen=True, slots=True)
class TurnUsage:
    input_tokens: int
    output_tokens: int
    # Tokens the model read in the turn's last call: the size of the conversation that counts for the limit
    context_tokens: int


def turn_usage(
    new_messages: list[BaseMessage], history: list[BaseMessage]
) -> TurnUsage:
    """`new_messages` were added by this turn, `history` is the whole conversation after it.

    A turn can call the model several times (once per tool round), so inputs and outputs are summed.
    When the provider reported nothing, the size is estimated from the text (approximate)."""
    calls = [
        m.usage_metadata
        for m in new_messages
        if isinstance(m, AIMessage) and m.usage_metadata
    ]
    if calls:
        return TurnUsage(
            input_tokens=sum(c["input_tokens"] for c in calls),
            output_tokens=sum(c["output_tokens"] for c in calls),
            context_tokens=calls[-1]["input_tokens"],
        )
    answers = [m for m in new_messages if isinstance(m, AIMessage)]
    context = count_tokens_approximately(history)
    return TurnUsage(
        input_tokens=context,
        output_tokens=count_tokens_approximately(answers),
        context_tokens=context,
    )
