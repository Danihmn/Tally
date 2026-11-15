"""Takes the model's reasoning out of its answer.

Some models (the OpenAI one on Bedrock) write their reasoning inside the answer text, between
<reasoning>...</reasoning> tags (<think> for others), and a streamed answer can cut a tag in two
pieces. The user must only see the answer."""

OPEN_TAGS = ("<reasoning>", "<think>")
CLOSE_TAGS = ("</reasoning>", "</think>")


def _first_tag(text: str, tags: tuple[str, ...]) -> tuple[int, str] | None:
    """Where the earliest of `tags` starts in `text`, and which one."""
    found = [(text.find(tag), tag) for tag in tags if tag in text]
    return min(found) if found else None


def _partial_tag_length(text: str, tags: tuple[str, ...]) -> int:
    """How many characters at the end of `text` could be the start of a tag still arriving."""
    longest = max(len(tag) for tag in tags) - 1
    for size in range(min(len(text), longest), 0, -1):
        if any(tag.startswith(text[-size:]) for tag in tags):
            return size
    return 0


class ReasoningFilter:
    """Feed it the pieces of one answer, in order: it returns the part that is not reasoning.

    One filter per model call. `flush()` ends the answer and returns what it was holding back."""

    def __init__(self) -> None:
        self._buffer = ""
        self._inside = False
        self._started = False

    def feed(self, text: str) -> str:
        self._buffer += text
        visible: list[str] = []
        while True:
            if self._inside:
                close = _first_tag(self._buffer, CLOSE_TAGS)
                if close is None:
                    # Drop the reasoning, keeping only what could be the start of the closing tag
                    keep = _partial_tag_length(self._buffer, CLOSE_TAGS)
                    self._buffer = self._buffer[len(self._buffer) - keep :]
                    break
                start, tag = close
                self._buffer = self._buffer[start + len(tag) :]
                self._inside = False
            else:
                opening = _first_tag(self._buffer, OPEN_TAGS)
                if opening is None:
                    keep = _partial_tag_length(self._buffer, OPEN_TAGS)
                    cut = len(self._buffer) - keep
                    visible.append(self._buffer[:cut])
                    self._buffer = self._buffer[cut:]
                    break
                start, tag = opening
                visible.append(self._buffer[:start])
                self._buffer = self._buffer[start + len(tag) :]
                self._inside = True
        return self._without_leading_space("".join(visible))

    def flush(self) -> str:
        """The answer is over: text held back as a possible tag was not one. An unclosed reasoning is lost."""
        rest, self._buffer = ("" if self._inside else self._buffer), ""
        self._inside = False
        return self._without_leading_space(rest)

    def _without_leading_space(self, text: str) -> str:
        """The blank lines the model leaves after its reasoning are not part of the answer."""
        if not self._started:
            text = text.lstrip()
            self._started = bool(text)
        return text


def strip_reasoning(text: str) -> str:
    """A whole answer without its reasoning."""
    reasoning_filter = ReasoningFilter()
    return reasoning_filter.feed(text) + reasoning_filter.flush()
