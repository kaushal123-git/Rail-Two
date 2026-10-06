"""0004_phase4_geofencing_journeys_location_integrity

Revision ID: 0004_phase4_geofencing_journeys_location_integrity
Revises: 0003_phase3_railway_network_graph
Create Date: 2026-10-06 06:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0004_phase4_geofencing_journeys_location_integrity'
down_revision: Union[str, None] = '0003_phase3_railway_network_graph'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. geofences table
    op.create_table(
        'geofences',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('station_id', sa.String(length=36), sa.ForeignKey('stations.id', ondelete='CASCADE'), nullable=False),
        sa.Column('center_latitude', sa.Float(), nullable=False),
        sa.Column('center_longitude', sa.Float(), nullable=False),
        sa.Column('radius_meters', sa.Float(), nullable=False, server_default='300.0'),
        sa.Column('geofence_type', sa.String(length=30), nullable=False, server_default='STATION'),
        sa.Column('s2_cell_token', sa.String(length=20), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_geofences_id'), 'geofences', ['id'], unique=False)
    op.create_index(op.f('ix_geofences_station_id'), 'geofences', ['station_id'], unique=False)
    op.create_index(op.f('ix_geofences_s2_cell_token'), 'geofences', ['s2_cell_token'], unique=False)

    # 2. journeys table
    op.create_table(
        'journeys',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('device_id', sa.String(length=100), nullable=False),
        sa.Column('origin_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=False),
        sa.Column('destination_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=False),
        sa.Column('route_id', sa.String(length=100), nullable=True),
        sa.Column('status', sa.String(length=30), nullable=False, server_default='ACTIVE'),
        sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('current_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=True),
        sa.Column('last_validated_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=True),
        sa.Column('security_state', sa.String(length=30), nullable=False, server_default='NORMAL'),
        sa.Column('location_confidence', sa.Float(), nullable=False, server_default='1.0'),
        sa.Column('risk_score', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_journeys_id'), 'journeys', ['id'], unique=False)
    op.create_index(op.f('ix_journeys_ticket_id'), 'journeys', ['ticket_id'], unique=True)
    op.create_index(op.f('ix_journeys_user_id'), 'journeys', ['user_id'], unique=False)
    op.create_index(op.f('ix_journeys_device_id'), 'journeys', ['device_id'], unique=False)
    op.create_index(op.f('ix_journeys_status'), 'journeys', ['status'], unique=False)
    op.create_index(op.f('ix_journeys_origin_station_id'), 'journeys', ['origin_station_id'], unique=False)
    op.create_index(op.f('ix_journeys_destination_station_id'), 'journeys', ['destination_station_id'], unique=False)

    # 3. location_events table
    op.create_table(
        'location_events',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('device_id', sa.String(length=100), nullable=False),
        sa.Column('journey_id', sa.String(length=36), sa.ForeignKey('journeys.id', ondelete='CASCADE'), nullable=True),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='CASCADE'), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('accuracy_meters', sa.Float(), nullable=False),
        sa.Column('altitude', sa.Float(), nullable=True),
        sa.Column('speed_mps', sa.Float(), nullable=True),
        sa.Column('bearing', sa.Float(), nullable=True),
        sa.Column('timestamp_device', sa.DateTime(timezone=True), nullable=False),
        sa.Column('timestamp_server', sa.DateTime(timezone=True), nullable=False),
        sa.Column('provider', sa.String(length=50), nullable=False, server_default='gps'),
        sa.Column('is_mock', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('mock_confidence', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('location_source', sa.String(length=50), nullable=False, server_default='device_stream'),
        sa.Column('integrity_status', sa.String(length=30), nullable=False, server_default='VALID'),
        sa.Column('s2_cell_token', sa.String(length=20), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_location_events_id'), 'location_events', ['id'], unique=False)
    op.create_index(op.f('ix_location_events_user_id'), 'location_events', ['user_id'], unique=False)
    op.create_index(op.f('ix_location_events_device_id'), 'location_events', ['device_id'], unique=False)
    op.create_index(op.f('ix_location_events_journey_id'), 'location_events', ['journey_id'], unique=False)
    op.create_index(op.f('ix_location_events_ticket_id'), 'location_events', ['ticket_id'], unique=False)
    op.create_index(op.f('ix_location_events_timestamp_server'), 'location_events', ['timestamp_server'], unique=False)
    op.create_index(op.f('ix_location_events_s2_cell_token'), 'location_events', ['s2_cell_token'], unique=False)

    # 4. fraud_events table
    op.create_table(
        'fraud_events',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('ticket_id', sa.String(length=36), nullable=True),
        sa.Column('journey_id', sa.String(length=36), nullable=True),
        sa.Column('device_id', sa.String(length=100), nullable=True),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('severity', sa.String(length=20), nullable=False, server_default='MEDIUM'),
        sa.Column('confidence', sa.Float(), nullable=False, server_default='1.0'),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('resolved_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(op.f('ix_fraud_events_id'), 'fraud_events', ['id'], unique=False)
    op.create_index(op.f('ix_fraud_events_user_id'), 'fraud_events', ['user_id'], unique=False)
    op.create_index(op.f('ix_fraud_events_ticket_id'), 'fraud_events', ['ticket_id'], unique=False)
    op.create_index(op.f('ix_fraud_events_journey_id'), 'fraud_events', ['journey_id'], unique=False)
    op.create_index(op.f('ix_fraud_events_device_id'), 'fraud_events', ['device_id'], unique=False)
    op.create_index(op.f('ix_fraud_events_event_type'), 'fraud_events', ['event_type'], unique=False)
    op.create_index(op.f('ix_fraud_events_created_at'), 'fraud_events', ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_table('fraud_events')
    op.drop_table('location_events')
    op.drop_table('journeys')
    op.drop_table('geofences')
