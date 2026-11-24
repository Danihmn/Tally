"""How an agent asks a sub-agent (a specialist) for an analysis. Every sub-agent works the same way:
the orchestrator calls a tool, the tool runs the specialist and returns its answer as text."""

from typing import Any

from langchain_core.messages import AIMessage, HumanMessage

from agents.tally.history import message_text
from agents.tally.reasoning import strip_reasoning

# Goes in the orchestrator's prompt: the user must know which specialist helped
CONSULTED_RULE = (
    "Specialists: some tools ask a specialist agent (for example Hawk, the spending "
    "specialist). When you used one, ALWAYS say in your final answer, in Brazilian Portuguese, "
    "that you consulted it (for example: \"Consultei o Hawk, nosso especialista em gastos.\"). "
    "Say it once, naturally, near the start or the end. Do this for every specialist you used, "
    "and never say you consulted one that you did not use. "
    "Use the specialist's analysis as it is: do not recalculate its numbers or change its facts."
)

EMPTY_ANSWER = "Error: the specialist returned no answer. Try again with a clearer request."


def run_subagent(agent: Any, request: str, context: Any) -> str:
    """Runs `agent` on one self-contained request and returns the text of its final answer.

    The specialist keeps no history, so the request must say everything it needs. Callbacks are
    turned off so its tokens never reach the orchestrator's stream: the user sees only the
    orchestrator's answer."""
    result = agent.invoke(
        {"messages": [HumanMessage(content=request)]},
        context=context,
        config={"callbacks": []},
    )
    for message in reversed(result.get("messages", [])):
        if isinstance(message, AIMessage) and not message.tool_calls:
            answer = strip_reasoning(message_text(message.content)).strip()
            return answer or EMPTY_ANSWER
    return EMPTY_ANSWER
