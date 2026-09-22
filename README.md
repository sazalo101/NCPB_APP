# NCPB Store Records — MVP (v2)

Staff log in, record stock movements (who's bringing in / taking out what,
how much, when), and upload invoice PDFs against a customer. Data now
persists in a real SQLite database instead of JSON files.

## What's new in this version

- **Edit existing records** — tap the edit icon on any record to load it into
  the form, change it, and save (updates in place instead of creating a new one)
- **Date + time on every record** — both are now captured, shown together
  on each record
- **Running stock balance per product** — each record shows "Balance after"
  reflecting the cumulative total for that product up to that point in time
  (In adds, Out subtracts), plus the overall current-stock summary card
- **View invoices from the dashboard** — an open icon on each invoice opens
  the uploaded PDF directly

- **SQLite database** (`backend/data/ncpb.db`) instead of JSON files
- **Staff login required** — token-based auth, default account seeded on
  first run: `admin` / `admin123` (change this — see "Managing staff logins" below)
- **Redesigned UI** — card-based forms, colored In/Out and status badges,
  responsive layout (side navigation on wide/desktop screens, bottom nav on
  narrow/mobile), date pickers instead of free-text date fields
- Fixed the `shelf_multipart` import issue from the previous version

## What's in this zip

```
ncpb_invoice_mvp/
├── backend/
│   ├── bin/server.dart      # API server
│   ├── lib/db.dart          # SQLite database layer
│   ├── pubspec.yaml
│   ├── data/                # ncpb.db gets created here
│   └── uploads/              # uploaded invoice PDFs
└── frontend_lib/             # Flutter source (see setup below)
    ├── lib/
    └── pubspec.yaml
```

---

## 1. System requirement: SQLite native library

The `sqlite3` Dart package needs the SQLite native library available on
your system. Kali usually has this already, but confirm:

```bash
sudo apt update
sudo apt install -y libsqlite3-0
```

## 2. Run the backend

```bash
cd backend
dart pub get
dart run bin/server.dart
```

You should see:
```
NCPB Invoice Manager API running on http://0.0.0.0:8080
Seeded default login -> username: admin  password: admin123
```

(The "Seeded" message only appears the first time — after that, the
account already exists in the database.)

Leave this running.

## 3. Set up the Flutter frontend

```bash
flutter create ncpb_app
cd ncpb_app
rm -rf lib
cp -r /path/to/ncpb_invoice_mvp/frontend_lib/lib .
cp /path/to/ncpb_invoice_mvp/frontend_lib/pubspec.yaml .
flutter pub get
```

## 4. Run it

```bash
flutter run -d chrome
```

Log in with `admin` / `admin123`.

### Backend address for Android

In `lib/api_service.dart`:
```dart
static const String baseUrl = 'http://localhost:8080';
```
- Web, same machine as backend → leave as `localhost`
- Android emulator → change to `http://10.0.2.2:8080`
- Physical Android phone (same WiFi) → your computer's LAN IP, e.g.
  `http://192.168.1.50:8080` (find it with `ip a`)

---

## Managing staff logins

There's no "add staff" screen in the UI yet (MVP scope). To add another
staff login for now, stop the server and add one directly via a quick
Dart script, or ask me to add a simple "add staff" admin screen /
endpoint next. The default `admin`/`admin123` account works for testing
in the meantime — change that password before this goes into real use.

## How auth works (so behavior makes sense)

- Logging in gets a session token, held in memory by the app for as long
  as it's open. Refreshing a web page or restarting the app logs you out.
- Restarting the **backend** clears all active sessions too (tokens live
  in memory, not the database) — everyone will need to log in again.
- This is fine for an MVP; a production version would want persistent,
  expiring sessions.

## Data storage

- Records and invoices: `backend/data/ncpb.db` (SQLite — open it with
  `sqlite3 backend/data/ncpb.db` or any SQLite viewer to inspect data
  directly)
- Invoice PDFs: `backend/uploads/`

## Troubleshooting

- **"Could not load records" / "Session expired"** → backend isn't
  running, or you were logged out (restart-related, see above) — just
  log in again.
- **`dart pub get` fails on `sqlite3`** → make sure `libsqlite3-0` is
  installed (step 1).
- **File picker doesn't show PDFs** → confirm the file is actually
  a `.pdf` — the picker is filtered to that extension.
# NCPB_APP
