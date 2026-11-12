import unittest
import uuid
from dataclasses import dataclass
from types import SimpleNamespace

from services.common.mappers import to_entities, to_entity, to_entity_or_none, to_values


@dataclass
class _Entity:
    name: str
    id: uuid.UUID | None = None
    created_at: str | None = None
    parent_id: uuid.UUID | None = None


def _model(**overrides):
    values = {"id": uuid.uuid4(), "name": "Ana", "created_at": "2026-11-10", "parent_id": None, "extra": 1}
    values.update(overrides)
    return SimpleNamespace(**values)


class TestToEntity(unittest.TestCase):
    def test_copies_only_the_entity_fields(self):
        model = _model()

        entity = to_entity(_Entity, model)

        self.assertEqual(entity, _Entity(name="Ana", id=model.id, created_at="2026-11-10"))


class TestToEntityOrNone(unittest.TestCase):
    def test_none_stays_none(self):
        self.assertIsNone(to_entity_or_none(_Entity, None))

    def test_a_model_becomes_an_entity(self):
        self.assertEqual(to_entity_or_none(_Entity, _model(name="Bia")).name, "Bia")  # type: ignore[union-attr]


class TestToEntities(unittest.TestCase):
    def test_maps_every_model_in_order(self):
        entities = to_entities(_Entity, [_model(name="Ana"), _model(name="Bia")])

        self.assertEqual([e.name for e in entities], ["Ana", "Bia"])

    def test_empty_list(self):
        self.assertEqual(to_entities(_Entity, []), [])


class TestToValues(unittest.TestCase):
    def test_unset_database_generated_columns_are_left_out(self):
        self.assertEqual(to_values(_Entity(name="Ana")), {"name": "Ana", "parent_id": None})

    def test_set_database_generated_columns_are_kept(self):
        id_ = uuid.uuid4()

        values = to_values(_Entity(name="Ana", id=id_, created_at="2026-11-10"))

        self.assertEqual(values["id"], id_)
        self.assertEqual(values["created_at"], "2026-11-10")

    def test_excluded_columns_are_left_out_even_when_set(self):
        entity = _Entity(name="Ana", id=uuid.uuid4(), created_at="x", parent_id=uuid.uuid4())

        values = to_values(entity, exclude=("id", "created_at", "parent_id"))

        self.assertEqual(values, {"name": "Ana"})
