import unittest

from agents.tally.reasoning import ReasoningFilter, strip_reasoning


def _stream(*pieces):
    """What the user would see of an answer that arrives in these pieces."""
    reasoning_filter = ReasoningFilter()
    shown = [reasoning_filter.feed(piece) for piece in pieces]
    shown.append(reasoning_filter.flush())
    return "".join(shown)


class StripReasoningTests(unittest.TestCase):
    def test_an_answer_without_reasoning_is_untouched(self):
        self.assertEqual(strip_reasoning("Você gastou **R$ 100,00**."), "Você gastou **R$ 100,00**.")

    def test_the_reasoning_before_the_answer_is_removed(self):
        text = "<reasoning>User asks the limit. Use the tool.</reasoning>Limite: R$ 5.398,13"

        self.assertEqual(strip_reasoning(text), "Limite: R$ 5.398,13")

    def test_several_reasoning_blocks_are_all_removed(self):
        text = "<reasoning>a</reasoning><reasoning>b</reasoning>Total: R$ 10,00<reasoning>c</reasoning>."

        self.assertEqual(strip_reasoning(text), "Total: R$ 10,00.")

    def test_the_blank_lines_after_the_reasoning_are_dropped(self):
        self.assertEqual(strip_reasoning("<reasoning>x</reasoning>\n\nOlá"), "Olá")

    def test_the_think_tag_is_removed_too(self):
        self.assertEqual(strip_reasoning("<think>hmm</think>Oi"), "Oi")

    def test_an_unclosed_reasoning_is_dropped_to_the_end(self):
        self.assertEqual(strip_reasoning("Oi<reasoning>never finished"), "Oi")

    def test_a_less_than_sign_that_is_not_a_tag_stays(self):
        self.assertEqual(strip_reasoning("Gastos < 100 e a < b"), "Gastos < 100 e a < b")


class ReasoningFilterStreamingTests(unittest.TestCase):
    def test_tags_cut_in_the_middle_are_still_recognized(self):
        shown = _stream("<reas", "oning>User asks</reas", "oning>Limite: ", "R$ 5")

        self.assertEqual(shown, "Limite: R$ 5")

    def test_one_character_at_a_time_gives_the_same_result(self):
        text = "<reasoning>Use the tool.</reasoning>Total: R$ 10,00 <b>ok</b>"

        self.assertEqual(_stream(*text), "Total: R$ 10,00 <b>ok</b>")

    def test_nothing_of_the_reasoning_is_released_while_it_is_open(self):
        reasoning_filter = ReasoningFilter()

        self.assertEqual(reasoning_filter.feed("<reasoning>secret "), "")
        self.assertEqual(reasoning_filter.feed("still secret"), "")
        self.assertEqual(reasoning_filter.feed("</reasoning>Pronto"), "Pronto")

    def test_text_is_released_as_soon_as_it_cannot_be_a_tag(self):
        reasoning_filter = ReasoningFilter()

        self.assertEqual(reasoning_filter.feed("Olá, tudo bem"), "Olá, tudo bem")

    def test_a_held_back_start_that_was_not_a_tag_comes_out_on_flush(self):
        reasoning_filter = ReasoningFilter()

        self.assertEqual(reasoning_filter.feed("a <rea"), "a ")
        self.assertEqual(reasoning_filter.flush(), "<rea")

    def test_spaces_between_words_are_kept(self):
        self.assertEqual(_stream("Você ", "gastou ", "R$ 10"), "Você gastou R$ 10")
