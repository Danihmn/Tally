import unittest

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.tally.usage import turn_usage


def _ai(input_tokens, output_tokens, **kwargs):
    usage = {"input_tokens": input_tokens, "output_tokens": output_tokens, "total_tokens": input_tokens + output_tokens}
    return AIMessage(content="x", usage_metadata=usage, **kwargs)


class TurnUsageWithReportedTokensTests(unittest.TestCase):
    def test_one_model_call_is_its_own_usage(self):
        usage = turn_usage([_ai(1200, 80)], [])

        self.assertEqual((usage.input_tokens, usage.output_tokens, usage.context_tokens), (1200, 80, 1200))

    def test_each_tool_round_is_a_model_call_and_they_are_summed(self):
        call = {"name": "t", "args": {}, "id": "c1"}
        new = [
            _ai(1000, 20, tool_calls=[call]),
            ToolMessage(content="rows", tool_call_id="c1"),
            _ai(1500, 60),
        ]

        usage = turn_usage(new, [])

        self.assertEqual(usage.input_tokens, 2500)
        self.assertEqual(usage.output_tokens, 80)

    def test_the_context_is_what_the_last_call_read(self):
        call = {"name": "t", "args": {}, "id": "c1"}
        new = [_ai(1000, 20, tool_calls=[call]), _ai(1500, 60)]

        self.assertEqual(turn_usage(new, []).context_tokens, 1500)

    def test_messages_that_are_not_ai_answers_do_not_count(self):
        new = [HumanMessage(content="oi"), _ai(300, 10)]

        self.assertEqual(turn_usage(new, []).input_tokens, 300)


class TurnUsageWithoutReportedTokensTests(unittest.TestCase):
    def test_the_size_is_estimated_from_the_text(self):
        history = [HumanMessage(content="a" * 400), AIMessage(content="b" * 400)]

        usage = turn_usage([history[1]], history)

        self.assertGreater(usage.context_tokens, 0)
        self.assertEqual(usage.input_tokens, usage.context_tokens)
        self.assertGreater(usage.output_tokens, 0)
        self.assertLess(usage.output_tokens, usage.context_tokens)

    def test_a_longer_conversation_is_estimated_bigger(self):
        short = [HumanMessage(content="oi"), AIMessage(content="olá")]
        long = short + [HumanMessage(content="c" * 4000), AIMessage(content="d" * 4000)]

        self.assertGreater(
            turn_usage(long[-1:], long).context_tokens, turn_usage(short[-1:], short).context_tokens
        )
