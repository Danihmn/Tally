from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class PluggyModel(BaseModel):
    """Base of the Pluggy response schemas: Pluggy sends camelCase, our fields are snake_case."""

    model_config = ConfigDict(
        alias_generator=to_camel,  # created_at -> createdAt
        validate_by_name=True,  # accepts created_at and createdAt
        validate_by_alias=True,
    )
