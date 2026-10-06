"""0006_phase7_loco_assist_tables

Revision ID: 0006_phase7_loco_assist_tables
Revises: 0005_phase5_custom_ml_fraud_engine
Create Date: 2026-10-06 20:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0006_phase7_loco_assist_tables'
down_revision: Union[str, None] = '0005_phase5_custom_ml_fraud_engine'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. assistant_requests table (audit trail)
    op.create_table(
        'assistant_requests',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('session_id', sa.String(length=36), nullable=True),
        sa.Column('request_id', sa.String(length=64), nullable=False, index=True),
        sa.Column('query', sa.Text(), nullable=False),
        sa.Column('intent', sa.String(length=64), nullable=False, index=True),
        sa.Column('tool_name', sa.String(length=64), nullable=True, index=True),
        sa.Column('tool_arguments_hash', sa.String(length=64), nullable=True),
        sa.Column('result_status', sa.String(length=32), nullable=False, server_default='SUCCESS'),
        sa.Column('error_code', sa.String(length=64), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )

    # 2. assistant_actions table (sensitive confirmations)
    op.create_table(
        'assistant_actions',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True),
        sa.Column('action_type', sa.String(length=64), nullable=False),
        sa.Column('target_id', sa.String(length=64), nullable=False),
        sa.Column('confirmation_token', sa.String(length=128), nullable=False, unique=True, index=True),
        sa.Column('status', sa.String(length=32), nullable=False, server_default='PENDING_CONFIRMATION'),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('executed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('assistant_actions')
    op.drop_table('assistant_requests')
