import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from infra.database.models import CreditDatas
from infra.repositories.common.exceptions import translate_db_errors
from infra.repositories.common.upsert import upsert_one


@translate_db_errors("credit_datas")
def get_credit_data_by_bank_account_id(
    session: Session, bank_account_id: uuid.UUID
) -> CreditDatas | None:
    stmt = select(CreditDatas).where(CreditDatas.bank_account_id == bank_account_id)
    return session.scalars(stmt).one_or_none()


@translate_db_errors("credit_datas")
def upsert_credit_data(session: Session, values: dict[str, Any]) -> CreditDatas:
    """Insert or update by bank_account_id (1:1). `values` uses CreditDatas column names."""
    return upsert_one(session, CreditDatas, values, "bank_account_id")
