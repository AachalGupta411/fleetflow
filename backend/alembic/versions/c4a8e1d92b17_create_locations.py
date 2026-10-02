"""create locations

Revision ID: c4a8e1d92b17
Revises: 91b71793c2e0
Create Date: 2026-09-28 23:58:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c4a8e1d92b17"
down_revision: Union[str, Sequence[str], None] = "91b71793c2e0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "locations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("vehicle_id", sa.Uuid(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=False),
        sa.Column("longitude", sa.Float(), nullable=False),
        sa.Column("accuracy", sa.Float(), nullable=True),
        sa.Column("speed", sa.Float(), nullable=True),
        sa.Column("heading", sa.Float(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("latitude >= -90 AND latitude <= 90", name="latitude"),
        sa.CheckConstraint("longitude >= -180 AND longitude <= 180", name="longitude"),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name=op.f("fk_locations_driver_id_drivers")),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"], name=op.f("fk_locations_vehicle_id_vehicles")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_locations")),
    )
    op.create_index(op.f("ix_locations_driver_id"), "locations", ["driver_id"], unique=False)
    op.create_index(
        "ix_locations_driver_id_timestamp",
        "locations",
        ["driver_id", "timestamp"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_locations_driver_id_timestamp", table_name="locations")
    op.drop_index(op.f("ix_locations_driver_id"), table_name="locations")
    op.drop_table("locations")
