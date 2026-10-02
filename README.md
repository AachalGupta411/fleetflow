# FleetFlow

Mobile logistics application for shipments, tracking, proof of delivery, and fleet operations. Feature development is complete through operations analytics. Billing and predictive analytics are not included.

## Layout

- `frontend/` — Flutter app (Android is the primary target)
- `backend/` — FastAPI
- `database/` — notes for the PostgreSQL database. Alembic lives in `backend/alembic`

## Backend

PostgreSQL 14 is expected on `localhost:5432`, with a database named `fleetflow`.

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit DATABASE_URL, JWT_SECRET, and CORS_ORIGINS.
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Apply the schema and load development sample data. The seed command writes only when you pass `--confirm-dev`, and it refuses any database host other than localhost.

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
python scripts/seed_dev.py --confirm-dev
```

Development password for every seeded account: `Fleetflow-Dev-2026`

- `admin@fleetflow.dev`
- `manager@fleetflow.dev`
- `customer@fleetflow.dev`
- `driver@fleetflow.dev` (available)
- `driver.assigned@fleetflow.dev`
- `driver.transit@fleetflow.dev`

These accounts exist only after the seed script runs. They are not built into the API.

Checks:

- http://127.0.0.1:8000/
- http://127.0.0.1:8000/health
- http://127.0.0.1:8000/docs

`GET /health` runs `SELECT 1` against PostgreSQL. If the database is down, the response is HTTP 503 and `"database": "disconnected"`.

```bash
cd backend
source .venv/bin/activate
pytest
alembic current
```

`alembic upgrade head` creates `users`, `drivers`, `vehicles`, `shipments`, `deliveries`, and `locations`.

## Tracking and maps

Drivers share a foreground GPS fix only while a delivery is picked up, in transit, or arriving. The API stores every fix. Fleet and customer screens read the latest fix for each driver.

Location freshness is `LIVE` within 45 seconds, `RECENT` within 3 minutes, `STALE` within 15 minutes, and `OFFLINE` after that or when no fix exists.

Google Maps needs two keys, and neither is committed:

- `GOOGLE_MAPS_API_KEY` in `backend/.env` enables Directions and Geocoding for distance and ETA. Leave it empty and the API returns no ETA.
- `MAPS_API_KEY` in `frontend/android/local.properties` is the Android Maps SDK key. That file is gitignored. Rebuild with `--dart-define=MAPS_CONFIGURED=true` so the map widget is shown. Without that flag, the tracking screens stay usable and say that Maps configuration is required.

## Android app

The API base URL is set in one place: `frontend/lib/core/network/api_config.dart`.

| Where the app runs | Base URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator, desktop, tests | `http://127.0.0.1:8000` |
| Physical Android device | `--dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000` |

Debug Android builds allow cleartext HTTP so the app can reach this local API. Do not ship a release build against HTTP.

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run
```

Start the API with `--host 0.0.0.0` before opening the app on a device or emulator. The landing screen shows the base URL it is using and the result of `GET /health`.

`flutter build apk --debug` produces `frontend/build/app/outputs/flutter-apk/app-debug.apk`.

## Configuration

Backend settings live in `backend/.env` (see `backend/.env.example`). `APP_ENV=production` refuses a wildcard `CORS_ORIGINS` and a `JWT_SECRET` shorter than 32 characters. Leave `GOOGLE_MAPS_API_KEY`, Supabase, and `FIREBASE_CREDENTIALS_FILE` empty until those services are configured. Proof files stay on local disk when `STORAGE_PROVIDER=local`.

The Flutter app reads `API_BASE_URL` from `--dart-define`. Map tiles appear only when the build also passes `--dart-define=MAPS_CONFIGURED=true` and `MAPS_API_KEY` is in the gitignored `frontend/android/local.properties`. Without that, tracking screens still show status, freshness, and ETA text.

Alerts stored by the API are in-app. `push_sent` stays false until a Firebase credential file is configured, and the app does not claim that a push reached the phone.

An expired token returns 401, clears the saved session, and the login screen asks the user to sign in again. A network failure during startup keeps the saved profile so a driver is not signed out while offline.

The AVD named `ShieldAI_Pixel` is registered, but it cannot boot until this system image exists:

`~/Library/Android/sdk/system-images/android-35/google_apis/arm64-v8a/`

Install that image from Android Studio’s SDK Manager, or with the SDK command-line tool, then launch it:

```bash
flutter emulators --launch ShieldAI_Pixel
cd frontend
flutter run
```
