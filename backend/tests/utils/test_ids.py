import unittest
import uuid
from types import SimpleNamespace

from utils.ids import require_id


class TestRequireId(unittest.TestCase):
    def test_returns_the_id(self):
        id_ = uuid.uuid4()

        self.assertEqual(require_id(SimpleNamespace(id=id_), "User"), id_)

    def test_an_entity_without_id_is_a_value_error_with_its_label(self):
        with self.assertRaisesRegex(ValueError, "^Bank account without id$"):
            require_id(SimpleNamespace(id=None), "Bank account")
