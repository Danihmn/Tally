# Backend gaps

What the design or the app needs and the API does not have yet. Checked against
`backend/presentation/routers` and `schemas`. Each item is a `// TODO(backend)`
in code once its feature is built. Until then, the app uses a fake data source
behind a repository interface.

| # | Gap | Impact in the app | Interim |
|---|---|---|---|
| 1 | No `GET /pluggy-items` | The consent expiry ("Autorização do X expira em N dias") is only known in the `POST` answer | Keep `consent_expires_at` from the POST answer in preferences (not sensitive) |
| 2 | `POST /pluggy-items` takes the owner from the JWT only | "Dono da conexão" for another person cannot be set | Only "Eu" can connect a bank |
| 3 | No endpoint to create a household; `POST /users` needs `household_id` | "Nova casa" in "Adicionar pessoa" | Hidden. New people join the current household |
| 4 | No reconciliation endpoints (table `007_reconciliations_table.sql` and matching logic exist) | Conciliação: list pairs, confirm, undo, manual link | Fake data source |
| 5 | Partial analysis. Done: `GET /transactions/total-expenses`, `/total-revenues`, `/balance` (filters `date_from`+`date_to` together or none, optional `user_id`; default period is day 1 until yesterday, or the whole previous month on day 1). Planning (entries) also done: `GET /financial-entries/total-planned`, `/total-reconciled`, `/reconciliation-counts` (`type` REVENUES or EXPENSES is required; the period is by month, any day picks the month, default is the current month; reconciled is the entry status, CANCELLED is left out). Also done: `GET /transactions/top-expenses` (`limit`, default 5), `/transactions/daily-expenses` (every day of the period, 0 when nothing was spent), `/transactions/average-daily-expenses` and `GET /financial-entries/upcoming` (`days`, default 7; PLANNED entries due from today until today + days; each item has `description`, `amount`, `type`, `category` (may be null) and `due_date`). Missing: by month, by category, by member | Home dashboard, charts | Totals from the API; the rest from a fake data source |
| 6 | No update/delete for entries and recurrences | Edit/cancel actions | Not built |
| 7 | No credit limit or due date in `BankAccountResponse` | Card details | Not shown |
| 8 | `GET /bank-accounts` and `GET /users` return plain lists (no `total`) | "Has more" is guessed from a full page | `PaginatedViewModel` handles it |
| 9 | Chat is stateless (`POST /tally/chat {message}`); no conversation id or history | "Nova conversa", history list | The thread lives in memory. History will be owned by the API |
| 10 | Validation 422 returns `detail` as a list, other errors as a string | Client must accept both | Done in `ErrorInterceptor` |

Not in the original app brief but present in the API: `POST /recurrences/provision`
(creates the month's PLANNED entries from recurrences) and `GET /users/{id}`.

**Known limit of the totals (gap 5):** they sum every DEBIT / CREDIT. A credit card bill payment is a DEBIT in the bank account and a CREDIT in the card, and transfers between own accounts are both, so expenses can be counted twice and revenues inflated. A filter will come later.
