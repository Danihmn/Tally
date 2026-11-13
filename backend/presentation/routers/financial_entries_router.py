import datetime
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.orm import Session

from domain.entities import FinancialEntry, User
from domain.read_models import FinancialEntryFilters
from infra.database.session import get_db
from presentation.dependencies.auth import get_current_user
from presentation.schemas.common_schemas import Page
from presentation.schemas.financial_entry_schemas import (
    EntryPeriodQuery,
    EntryTotalResponse,
    FinancialEntryCreate,
    FinancialEntryQuery,
    FinancialEntryResponse,
    ReconciliationCountsResponse,
    UpcomingEntriesQuery,
    UpcomingEntriesResponse,
    UpcomingEntryItem,
)
from services.common.exceptions import NotFoundError
from services.financial_entries_service import (
    count_not_reconciled_entries,
    count_reconciled_entries,
    create_financial_entry,
    get_active_financial_entry_by_id,
    get_total_planned,
    get_total_reconciled,
    list_upcoming_entries,
    search_financial_entries,
)
from services.users_service import get_user_by_id
from utils.dates import first_day_of_month, today_local

# Both people of the household see every entry (the app is private, for two people).
router = APIRouter(
    prefix="/financial-entries",
    tags=["financial-entries"],
    dependencies=[Depends(get_current_user)],
)


@router.get("", response_model=Page[FinancialEntryResponse])
def list_financial_entries_endpoint(
    query: Annotated[FinancialEntryQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
) -> Page[FinancialEntryResponse]:
    items, total = search_financial_entries(
        session, query.to_filters(), limit=query.limit, offset=query.offset
    )
    return Page[FinancialEntryResponse](
        items=[FinancialEntryResponse.from_entity(e) for e in items],
        total=total,
        limit=query.limit,
        offset=query.offset,
    )


def _period_filters(
    query: EntryPeriodQuery, user: User
) -> tuple[datetime.date, datetime.date, FinancialEntryFilters]:
    """The months used (the current month when the query has no dates) and the filters for them.

    The household always comes from the logged user, never from the request.
    """
    if query.date_from is not None and query.date_to is not None:
        month_from = first_day_of_month(query.date_from)
        month_to = first_day_of_month(query.date_to)
    else:
        month_from = month_to = first_day_of_month(today_local())
    filters = FinancialEntryFilters(
        household_id=user.household_id,
        user_id=query.user_id,
        type=query.type,
        reference_month_from=month_from,
        reference_month_to=month_to,
    )
    return month_from, month_to, filters


# The fixed paths below must stay before "/{entry_id}"
@router.get("/total-planned", response_model=EntryTotalResponse)
def total_planned_endpoint(
    query: Annotated[EntryPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> EntryTotalResponse:
    month_from, month_to, filters = _period_filters(query, current_user)
    return EntryTotalResponse(
        reference_month_from=month_from,
        reference_month_to=month_to,
        type=query.type,
        total=get_total_planned(session, filters),
    )


@router.get("/total-reconciled", response_model=EntryTotalResponse)
def total_reconciled_endpoint(
    query: Annotated[EntryPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> EntryTotalResponse:
    month_from, month_to, filters = _period_filters(query, current_user)
    return EntryTotalResponse(
        reference_month_from=month_from,
        reference_month_to=month_to,
        type=query.type,
        total=get_total_reconciled(session, filters),
    )


@router.get("/reconciliation-counts", response_model=ReconciliationCountsResponse)
def reconciliation_counts_endpoint(
    query: Annotated[EntryPeriodQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ReconciliationCountsResponse:
    month_from, month_to, filters = _period_filters(query, current_user)
    return ReconciliationCountsResponse(
        reference_month_from=month_from,
        reference_month_to=month_to,
        type=query.type,
        reconciled=count_reconciled_entries(session, filters),
        not_reconciled=count_not_reconciled_entries(session, filters),
    )


@router.get("/upcoming", response_model=UpcomingEntriesResponse)
def upcoming_entries_endpoint(
    query: Annotated[UpcomingEntriesQuery, Query()],
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> UpcomingEntriesResponse:
    """Entries not reconciled yet that are due from today until today + `days` (both inclusive)."""
    date_from = today_local()
    date_to = date_from + datetime.timedelta(days=query.days)
    filters = FinancialEntryFilters(
        household_id=current_user.household_id,
        user_id=query.user_id,
        due_date_from=date_from,
        due_date_to=date_to,
    )
    items = []
    for entry in list_upcoming_entries(session, filters):
        assert (
            entry.due_date is not None
        )  # The due date filter leaves out the entries without one
        items.append(
            UpcomingEntryItem(
                description=entry.description,
                amount=entry.amount,
                type=entry.type,
                category=entry.category,
                due_date=entry.due_date,
            )
        )
    return UpcomingEntriesResponse(date_from=date_from, date_to=date_to, items=items)


@router.get("/{entry_id}", response_model=FinancialEntryResponse)
def get_financial_entry_endpoint(
    entry_id: uuid.UUID,
    session: Annotated[Session, Depends(get_db)],
) -> FinancialEntryResponse:
    return FinancialEntryResponse.from_entity(
        get_active_financial_entry_by_id(session, entry_id)
    )


@router.post(
    "", response_model=FinancialEntryResponse, status_code=status.HTTP_201_CREATED
)
def create_financial_entry_endpoint(
    body: FinancialEntryCreate,
    session: Annotated[Session, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> FinancialEntryResponse:
    assert current_user.id is not None
    if body.user_id is not None and body.user_id != current_user.id:  # noqa: SIM102
        # An entry can only be assigned to someone of the same household
        if (
            get_user_by_id(session, body.user_id).household_id
            != current_user.household_id
        ):
            raise NotFoundError("User not found")
    entry = FinancialEntry(
        household_id=current_user.household_id,
        user_id=body.user_id or current_user.id,
        description=body.description,
        type=body.type,
        payment_type=body.payment_type,
        category=body.category,
        amount=body.amount,
        currency_code=body.currency_code.upper(),
        reference_month=first_day_of_month(body.reference_month),
        due_date=body.due_date,
        bank_account_id=body.bank_account_id,
        installment_number=body.installment_number,
        installment_total=body.installment_total,
        notes=body.notes,
    )
    created = create_financial_entry(session, entry)
    session.commit()
    return FinancialEntryResponse.from_entity(created)
