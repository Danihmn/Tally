import uuid

from sqlalchemy.orm import Session

from domain.entities import Address
from infra.repositories import addresses_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entities, to_values


@translate_repository_errors
def list_addresses_by_identity_data(
    session: Session, identity_data_id: uuid.UUID
) -> list[Address]:
    addresses = addresses_repository.list_addresses_by_identity_data(
        session, identity_data_id
    )
    return to_entities(Address, addresses)


@translate_repository_errors
def replace_addresses_for_identity_data(
    session: Session, identity_data_id: uuid.UUID, addresses: list[Address]
) -> list[Address]:
    values = [to_values(a, exclude=("identity_data_id",)) for a in addresses]
    saved = addresses_repository.replace_addresses_for_identity_data(
        session, identity_data_id, values
    )
    return to_entities(Address, saved)
