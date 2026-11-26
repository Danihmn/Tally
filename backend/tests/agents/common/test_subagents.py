import unittest
from unittest.mock import MagicMock

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage

from agents.common.subagents import (
    CONSULTED_RULE,
    EMPTY_ANSWER,
    final_answer,
    invoke_subagent,
    run_subagent,
)


def _agent(*messages):
    agent = MagicMock()
    agent.invoke.return_value = {"messages": list(messages)}
    return agent


class TestRunSubagent(unittest.TestCase):
    def test_the_request_goes_alone_as_the_only_message_with_the_context(self):
        agent = _agent(AIMessage(content="ok"))
        context = object()

        run_subagent(agent, "gastos de novembro", context)

        args, kwargs = agent.invoke.call_args
        messages = args[0]["messages"]
        self.assertEqual(len(messages), 1)
        self.assertIsInstance(messages[0], HumanMessage)
        self.assertEqual(messages[0].content, "gastos de novembro")
        self.assertIs(kwargs["context"], context)

    def test_its_tokens_never_reach_the_caller_stream(self):
        agent = _agent(AIMessage(content="ok"))

        run_subagent(agent, "x", object())

        self.assertEqual(agent.invoke.call_args.kwargs["config"], {"callbacks": []})

    def test_returns_the_last_answer_that_is_not_a_tool_call(self):
        call = AIMessage(content="", tool_calls=[{"name": "t", "args": {}, "id": "1"}])
        agent = _agent(
            HumanMessage(content="x"),
            call,
            ToolMessage(content="data", tool_call_id="1"),
            AIMessage(content="Você gastou R$ 10,00."),
        )

        self.assertEqual(run_subagent(agent, "x", object()), "Você gastou R$ 10,00.")

    def test_reasoning_is_taken_out_of_the_answer(self):
        agent = _agent(AIMessage(content="<reasoning>hmm</reasoning>Total: R$ 5,00"))

        self.assertEqual(run_subagent(agent, "x", object()), "Total: R$ 5,00")

    def test_block_content_is_read_as_text(self):
        agent = _agent(AIMessage(content=[{"type": "text", "text": "Total: R$ 5,00"}]))

        self.assertEqual(run_subagent(agent, "x", object()), "Total: R$ 5,00")

    def test_no_answer_returns_an_error_the_caller_can_read(self):
        self.assertEqual(run_subagent(_agent(), "x", object()), EMPTY_ANSWER)
        self.assertEqual(run_subagent(_agent(AIMessage(content="  ")), "x", object()), EMPTY_ANSWER)


class TestInvokeSubagent(unittest.TestCase):
    def test_returns_every_message_of_the_run_including_the_tool_results(self):
        tool_result = ToolMessage(content="data", tool_call_id="1")
        agent = _agent(HumanMessage(content="x"), tool_result, AIMessage(content="ok"))

        messages = invoke_subagent(agent, "x", object())

        self.assertEqual(len(messages), 3)
        self.assertIs(messages[1], tool_result)
        self.assertEqual(agent.invoke.call_args.kwargs["config"], {"callbacks": []})

    def test_final_answer_reads_the_last_answer_of_those_messages(self):
        call = AIMessage(content="", tool_calls=[{"name": "t", "args": {}, "id": "1"}])

        self.assertEqual(final_answer([call, AIMessage(content="Pronto.")]), "Pronto.")
        self.assertEqual(final_answer([call]), EMPTY_ANSWER)


class TestConsultedRule(unittest.TestCase):
    def test_it_asks_to_say_the_specialist_was_consulted_in_portuguese(self):
        self.assertIn("ALWAYS say", CONSULTED_RULE)
        self.assertIn("Consultei o Hawk", CONSULTED_RULE)
        self.assertIn("never say you consulted one that you did not use", CONSULTED_RULE)
