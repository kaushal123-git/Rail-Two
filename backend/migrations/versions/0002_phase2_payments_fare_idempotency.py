"""0002_phase2_payments_fare_idempotency

Revision ID: 0002_phase2_payments_fare_idempotency
Revises: 0001_initial_schema
Create Date: 2026-10-05 23:25:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0002_phase2_payments_fare_idempotency'
down_revision: Union[str, None] = '0001_initial_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add currency to tickets
    op.add_column(
        'tickets',
        sa.Column('currency', sa.String(length=10), nullable=False, server_default='INR')
    )

    # 2. payments table
    op.create_table(
        'payments',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('gateway', sa.String(length=50), nullable=False, server_default='RAZORPAY'),
        sa.Column('gateway_order_id', sa.String(length=100), nullable=True),
        sa.Column('gateway_payment_id', sa.String(length=100), nullable=True),
        sa.Column('gateway_signature', sa.String(length=255), nullable=True),
        sa.Column('amount', sa.Float(), nullable=False),
        sa.Column('currency', sa.String(length=10), nullable=False, server_default='INR'),
        sa.Column('status', sa.String(length=30), nullable=False, server_default='CREATED'),
        sa.Column('failure_reason', sa.Text(), nullable=True),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('verified_at', sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index('ix_payments_id', 'payments', ['id'])
    op.create_index('ix_payments_user_id', 'payments', ['user_id'])
    op.create_index('ix_payments_ticket_id', 'payments', ['ticket_id'])
    op.create_index('ix_payments_gateway_order_id', 'payments', ['gateway_order_id'])
    op.create_index('ix_payments_gateway_payment_id', 'payments', ['gateway_payment_id'])
    op.create_index('ix_payments_status', 'payments', ['status'])

    # 3. fare_rules table
    op.create_table(
        'fare_rules',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('origin_zone', sa.String(length=50), nullable=False, server_default='*'),
        sa.Column('destination_zone', sa.String(length=50), nullable=False, server_default='*'),
        sa.Column('journey_type', sa.String(length=20), nullable=False, server_default='SINGLE'),
        sa.Column('ticket_class', sa.String(length=20), nullable=False, server_default='SECOND'),
        sa.Column('min_distance_km', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('max_distance_km', sa.Float(), nullable=False, server_default='9999.0'),
        sa.Column('base_fare', sa.Float(), nullable=False),
        sa.Column('per_km_rate', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('discount_percentage', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('tax_percentage', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('discount_rule', sa.String(length=100), nullable=True),
        sa.Column('active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('version', sa.String(length=20), nullable=False, server_default='v1.0'),
        sa.Column('effective_from', sa.DateTime(timezone=True), nullable=False),
        sa.Column('effective_until', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_fare_rules_id', 'fare_rules', ['id'])
    op.create_index('ix_fare_rules_journey_type', 'fare_rules', ['journey_type'])
    op.create_index('ix_fare_rules_ticket_class', 'fare_rules', ['ticket_class'])
    op.create_index('ix_fare_rules_active', 'fare_rules', ['active'])

    # 4. idempotency_keys table
    op.create_table(
        'idempotency_keys',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('key', sa.String(length=255), unique=True, nullable=False),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
        sa.Column('request_path', sa.String(length=255), nullable=False),
        sa.Column('request_hash', sa.String(length=64), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='PENDING'),
        sa.Column('response_code', sa.Integer(), nullable=True),
        sa.Column('response_status_code', sa.Integer(), nullable=True),
        sa.Column('response_body', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_idempotency_keys_id', 'idempotency_keys', ['id'])
    op.create_index('ix_idempotency_keys_key', 'idempotency_keys', ['key'])
    op.create_index('ix_idempotency_keys_user_id', 'idempotency_keys', ['user_id'])


def downgrade() -> None:
    op.drop_table('idempotency_keys')
    op.drop_table('fare_rules')
    op.drop_table('payments')
    op.drop_column('tickets', 'currency')
