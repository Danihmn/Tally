"""What the app shows of a conversation: the saved LangGraph messages, without the agent's inner work."""

from typing import Any

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage

from agents.tally.reasoning import strip_reasoning


def message_text(content: str | list) -> str:
    """A message's content is a string, or a list of blocks (strings or {"type": "text", ...})."""
    if isinstance(content, str):
        return content
    parts = [
        block if isinstance(block, str) else block.get("text", "")
        for block in content
        if isinstance(block, str) or block.get("type") == "text"
    ]
    return "".join(parts)


def to_display_messages(messages: list[BaseMessage]) -> list[dict[str, Any]]:
    """The user's questions and the agent's final answers, in order.

    Tool results and the agent steps that only call tools are left out: the user never saw them."""
    shown: list[dict[str, Any]] = []
    for message in messages:
        if isinstance(message, HumanMessage):
            role = "user"
        elif isinstance(message, AIMessage) and not message.tool_calls:
            role = "assistant"
        else:
            continue
        content = message_text(message.content)
        if role == "assistant":
            content = strip_reasoning(content)
        content = content.strip()
        if content:
            shown.append({"id": message.id, "role": role, "content": content})
    return shown
