# FleetFlow database

Local development uses a database named `fleetflow`. Connection settings live in `backend/.env` (`DATABASE_URL`). Copy `backend/.env.example` and fill in a real URL. Do not commit `.env`.

Schema changes are managed with Alembic from `backend/`:

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
```

The current revision creates:

- users
- drivers
- vehicles
- shipments
- deliveries
- locations
- delivery execution columns on deliveries
- delivery_events
- delivery_operations
- device_tokens
- notifications
- fuel_records
- vehicle fuel and service columns

Development sample data is loaded separately:

```bash
python scripts/seed_dev.py --confirm-dev
```

`locations` stores each driver GPS fix. Current fleet position is the latest row per driver. Older rows are kept.

Later milestones can add proof of delivery, fuel records, and notifications when those features are built.
