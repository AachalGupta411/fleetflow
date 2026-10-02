"""delivery execution

Revision ID: d8f3a1c04e22
Revises: c4a8e1d92b17
Create Date: 2026-09-29 00:55:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "d8f3a1c04e22"
down_revision: Union[str, Sequence[str], None] = "c4a8e1d92b17"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("deliveries", sa.Column("picked_up_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("deliveries", sa.Column("arrived_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("deliveries", sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("deliveries", sa.Column("failed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("deliveries", sa.Column("failure_code", sa.String(length=40), nullable=True))
    op.add_column("deliveries", sa.Column("failure_notes", sa.Text(), nullable=True))
    op.add_column("deliveries", sa.Column("recipient_name", sa.String(length=120), nullable=True))
    op.add_column("deliveries", sa.Column("recipient_phone", sa.String(length=20), nullable=True))
    op.add_column("deliveries", sa.Column("pod_photo_key", sa.String(length=255), nullable=True))
    op.add_column("deliveries", sa.Column("signature_key", sa.String(length=255), nullable=True))
    op.add_column("deliveries", sa.Column("pod_notes", sa.Text(), nullable=True))
    op.add_column("deliveries", sa.Column("delivery_latitude", sa.Float(), nullable=True))
    op.add_column("deliveries", sa.Column("delivery_longitude", sa.Float(), nullable=True))
    op.add_column("deliveries", sa.Column("delivery_accuracy", sa.Float(), nullable=True))
    op.add_column("deliveries", sa.Column("geofence_entered_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "delivery_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("delivery_id", sa.Uuid(), nullable=False),
        sa.Column("event_type", sa.String(length=40), nullable=False),
        sa.Column("actor_user_id", sa.Uuid(), nullable=True),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["actor_user_id"], ["users.id"], name=op.f("fk_delivery_events_actor_user_id_users")),
        sa.ForeignKeyConstraint(["delivery_id"], ["deliveries.id"], name=op.f("fk_delivery_events_delivery_id_deliveries")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_delivery_events")),
    )
    op.create_index(op.f("ix_delivery_events_delivery_id"), "delivery_events", ["delivery_id"], unique=False)
    op.create_table(
        "delivery_operations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("client_operation_id", sa.String(length=80), nullable=False),
        sa.Column("delivery_id", sa.Uuid(), nullable=False),
        sa.Column("driver_id", sa.Uuid(), nullable=False),
        sa.Column("action", sa.String(length=40), nullable=False),
        sa.Column("result_status", sa.String(length=40), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(["delivery_id"], ["deliveries.id"], name=op.f("fk_delivery_operations_delivery_id_deliveries")),
        sa.ForeignKeyConstraint(["driver_id"], ["drivers.id"], name=op.f("fk_delivery_operations_driver_id_drivers")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_delivery_operations")),
        sa.UniqueConstraint("client_operation_id", name=op.f("uq_delivery_operations_client_operation_id")),
    )
    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column("platform", sa.String(length=20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_device_tokens_user_id_users")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_device_tokens")),
        sa.UniqueConstraint("token", name=op.f("uq_device_tokens_token")),
    )
    op.create_index(op.f("ix_device_tokens_user_id"), "device_tokens", ["user_id"], unique=False)
    op.create_table(
        "notifications",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("shipment_id", sa.Uuid(), nullable=True),
        sa.Column("kind", sa.String(length=40), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("push_sent", sa.Boolean(), server_default=sa.text("false"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["shipment_id"], ["shipments.id"], name=op.f("fk_notifications_shipment_id_shipments")),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], name=op.f("fk_notifications_user_id_users")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_notifications")),
    )
    op.create_index(op.f("ix_notifications_user_id"), "notifications", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_notifications_user_id"), table_name="notifications")
    op.drop_table("notifications")
    op.drop_index(op.f("ix_device_tokens_user_id"), table_name="device_tokens")
    op.drop_table("device_tokens")
    op.drop_table("delivery_operations")
    op.drop_index(op.f("ix_delivery_events_delivery_id"), table_name="delivery_events")
    op.drop_table("delivery_events")
    for name in (
        "geofence_entered_at",
        "delivery_accuracy",
        "delivery_longitude",
        "delivery_latitude",
        "pod_notes",
        "signature_key",
        "pod_photo_key",
        "recipient_phone",
        "recipient_name",
        "failure_notes",
        "failure_code",
        "failed_at",
        "delivered_at",
        "arrived_at",
        "picked_up_at",
    ):
        op.drop_column("deliveries", name)
