# Architecture

MVVM + Clean Architecture, feature-first. Dependencies point inward.

```
presentation  ──►  domain  ◄──  data
(View, ViewModel)  (entities,    (DTO, mapper, data sources,
                    repository    repository implementation)
                    interfaces,
                    use cases)
```

## Layers

| Layer | Contains | May import |
|---|---|---|
| `domain` | entities (Equatable, immutable), repository **interfaces**, use cases | pure Dart + `core/result`, `core/error`. No Flutter, no Dio, no storage |
| `data` | DTOs (`fromJson`), mappers, remote/fake data sources, repository implementations | domain, Dio, core |
| `presentation` | ViewModels (`ChangeNotifier`), views, feature widgets | domain, Flutter, provider |

Rules:
- **View**: renders state and forwards actions. No API calls, no business `if`.
- **ViewModel**: one per screen, never imports `BuildContext`/`Navigator`. Holds an immutable `UiState` (`UiInitial | UiLoading | UiSuccess | UiEmpty | UiError`). Calls **use cases**, never repositories.
- **Use case**: one class, one `call`, returns `Result<T>`.
- **Entities are not DTOs.** Map at the repository boundary. No business rule in `fromJson`.
- Navigation is done by the View or by the router redirect, never by a ViewModel.
- Errors: data sources use `apiCall(...)`, which returns `Result<T>` with a typed `Failure`. A `DioException` never leaves the data layer. Views show pt-BR text with `failureMessage(...)`; server text (English) is never shown.
- Money is `Decimal` (never `double`). Formatting only through `MoneyFormatter`, dates through `DateFormatter`. Strings only in `lib/l10n/app_pt.arb`.

## Network (`core/network`)

Interceptor order: `AuthInterceptor` (adds `Bearer`, on 401 clears the token and fires `SessionExpiredNotifier` once) → `ErrorInterceptor` (Dio error → `Failure`) → `SafeLogInterceptor` (debug only).

API error shape: `{"detail": "<English text>"}`, except request validation (422) where `detail` is a **list** of `{loc, msg, type}`. `ErrorInterceptor` reads only the field names.
401 on `/auth/login` = wrong credentials; 401 anywhere else = expired session. There is no refresh token.

## Session and login

`SessionController` (`core/session`) says whether somebody is logged in. A token in secure storage means logged in; `main.dart` calls `restore()` before the router is built. When the API answers 401 outside of login, `AuthInterceptor` clears the token and tells `SessionExpiredNotifier`, and the controller turns to logged out and remembers that the session expired (the login screen shows a notice).

The router (`createAppRouter`) gets `redirect: sessionRedirect(session)` and `refreshListenable: session`: without a session every route goes to `/login`, and with one `/login` goes to `/home`. The login screen and the home are passed in by the caller (they need a ViewModel from the DI container), so tests can use plain widgets.

Login: `LoginView` creates its own `LoginViewModel` (fresh state on each visit). On success the repository has already saved the token, and the ViewModel calls `session.onLoggedIn()`.

## State and lists

`PaginatedViewModel<T>` (`core/pagination`) gives `load / refresh / loadMore` with `limit/offset`. Late answers of an older request (for example an old search text) are ignored. `AsyncStateView` renders every `UiState` the same way (skeleton, empty, error + retry).

## Scope (Eu / Casa / member)

Maps to the `user_id` query parameter: Eu = my id, member = their id, Casa = omitted.

The choice is **shared between the tabs** by one `HouseholdScopeController` (a singleton in `features/household`). It loads the profile once and is cleared when the session ends. Home and Transações listen to it; because the tabs stay alive (`indexedStack`), a change reloads both.

## Endpoints the app uses

Every backend endpoint the app calls is declared in `lib/core/network/api_endpoints.dart` (`ApiEndpoints`), with its method, its path and the feature that uses it. Data sources take the path from there, never a string typed in place.

This list is also the mark used to clean the backend: a route of `backend/presentation/routers` that is not in `ApiEndpoints.all` is a candidate for removal. Add the endpoint in the same change that creates it. The list is **not complete yet** (see the comment in the file), so do not delete routes from it alone.

## Home (first real screen)

One ViewModel for the screen, but **one `UiState` for each section**: every card loads, fails and retries alone (`AsyncStateView` with its own skeleton), and all of them load at the same time. The profile (me and the people of the house) loads first; the others need it for the "who appears" choice.

Period rule: the app always sends `date_from` and `date_to`, never the API default (on day 1 of a month the default would be the previous month, and the label would lie). `MonthPeriod` decides the days: a past month is whole, the current month goes from day 1 until yesterday, and on day 1 of the current month no transaction endpoint is called. Planning endpoints are by month and get the whole month.

Numbers are never calculated in the ViewModel with `double`. Money stays `Decimal`; a `double` only sizes a bar (`ratio`, `shareOf`).

## Transações (list and detail)

`TransactionsViewModel` uses `PaginatedViewModel` (pages of 30, "Mostrando X de Y" from `total`). It reloads when the person, the filters or the search text change (the text waits 300 ms). The accounts load beside the list: they give the account name of each row and say whether the chosen person has a bank at all (the "sem banco conectado" card).

- The direction of a transaction comes from `type` (DEBIT / CREDIT), never from the sign of `amount` (a credit card purchase comes positive). The sum of a day is credits minus debits.
- The day of a transaction is its **UTC** calendar day. "Hoje" and "Ontem" compare it with the local day.
- The filter sheet has no category field on purpose (the API may not have categories). The category text of a transaction is shown as the bank sends it (maybe in English).
- The detail screen (`/transactions/detail`) opens on the root navigator, over the tabs. It receives the transaction by `extra`, so it needs no request. Opened without it (for example after a restore), it says so and goes back to the list.

## Dependency injection

`get_it` in `app/di/injection.dart`. Services are lazy singletons, ViewModels are factories (one per screen). Tests build a fresh container with fakes (`registerCoreDependencies`).

## How to add a feature (step by step)

1. Read the endpoint in `backend/presentation/routers` and the schema in `backend/presentation/schemas`. Do not invent fields.
2. `domain/entities`: immutable Equatable classes. `domain/repositories`: abstract interface returning `Result<T>`.
3. `domain/usecases`: one class per action.
4. `data/models`: DTOs with `fromJson` (use `parseDecimal`, `parseDateTime`). `data/mappers`: DTO ↔ entity.
5. `data/datasources`: remote (Dio + `apiCall`), with the path from `ApiEndpoints` (add the endpoint there if it is not listed). If the endpoint does not exist yet: a fake data source, marked `// TODO(backend)`, and a line in `docs/BACKEND_GAPS.md`.
6. `data/repositories`: implement the interface.
7. `presentation/viewmodels`: `ChangeNotifier` + `UiState` (or `PaginatedViewModel`). Register as a factory in DI.
8. `presentation/views`: use `AsyncStateView`. Add strings to the ARB file and run `flutter gen-l10n`. Add the route in `app/router`.
9. Tests mirroring the folders (mappers, use cases, ViewModel states, repository with mocked data source, one widget test). Run `flutter analyze` and `flutter test`.

## Privacy screen (hide content in the app switcher)

Off by default.
- **Android**: in `MainActivity.kt` set `PRIVACY_SCREEN_ENABLED = true` (uses `FLAG_SECURE`: also blocks screenshots).
- **iOS**: not implemented yet. To enable, in `AppDelegate` add a blur/colored view over the window in `applicationWillResignActive` and remove it in `applicationDidBecomeActive`.

## Later phases (prepared, not enabled)

- Biometric lock: `AppLockService` interface + `local_auth`, after phase 7.
- Chat history lives in the backend (phase 7 builds only the UI).
