import uuid

from sqlalchemy.orm import Session

from infra.database.models import Households
from infra.repositories.common.exceptions import (
    RecordNotFoundError,
    translate_db_errors,
)


@translate_db_errors("households")
def get_household_by_id(session: Session, household_id: uuid.UUID) -> Households:
    household = session.get(Households, household_id)
    if household is None:
        raise RecordNotFoundError("households", "get_household_by_id")
    return household
