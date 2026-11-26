# Recurrence detection

Tally AI looks at the past bank transactions, finds what repeats every month (rent, salary,
subscriptions) and suggests recurrences (recorrências) from them. The person confirms each
suggestion in the chat, and only then the recurrence is created.

The detection is **deterministic Python**, not a guess of the model: the same transactions
always give the same candidates, with the same amounts and scores. The model only shows the
candidates and asks for the confirmation.

## Where the code lives

| Layer | File | What it does |
|---|---|---|
| Domain (pure rules) | `backend/domain/recurrence_detection.py` | Normalizes descriptions, groups the transactions, checks the monthly rhythm, builds the candidates. No database. |
| Service | `backend/services/recurrence_detection_service.py` | Reads the transactions, the accounts and the active recurrences of the household, calls the domain rules, creates the recurrence of a confirmed candidate. |
| Agent tools | `backend/agents/tools/recurrence_detection.py` | `suggest_my_recurrences`, `suggest_household_recurrences` (read only, Owl's) and `create_suggested_recurrence` (writes, Tally's, only after the confirmation). |
| Owl | `backend/agents/owl/`, `backend/agents/tools/owl.py` | Owl, the planning specialist: a read-only sub-agent with the entries and recurrences tools (moved from Tally), the suggest tools and `calculate`. Tally asks it with `ask_owl`. |
| Tally AI | `backend/agents/tally/agent.py` | Gets `ask_owl` and `create_suggested_recurrence`, and no entries or recurrences tools any more. Hawk does not change: it stays read only. |

## Detection rule

1. **Input**: the POSTED transactions of the household in the last 12 months (configurable),
   with their owner. Internal transfers that are already classified are left out by the query
   (`exclude_internal_transfers`).
2. **Left out** before grouping:
   - internal transfers not classified yet: the pairs `domain/internal_transfers.py` finds
     among the loaded transactions;
   - credit card bill payments (`PAGAMENTO_FATURA`): the bill is not a recurrence, its
     purchases are;
   - installments of a purchase (`installmentNumber`/`totalInstallments` from Pluggy, or a
     `PARC 3/10` marker in the description): they end, so they are not recurrences;
   - transactions in a foreign currency without the converted value.
3. **Normalized description**: lowercase, no accents, no dates (`05/11`, `2026-11-05`), no
   installment markers, no digits, no punctuation, spaces collapsed. `NETFLIX.COM 05/11` and
   `Netflix.com 12/12` are the same `netflix com`.
4. **Groups**: same owner, same direction (DEBIT -> EXPENSES, CREDIT -> REVENUES) and same
   normalized description. Inside a group, the amounts are split where two amounts in a row
   (sorted) differ by more than the amount tolerance (default **10%**).
5. **Monthly rhythm**: inside each amount group, the transactions in date order form a chain
   while each gap is **30 days ± 7** (configurable). The longest chain wins (the newest on a
   tie). It needs **3 or more distinct months**.
6. **Still alive**: the last transaction of the chain must be at most **45 days** old. An old
   subscription that stopped is not suggested.
7. **Already a recurrence**: a candidate is dropped when an ACTIVE recurrence of the household
   has the same type, a description that matches (same normalized text, or one inside the
   other) and an amount inside the tolerance.

## What a candidate has

- `candidate_id`: a short stable id (owner, type, normalized description and the first
  transaction of the chain). New months keep the same id.
- description (the text of the newest transaction), type, owner;
- amount: the **median** of the chain, in cents;
- due day: the median local day of month;
- category: the most common one; payment type: CREDIT when most transactions are on a credit
  card, else DEBIT;
- **confidence** from 0 to 1: `0.4 × months + 0.3 × amount stability + 0.3 × timing`, where
  months is `min(1, months / 6)`, amount stability is `1 - spread / tolerance` and timing is
  `1 - mean gap error / gap tolerance`;
- **evidence**: the date and amount of each transaction of the chain.

The created recurrence has `source = AI` and a note with the number of months it came from.

## Agents and tools

**Owl analyses and suggests, Tally creates.** Owl is the planning specialist: it reads the
entries (lançamentos) and the recurrences (`get_my_entries`, `get_household_entries`,
`get_my_recurrences`, `get_household_recurrences`, that were Tally's before), answers the planning
questions (the month plan, what is coming, what is left at the end of the month) and suggests new
recurrences. Owl is a specialist like Hawk: it keeps no history, so it
never sees the person's answer. The confirmation lives in Tally's conversation, so the tool
that writes is Tally's.

- Owl's tools, `suggest_my_recurrences` / `suggest_household_recurrences`: read only. They list
  the candidates (only the logged person's, or the whole household's with the owner of each
  one) with the id, amount, due day, confidence and evidence.
- Tally's `ask_owl(request)`: runs Owl and returns its answer, followed by the candidate rows
  exactly as the suggest tools wrote them (not Owl's words), so the ids Tally sees are the
  real ones.
- Tally's `create_suggested_recurrence(candidate_id)`: creates the recurrence of one
  candidate. It does not take amounts or descriptions from the model: it runs the detection
  again and uses the candidate with that id. It refuses when:
  - the candidate was not in an `ask_owl` result of this conversation, or the person did not
    write after it (the confirmation must come from the person, in the chat);
  - the id is not a current candidate any more (it may have become a recurrence already).

The prompt tells Tally AI to ask Owl, show the candidates, ask which ones the person wants,
and call the create tool once per candidate that the person confirmed by name.

## Tests

- `backend/tests/domain/test_recurrence_detection.py`: normalization, monthly patterns,
  irregular gaps, amount drift inside and outside the tolerance, fewer than 3 months, old
  series, existing recurrences, internal transfers (classified and not), bill payments,
  installments, type, category, payment type, due day, confidence and stable ids.
- `backend/tests/services/test_recurrence_detection_service.py`: the filters of the query,
  the paging, the owner filter and the creation of a confirmed candidate.
- `backend/tests/agents/tools/test_recurrence_detection.py`: the tool output, the scope, the
  confirmation guard and the errors.
- `backend/tests/agents/owl/test_agent.py`: Owl has the planning tools, the suggest tools and the
  calculator, all read only, and no history.
- `backend/tests/agents/tools/test_owl.py`: `ask_owl` passes the context and appends the
  candidate rows of the rules.
- `backend/tests/agents/tally/test_agent.py`: Tally AI has `ask_owl` and the create tool, and no
  entries or recurrences tools.
