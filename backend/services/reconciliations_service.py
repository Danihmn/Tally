import uuid

from sqlalchemy.orm import Session

from domain.entities import Reconciliation
from infra.repositories import reconciliations_repository
from services.common.exceptions import (
    InvalidDataError,
    NotFoundError,
    translate_repository_errors,
)
from services.common.mappers import to_entities, to_entity, to_values
from services.financial_entries_service import (
    get_financial_entry,
    mark_financial_entries_status,
)
from services.transactions_service import get_transaction


@translate_repository_errors
def create_reconciliation(
    session: Session, reconciliation: Reconciliation
) -> Reconciliation:
    created = reconciliations_repository.create_reconciliation(
        session, to_values(reconciliation)
    )
    return to_entity(Reconciliation, created)


@translate_repository_errors
def list_reconciliations_by_entries(
    session: Session, entry_ids: list[uuid.UUID]
) -> list[Reconciliation]:
    reconciliations = reconciliations_repository.list_reconciliations_by_entries(
        session, entry_ids
    )
    return to_entities(Reconciliation, reconciliations)


@translate_repository_errors
def list_reconciliations_by_transactions(
    session: Session, transaction_ids: list[uuid.UUID]
) -> list[Reconciliation]:
    reconciliations = reconciliations_repository.list_reconciliations_by_transactions(
        session, transaction_ids
    )
    return to_entities(Reconciliation, reconciliations)


@translate_repository_errors
def mark_reconciliation_deleted(
    session: Session, reconciliation_id: uuid.UUID
) -> Reconciliation:
    reconciliation = reconciliations_repository.soft_delete_reconciliation(
        session, reconciliation_id
    )
    return to_entity(Reconciliation, reconciliation)


def undo_reconciliations_of_transactions(
    session: Session,
    transaction_ids: list[uuid.UUID],
    only_auto: bool = False,
) -> int:
    """
    Undoes the active reconciliations of the given transactions (the transaction is gone or changed
    in a way that breaks the match) and sends their entries back to PLANNED, unless the entry still
    has another active reconciliation. `only_auto` keeps the MANUAL ones: someone chose them.
    Returns how many reconciliations were undone.
    """
    if not transaction_ids:
        return 0

    reconciliations = [
        r
        for r in list_reconciliations_by_transactions(session, transaction_ids)
        if r.id is not None and (not only_auto or r.source == "AUTO")
    ]
    if not reconciliations:
        return 0

    for reconciliation in reconciliations:
        mark_reconciliation_deleted(session, reconciliation.id)  # type: ignore[arg-type]

    _reopen_entries_without_match(
        session, list({r.financial_entry_id for r in reconciliations})
    )
    return len(reconciliations)


def _reopen_entries_without_match(session: Session, entry_ids: list[uuid.UUID]) -> None:
    """Sends back to PLANNED the RECONCILED entries that have no active reconciliation left."""
    still_reconciled = {
        r.financial_entry_id for r in list_reconciliations_by_entries(session, entry_ids)
    }
    mark_financial_entries_status(
        session,
        [e for e in entry_ids if e not in still_reconciled],
        "PLANNED",
        only_from="RECONCILED",
    )


def link_entry(
    session: Session,
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    entry_id: uuid.UUID,
) -> Reconciliation:
    """Links by hand a transaction with an entry of the household: the entry becomes RECONCILED.

    NotFoundError when one of them is not in the household, InvalidDataError for a CANCELLED
    entry and AlreadyExistsError when the pair is already linked."""
    get_transaction(session, household_id, transaction_id)
    entry = get_financial_entry(session, household_id, entry_id)
    if entry.status == "CANCELLED":
        raise InvalidDataError("A cancelled entry cannot be linked")
    created = create_reconciliation(
        session,
        Reconciliation(
            financial_entry_id=entry_id, transaction_id=transaction_id, source="MANUAL"
        ),
    )
    mark_financial_entries_status(session, [entry_id], "RECONCILED")
    return created


def unlink_entry(
    session: Session,
    household_id: uuid.UUID,
    transaction_id: uuid.UUID,
    entry_id: uuid.UUID,
) -> None:
    """Undoes the link of a transaction with an entry. The entry goes back to PLANNED when it
    has no other link. NotFoundError when the pair is not linked."""
    get_transaction(session, household_id, transaction_id)
    linked = [
        r
        for r in list_reconciliations_by_transactions(session, [transaction_id])
        if r.financial_entry_id == entry_id and r.id is not None
    ]
    if not linked:
        raise NotFoundError("The transaction is not linked with this entry")
    for reconciliation in linked:
        mark_reconciliation_deleted(session, reconciliation.id)  # type: ignore[arg-type]
    _reopen_entries_without_match(session, [entry_id])
