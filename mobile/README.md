# Tally mobile

Flutter client of the Tally API (personal finance assistant for a household).
UI language: pt-BR. Currency: BRL. Dates: dd/MM/yyyy.

Status: **Phase 1 (foundation)** done. See `docs/ARCHITECTURE.md` for the rules
and `docs/BACKEND_GAPS.md` for what the API does not have yet.

## Run

The API address is never hardcoded. It comes from `--dart-define`.
Without `API_BASE_URL` the app shows a "Configuração ausente" screen.

```bash
# Android emulator (10.0.2.2 is the host machine, "localhost" of your PC)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# Real device on the same network
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000

# Production: https is required
flutter run --release --dart-define=API_BASE_URL=https://api.example.com --dart-define=ENVIRONMENT=prod
```

Plain `http` works only in debug/profile builds (their manifest allows it).
Release builds block cleartext traffic, and `ENVIRONMENT=prod` rejects `http` URLs.

## Check

```bash
flutter pub get
flutter analyze        # must have zero issues
flutter test           # unit and widget tests, no network
```

After editing `lib/l10n/app_pt.arb`, run `flutter gen-l10n`.

## Release build

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.example.com --dart-define=ENVIRONMENT=prod \
  --obfuscate --split-debug-info=build/symbols
```

Keep `build/symbols` (do not commit it): it is needed to read crash stack traces.

## Folder map

```
lib/
  main.dart      bootstrap only (config, DI, runApp)
  app/           app.dart, router/, di/, theme/
  core/          config, error (Failure), result, network (Dio), storage, utils, state, pagination, widgets
  features/      one folder per feature: domain / data / presentation
  l10n/          pt-BR strings (ARB) and generated code
test/            mirrors lib/, test/support has fakes
docs/            ARCHITECTURE.md, BACKEND_GAPS.md
```

## Security summary

- JWT only in `flutter_secure_storage` (Keychain/Keystore). Never in preferences, never logged.
- `shared_preferences` only for theme and other non-sensitive settings.
- No backups on Android, HTTPS only in release, no secrets in the repository.
- Debug log prints method, path and status only. No headers, query or bodies.
- Privacy screen (hide in app switcher) is available but off. See `docs/ARCHITECTURE.md`.
