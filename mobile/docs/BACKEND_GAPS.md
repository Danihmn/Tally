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
| 6 | No update/delete for entries | Edit/cancel actions | Not built |
| 7 | No credit limit or due date in `BankAccountResponse` | Card details | Not shown |
| 8 | `GET /bank-accounts` and `GET /users` return plain lists (no `total`) | "Has more" is guessed from a full page | `PaginatedViewModel` handles it |
| 9 | **Resolved.** Chat now has many conversations per user: `POST /tally/chat` (`message`, `conversation_id`, answer as SSE `meta`/`token`/`done`/`error`; 404, 409 `conversation_limit_reached`), `GET /tally/conversations` and `GET /tally/conversations/{id}`. Still missing: rename and delete a conversation, a time per message | "Nova conversa", history list, token limit banner | Built in `features/chat`. The history list has no rename or delete. Messages show no time |
| 10 | Validation 422 returns `detail` as a list, other errors as a string | Client must accept both | Done in `ErrorInterceptor` |
| 11 | `GET /users` lists the users of every household (no filter) | The Home needs only the people of its house | The app filters by `household_id` |
| 12 | Home "Precisa de atenção": no endpoint for a bank authorization about to expire (gap 1) or for overdue entries | Only "N lançamentos sem conciliar" is shown (from `reconciliation-counts`) | The other two items are left out |
| 13 | No household name | The Home caption cannot show it | It shows "Tally" |
| 14 | "Onde mais gastamos" in the prototype groups by merchant ("N compras") | `top-expenses` lists single transactions | The card lists the biggest transactions |
| 15 | No spending by category | The "Gastos por categoria" chart | Left out of the Home for now |
| 16 | No last-sync date | "Atualizado há 2 min" of the Transações prototype | The screen has only "Atualizar" and pull to refresh |
| 17 | Transaction category: `category` is English text and may be null; `category_id` is hierarchical (only groups 01, 05 and 19 are known) | Category badge and icon in the list and the detail | Text shown as it comes; the icon follows the known groups, else the direction. No category filter |
| 18 | No reconciliation endpoints for a transaction (see gap 4) | The "Lançamento vinculado" block of the transaction detail | Left out of the detail screen |
| 19 | `GET /transactions` and `GET /bank-accounts` did not filter by household | Anyone logged in could list other houses | Fixed in the backend: the household comes from the JWT |
| 20 | `GET /financial-entries` did not filter by household | Anyone logged in could list the entries of other houses | Fixed in the backend: the household comes from the JWT (`GET /financial-entries/{id}` still does not check it; the app does not use it) |
| 21 | The list of entries is ordered by month of reference and then due date; the prototype orders by due date only | In "Todos" the order differs from the prototype | The app shows the order of the API |
| 22 | The entry has no "who created it" and no reconciliation source or date in its response | The timeline says "Criado … por <titular>" and "Vinculado a uma transação do banco" | Uses the owner and `created_at`. Whether it was AUTO or MANUAL is not shown |
| 23 | Read only: no endpoints to create, edit, cancel, reopen, link or unlink entries (the old `POST /financial-entries` was removed as dead code) | The FAB "Novo lançamento" and the buttons of the entry detail | Left out |
| 24 | No last-sync date of an account (`updated_at` is when our row changed, not when Pluggy synced) | "Atualizado há X" of the Contas prototype | Left out |
| 25 | No real-time refresh of the balance. The Pluggy client for it was removed as dead code (it was never used, its schema was wrong, it works only on Open Finance connectors and shares the rate limit with the sync). It can come back from the git history | The balance can be up to ~24h old (Meu Pluggy refresh) | Shows the stored balance. A future "Atualizar" button needs the client and an endpoint that saves the new balance |
| 26 | On Open Finance the balance of a card is the **used limit**, not always the open bill | The prototype label "Fatura atual" and "Faturas abertas nos cartões" may not match | Shown as in the prototype |
| 27 | The limits of a card (`credit_limit`, `available_credit_limit`) and the dates may be null | The usage bar | The bar is left out when there is no limit |
| 28 | No endpoint for the bank connections (see gap 1) | "Conexões bancárias" and "Conectar banco" on Contas | Left out |


**Known limit of the totals (gap 5):** they sum every DEBIT / CREDIT. A credit card bill payment is a DEBIT in the bank account and a CREDIT in the card, and transfers between own accounts are both, so expenses can be counted twice and revenues inflated. A filter will come later.

`GET /transactions` and `GET /bank-accounts` only return data of the household of the logged user. The household comes from the JWT and is never a query parameter (a `household_id` in the query is a 422). The `/{id}` routes of both are not scoped yet and the app does not use them.
