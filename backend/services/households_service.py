import uuid

from sqlalchemy.orm import Session

from domain.entities import Household
from infra.repositories import households_repository
from services.common.exceptions import translate_repository_errors
from services.common.mappers import to_entity


@translate_repository_errors
def get_household_by_id(session: Session, household_id: uuid.UUID) -> Household:
    return to_entity(
        Household, households_repository.get_household_by_id(session, household_id)
    )
