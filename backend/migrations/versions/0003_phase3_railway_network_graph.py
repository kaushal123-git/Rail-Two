"""0003_phase3_railway_network_graph

Revision ID: 0003_phase3_railway_network_graph
Revises: 0002_phase2_payments_fare_idempotency
Create Date: 2026-10-06 05:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0003_phase3_railway_network_graph'
down_revision: Union[str, None] = '0002_phase2_payments_fare_idempotency'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. railway_lines table
    op.create_table(
        'railway_lines',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('code', sa.String(length=20), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('display_name', sa.String(length=150), nullable=False),
        sa.Column('operator', sa.String(length=100), nullable=False, server_default='Indian Railways / Mumbai Suburban'),
        sa.Column('color_code', sa.String(length=20), nullable=False, server_default='#FF5722'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_railway_lines_code'), 'railway_lines', ['code'], unique=True)
    op.create_index(op.f('ix_railway_lines_id'), 'railway_lines', ['id'], unique=False)

    # 2. station_connections table
    op.create_table(
        'station_connections',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('from_station_id', sa.String(length=36), sa.ForeignKey('stations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('to_station_id', sa.String(length=36), sa.ForeignKey('stations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('line_id', sa.String(length=36), sa.ForeignKey('railway_lines.id', ondelete='CASCADE'), nullable=True),
        sa.Column('sequence', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('distance_km', sa.Float(), nullable=False),
        sa.Column('scheduled_travel_seconds', sa.Integer(), nullable=False),
        sa.Column('is_transfer', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_station_connections_id'), 'station_connections', ['id'], unique=False)
    op.create_index(op.f('ix_station_connections_from_station_id'), 'station_connections', ['from_station_id'], unique=False)
    op.create_index(op.f('ix_station_connections_to_station_id'), 'station_connections', ['to_station_id'], unique=False)
    op.create_index(op.f('ix_station_connections_line_id'), 'station_connections', ['line_id'], unique=False)

    # 3. railway_services table
    op.create_table(
        'railway_services',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('line_id', sa.String(length=36), sa.ForeignKey('railway_lines.id', ondelete='CASCADE'), nullable=False),
        sa.Column('service_code', sa.String(length=50), nullable=False),
        sa.Column('service_name', sa.String(length=150), nullable=False),
        sa.Column('direction', sa.String(length=20), nullable=False, server_default='UP'),
        sa.Column('status', sa.String(length=30), nullable=False, server_default='ACTIVE'),
        sa.Column('delay_seconds', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('source', sa.String(length=50), nullable=False, server_default='TIMETABLE'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_railway_services_id'), 'railway_services', ['id'], unique=False)
    op.create_index(op.f('ix_railway_services_line_id'), 'railway_services', ['line_id'], unique=False)

    # 4. service_updates table
    op.create_table(
        'service_updates',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('line_id', sa.String(length=36), sa.ForeignKey('railway_lines.id', ondelete='SET NULL'), nullable=True),
        sa.Column('station_id', sa.String(length=36), sa.ForeignKey('stations.id', ondelete='SET NULL'), nullable=True),
        sa.Column('title', sa.String(length=200), nullable=False),
        sa.Column('description', sa.Text(), nullable=False),
        sa.Column('severity', sa.String(length=20), nullable=False, server_default='INFO'),
        sa.Column('source', sa.String(length=50), nullable=False, server_default='OPERATIONAL_BULLETIN'),
        sa.Column('effective_from', sa.DateTime(timezone=True), nullable=False),
        sa.Column('effective_until', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_service_updates_id'), 'service_updates', ['id'], unique=False)
    op.create_index(op.f('ix_service_updates_line_id'), 'service_updates', ['line_id'], unique=False)
    op.create_index(op.f('ix_service_updates_station_id'), 'service_updates', ['station_id'], unique=False)

    # 5. provider_health table
    op.create_table(
        'provider_health',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('provider_name', sa.String(length=100), nullable=False),
        sa.Column('status', sa.String(length=30), nullable=False, server_default='NOT_CONFIGURED'),
        sa.Column('last_successful_sync', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_error', sa.Text(), nullable=True),
        sa.Column('latency_ms', sa.Integer(), nullable=True),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_provider_health_id'), 'provider_health', ['id'], unique=False)
    op.create_index(op.f('ix_provider_health_provider_name'), 'provider_health', ['provider_name'], unique=True)


def downgrade() -> None:
    op.drop_table('provider_health')
    op.drop_table('service_updates')
    op.drop_table('railway_services')
    op.drop_table('station_connections')
    op.drop_table('railway_lines')
