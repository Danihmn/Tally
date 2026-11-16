import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from domain.entities import User
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from services.reconciliations_service import link_entry, unlink_entry

# Manual link between a bank transaction and an entry. Both must be in the household
# of the logged user.
router = APIRouter(
    prefix="/transactions/{transaction_id}/financial-entries",
    tags=["reconciliations"],
    dependencies=[Depends(get_current_user)],
)


@router.post("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def link_entry_endpoint(
    transaction_id: uuid.UUID,
    entry_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    """The entry becomes RECONCILED. 404 when one is not found, 409 when already linked,
    422 for a cancelled entry."""
    link_entry(session, current_user.household_id, transaction_id, entry_id)
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def unlink_entry_endpoint(
    transaction_id: uuid.UUID,
    entry_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    """The entry goes back to PLANNED when it has no other link. 404 when not linked."""
    unlink_entry(session, current_user.household_id, transaction_id, entry_id)
    session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
