"""Tools for bank accounts (BANK) and credit cards (CREDIT).

Both live in `bank_accounts`, so each kind has its own tools and the model picks by what the
question is about. Data comes from our database (synced from Pluggy), not from Pluggy live.
Field meanings follow the Pluggy docs (guide `products/accounts`):
- BANK `balance` is the available balance (negative means overdraft in use);
  `closing_balance` adds the blocked amount; on some banks (Itaú, BB) the auto-invested amount
  is already inside `balance`.
- CREDIT `balance` is the open invoice not yet paid, not money the person has.
The holder's CPF (`tax_number`) is never sent to the model.
"""

import datetime
import decimal
from collections import defaultdict

from langchain.tools import ToolRuntime, tool

from agents.context import TallyContext
from domain.entities import BankAccount, BankData, CreditData, User
from domain.read_models import BankAccountWithOwner
from infra.database.session import get_session
from services.bank_accounts_service import search_bank_accounts
from services.bank_datas_service import get_bank_data_by_bank_account_id
from services.credit_datas_service import get_credit_data_by_bank_account_id
from services.users_service import list_users_by_household

MAX_ACCOUNTS = 50

_SUBTYPES = {
    "CHECKING_ACCOUNT": "conta corrente",
    "SAVINGS_ACCOUNT": "poupança",
    "CREDIT_CARD": "cartão de crédito",
}


def _money(value: decimal.Decimal | None) -> str:
    return "-" if value is None else f"{value:.2f}"


def _day(value: datetime.datetime | None) -> str:
    return "-" if value is None else value.date().isoformat()


def _text(value: str | None) -> str:
    return value or "-"


def _account_name(account: BankAccount) -> str:
    return account.marketing_name or account.name


def _load(
    user: User, only_mine: bool, account_type: str, load_data
) -> tuple[list[tuple[BankAccountWithOwner, object]], dict]:
    """Accounts of one type (with their bank/credit data) and the owners' first names."""
    household_id = user.household_id
    with get_session() as session:
        items = search_bank_accounts(
            session,
            user_id=user.id if only_mine else None,
            account_type=account_type,
            limit=MAX_ACCOUNTS,
            household_id=household_id,
            only_active=True,
        )
        rows = [
            (item, load_data(session, item.account.id) if item.account.id else None)
            for item in items
        ]
        names = {
            u.id: u.first_name for u in list_users_by_household(session, household_id)
        }
    return rows, names


def _scope_line(only_mine: bool) -> str:
    return (
        "Scope: only the logged user's accounts"
        if only_mine
        else "Scope: the whole household"
    )


def _bank_accounts(user: User, only_mine: bool) -> str:
    rows, names = _load(user, only_mine, "BANK", get_bank_data_by_bank_account_id)
    lines = [_scope_line(only_mine)]
    if not rows:
        lines.append("No bank accounts found.")
        return "\n".join(lines)

    lines.append(
        "owner | holder | account | kind | number | available balance | "
        "accounting balance | auto-invested | overdraft limit | overdraft used | "
        "currency | last update"
    )
    totals: dict[str, decimal.Decimal] = defaultdict(lambda: decimal.Decimal("0.00"))
    for item, data in rows:
        account = item.account
        bank: BankData | None = data  # type: ignore[assignment]
        if account.balance is not None:
            totals[account.currency_code] += account.balance
        lines.append(
            " | ".join([
                names.get(item.user_id, "?"),
                _text(account.owner),
                _account_name(account),
                _SUBTYPES.get(account.subtype, account.subtype),
                account.number,
                _money(account.balance),
                _money(bank.closing_balance if bank else None),
                _money(bank.automatically_invested_balance if bank else None),
                _money(bank.overdraft_contracted_limit if bank else None),
                _money(bank.overdraft_used_limit if bank else None),
                account.currency_code,
                _day(account.updated_at),
            ])
        )
    lines.append(f"{len(rows)} bank accounts.")
    for currency, total in sorted(totals.items()):
        lines.append(f"Total available balance ({currency}): {_money(total)}")
    lines.append(
        "Notes: available balance is what can be spent (negative = overdraft in use). "
        "Accounting balance includes blocked amounts. Auto-invested is already inside the "
        "balance on some banks: never add it to the balance."
    )
    return "\n".join(lines)


def _counts_for_limit(credit: CreditData | None) -> bool:
    """Additional cards share the main card's limit: count the limit only once."""
    return credit is None or credit.holder_type != "ADDITIONAL"


def _credit_cards(user: User, only_mine: bool) -> str:
    rows, names = _load(user, only_mine, "CREDIT", get_credit_data_by_bank_account_id)
    lines = [_scope_line(only_mine)]
    if not rows:
        lines.append("No credit cards found.")
        return "\n".join(lines)

    lines.append(
        "owner | holder | card | brand | level | final digits | holder type | status | "
        "open invoice | credit limit | available limit | minimum payment | close date | "
        "due date | currency | last update"
    )
    zero = decimal.Decimal("0.00")
    invoices: dict[str, decimal.Decimal] = defaultdict(lambda: zero)
    limits: dict[str, decimal.Decimal] = defaultdict(lambda: zero)
    available: dict[str, decimal.Decimal] = defaultdict(lambda: zero)
    for item, data in rows:
        account = item.account
        credit: CreditData | None = data  # type: ignore[assignment]
        currency = account.currency_code
        if account.balance is not None:
            invoices[currency] += account.balance
        if credit is not None and _counts_for_limit(credit):
            if credit.credit_limit is not None:
                limits[currency] += credit.credit_limit
            if credit.available_credit_limit is not None:
                available[currency] += credit.available_credit_limit
        lines.append(
            " | ".join([
                names.get(item.user_id, "?"),
                _text(account.owner),
                _account_name(account),
                _text(credit.brand if credit else None),
                _text(credit.level if credit else None),
                account.number,
                _text(credit.holder_type if credit else None),
                _text(credit.status if credit else None),
                _money(account.balance),
                _money(credit.credit_limit if credit else None),
                _money(credit.available_credit_limit if credit else None),
                _money(credit.minimum_payment if credit else None),
                _day(credit.balance_close_date if credit else None),
                _day(credit.balance_due_date if credit else None),
                currency,
                _day(account.updated_at),
            ])
        )
    lines.append(f"{len(rows)} credit cards.")
    for currency in sorted(invoices):
        lines.append(f"Total open invoice ({currency}): {_money(invoices[currency])}")
    for currency in sorted(limits.keys() | available.keys()):
        lines.append(
            f"Total credit limit ({currency}): {_money(limits[currency])}; "
            f"total available limit ({currency}): {_money(available[currency])}"
        )
    lines.append(
        "Notes: open invoice is the amount owed on the current invoice, not money the person "
        "has. Limit totals leave out ADDITIONAL cards, because they share the main card's limit."
    )
    return "\n".join(lines)


_BANK_HELP = (
    "Checking and savings accounts (conta corrente, poupança): available balance, accounting "
    "balance, overdraft (cheque especial). Not for credit cards. "
    "The result already has the totals: never add amounts yourself."
)
_CREDIT_HELP = (
    "Credit cards (cartão de crédito): open invoice (fatura), credit limit, available limit, "
    "minimum payment, close and due dates. Not for checking or savings accounts. "
    "The result already has the totals: never add amounts yourself."
)


@tool(
    "get_my_bank_accounts",
    description=(
        "ONLY the logged person's own bank accounts. Call it for 'meu saldo', 'minha conta', "
        "'quanto eu tenho'. Never use it for the couple or the house. " + _BANK_HELP
    ),
)
def get_my_bank_accounts(runtime: ToolRuntime[TallyContext]) -> str:
    return _bank_accounts(runtime.context.user, True)


@tool(
    "get_household_bank_accounts",
    description=(
        "Bank accounts of EVERYONE in the household (the couple); each line says whose it is. "
        "Call it for 'nosso saldo', 'nossas contas', 'a gente tem', 'casa', 'por pessoa', "
        "or to compare the people. " + _BANK_HELP
    ),
)
def get_household_bank_accounts(runtime: ToolRuntime[TallyContext]) -> str:
    return _bank_accounts(runtime.context.user, False)


@tool(
    "get_my_credit_cards",
    description=(
        "ONLY the logged person's own credit cards. Call it for 'meu cartão', 'minha fatura', "
        "'meu limite'. Never use it for the couple or the house. " + _CREDIT_HELP
    ),
)
def get_my_credit_cards(runtime: ToolRuntime[TallyContext]) -> str:
    return _credit_cards(runtime.context.user, True)


@tool(
    "get_household_credit_cards",
    description=(
        "Credit cards of EVERYONE in the household (the couple); each line says whose it is. "
        "Call it for 'nossos cartões', 'nossas faturas', 'casa', 'por pessoa', "
        "or to compare the people. " + _CREDIT_HELP
    ),
)
def get_household_credit_cards(runtime: ToolRuntime[TallyContext]) -> str:
    return _credit_cards(runtime.context.user, False)
