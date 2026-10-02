"""vehicle operations and fuel records

Revision ID: a7c2e91b4f05
Revises: d8f3a1c04e22
Create Date: 2026-09-29 01:25:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a7c2e91b4f05"
down_revision: Union[str, Sequence[str], None] = "d8f3a1c04e22"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("vehicles", sa.Column("fuel_type", sa.String(length=20), nullable=True))
    op.add_column("vehicles", sa.Column("fuel_efficiency_km_per_liter", sa.Numeric(precision=6, scale=2), nullable=True))
    op.add_column("vehicles", sa.Column("current_odometer_km", sa.Numeric(precision=10, scale=1), nullable=True))
    op.add_column("vehicles", sa.Column("last_service_date", sa.Date(), nullable=True))
    op.add_column("vehicles", sa.Column("next_service_due_km", sa.Numeric(precision=10, scale=1), nullable=True))
    op.add_column(
        "vehicles",
        sa.Column("service_status", sa.String(length=20), server_default="OK", nullable=False),
    )
    op.create_table(
        "fuel_records",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=True),
        sa.Column("liters", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("price_per_liter", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("total_cost", sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column("odometer_km", sa.Numeric(precision=10, scale=1), nullable=True),
        sa.Column("fuel_station", sa.String(length=120), nullable=True),
        sa.Column("fuel_date", sa.Date(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name=op.f("fk_fuel_records_driver_id_drivers")),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name=op.f("fk_fuel_records_vehicle_id_vehicles")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_fuel_records")),
    )
    op.create_index("ix_fuel_records_vehicle_id_fuel_date", "fuel_records", ["vehicle_id", "fuel_date"], unique=False)
    op.create_index("ix_fuel_records_driver_id", "fuel_records", ["driver_id"], unique=False)
    op.create_index("ix_deliveries_delivered_at", "deliveries", ["delivered_at"], unique=False)
    op.create_index("ix_deliveries_failed_at", "deliveries", ["failed_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_deliveries_failed_at", table_name="deliveries")
    op.drop_index("ix_deliveries_delivered_at", table_name="deliveries")
    op.drop_index("ix_fuel_records_driver_id", table_name="fuel_records")
    op.drop_index("ix_fuel_records_vehicle_id_fuel_date", table_name="fuel_records")
    op.drop_table("fuel_records")
    op.drop_column("vehicles", "service_status")
    op.drop_column("vehicles", "next_service_due_km")
    op.drop_column("vehicles", "last_service_date")
    op.drop_column("vehicles", "current_odometer_km")
    op.drop_column("vehicles", "fuel_efficiency_km_per_liter")
    op.drop_column("vehicles", "fuel_type")
