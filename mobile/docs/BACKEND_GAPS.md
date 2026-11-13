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
| 5 | No analysis summary (by month, category, member) | Home dashboard, charts | Fake data source (or computed from lists when possible) |
| 6 | No update/delete for entries and recurrences | Edit/cancel actions | Not built |
| 7 | No credit limit or due date in `BankAccountResponse` | Card details | Not shown |
| 8 | `GET /bank-accounts` and `GET /users` return plain lists (no `total`) | "Has more" is guessed from a full page | `PaginatedViewModel` handles it |
| 9 | Chat is stateless (`POST /tally/chat {message}`); no conversation id or history | "Nova conversa", history list | The thread lives in memory. History will be owned by the API |
| 10 | Validation 422 returns `detail` as a list, other errors as a string | Client must accept both | Done in `ErrorInterceptor` |

Not in the original app brief but present in the API: `POST /recurrences/provision`
(creates the month's PLANNED entries from recurrences) and `GET /users/{id}`.
