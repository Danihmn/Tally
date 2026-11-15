import unittest

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.tally.history import message_text, to_display_messages


class MessageTextTests(unittest.TestCase):
    def test_a_string_is_returned_as_it_is(self):
        self.assertEqual(message_text("Olá"), "Olá")

    def test_blocks_keep_only_the_text_ones_joined(self):
        content = [{"type": "text", "text": "Olá, "}, {"type": "tool_use", "id": "x"}, "mundo"]

        self.assertEqual(message_text(content), "Olá, mundo")


class ToDisplayMessagesTests(unittest.TestCase):
    def test_keeps_the_questions_and_the_final_answers_in_order(self):
        messages = [
            HumanMessage(content="Quanto gastei?", id="1"),
            AIMessage(content="Você gastou R$ 100,00.", id="2"),
        ]

        self.assertEqual(
            to_display_messages(messages),
            [
                {"id": "1", "role": "user", "content": "Quanto gastei?"},
                {"id": "2", "role": "assistant", "content": "Você gastou R$ 100,00."},
            ],
        )

    def test_the_agent_inner_steps_are_left_out(self):
        call = {"name": "get_my_transactions", "args": {}, "id": "c1"}
        messages = [
            HumanMessage(content="Quanto gastei?", id="1"),
            AIMessage(content="", tool_calls=[call], id="2"),
            ToolMessage(content="a | b", tool_call_id="c1", id="3"),
            AIMessage(content="Vou somar.", tool_calls=[call], id="4"),
            AIMessage(content="R$ 100,00", id="5"),
        ]

        shown = to_display_messages(messages)

        self.assertEqual([m["id"] for m in shown], ["1", "5"])

    def test_a_message_without_text_is_not_shown(self):
        messages = [AIMessage(content="   ", id="1"), HumanMessage(content=[{"type": "image"}], id="2")]

        self.assertEqual(to_display_messages(messages), [])

    def test_text_is_trimmed(self):
        self.assertEqual(to_display_messages([AIMessage(content="  oi \n", id="1")])[0]["content"], "oi")

    def test_the_reasoning_of_an_answer_is_not_shown(self):
        messages = [AIMessage(content="<reasoning>Use the tool.</reasoning>**R$ 100,00**", id="1")]

        self.assertEqual(to_display_messages(messages)[0]["content"], "**R$ 100,00**")

    def test_an_answer_that_was_only_reasoning_is_not_shown(self):
        self.assertEqual(to_display_messages([AIMessage(content="<reasoning>x</reasoning>", id="1")]), [])

    def test_a_question_is_never_filtered(self):
        shown = to_display_messages([HumanMessage(content="O que é <reasoning>?", id="1")])

        self.assertEqual(shown[0]["content"], "O que é <reasoning>?")

    def test_no_messages_is_an_empty_list(self):
        self.assertEqual(to_display_messages([]), [])
