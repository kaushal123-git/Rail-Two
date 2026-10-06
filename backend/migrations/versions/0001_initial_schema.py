"""0001_initial_schema

Revision ID: 0001_initial_schema
Revises: 
Create Date: 2026-10-05 22:45:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '0001_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. users table
    op.create_table(
        'users',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('phone_number', sa.String(length=20), nullable=False),
        sa.Column('phone_verified', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('email', sa.String(length=255), nullable=True),
        sa.Column('full_name', sa.String(length=100), nullable=False, server_default='Commuter'),
        sa.Column('profile_image_url', sa.String(length=500), nullable=True),
        sa.Column('hashed_mpin', sa.String(length=255), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='ACTIVE'),
        sa.Column('rwallet_balance', sa.Float(), nullable=False, server_default='100.0'),
        sa.Column('last_login_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_users_id', 'users', ['id'])
    op.create_index('ix_users_phone_number', 'users', ['phone_number'], unique=True)
    op.create_index('ix_users_email', 'users', ['email'], unique=True)

    # 2. devices table
    op.create_table(
        'devices',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('device_identifier', sa.String(length=255), nullable=False),
        sa.Column('platform', sa.String(length=50), nullable=False, server_default='android'),
        sa.Column('app_version', sa.String(length=50), nullable=True),
        sa.Column('os_version', sa.String(length=50), nullable=True),
        sa.Column('public_key', sa.Text(), nullable=True),
        sa.Column('integrity_status', sa.String(length=50), nullable=False, server_default='UNVERIFIED'),
        sa.Column('last_seen_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_devices_id', 'devices', ['id'])
    op.create_index('ix_devices_user_id', 'devices', ['user_id'])
    op.create_index('ix_devices_device_identifier', 'devices', ['device_identifier'])

    # 3. sessions table
    op.create_table(
        'sessions',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('device_id', sa.String(length=36), sa.ForeignKey('devices.id', ondelete='SET NULL'), nullable=True),
        sa.Column('refresh_token_hash', sa.String(length=64), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_used_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('ip_hash', sa.String(length=64), nullable=True),
        sa.Column('user_agent', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_sessions_id', 'sessions', ['id'])
    op.create_index('ix_sessions_user_id', 'sessions', ['user_id'])
    op.create_index('ix_sessions_refresh_token_hash', 'sessions', ['refresh_token_hash'], unique=True)

    # 4. otp_requests table
    op.create_table(
        'otp_requests',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('phone_number', sa.String(length=20), nullable=False),
        sa.Column('hashed_otp', sa.String(length=64), nullable=False),
        sa.Column('purpose', sa.String(length=50), nullable=False, server_default='LOGIN'),
        sa.Column('attempts', sa.Integer(), nullable=False, server_default='0'),
        sa.Column('max_attempts', sa.Integer(), nullable=False, server_default='3'),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('consumed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_otp_requests_id', 'otp_requests', ['id'])
    op.create_index('ix_otp_requests_phone_number', 'otp_requests', ['phone_number'])

    # 5. stations table
    op.create_table(
        'stations',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('code', sa.String(length=10), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('display_name', sa.String(length=150), nullable=False),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('city', sa.String(length=50), nullable=False, server_default='Mumbai'),
        sa.Column('zone', sa.String(length=50), nullable=False, server_default='Western'),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_stations_id', 'stations', ['id'])
    op.create_index('ix_stations_code', 'stations', ['code'], unique=True)
    op.create_index('ix_stations_name', 'stations', ['name'])

    # 6. tickets table
    op.create_table(
        'tickets',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('user_id', sa.String(length=36), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('provider', sa.String(length=50), nullable=False, server_default='LOCO_RAIL'),
        sa.Column('provider_ticket_id', sa.String(length=100), nullable=True),
        sa.Column('origin_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=False),
        sa.Column('destination_station_id', sa.String(length=36), sa.ForeignKey('stations.id'), nullable=False),
        sa.Column('journey_type', sa.String(length=20), nullable=False, server_default='SINGLE'),
        sa.Column('ticket_class', sa.String(length=20), nullable=False, server_default='SECOND'),
        sa.Column('passenger_count', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('fare', sa.Float(), nullable=False),
        sa.Column('booking_status', sa.String(length=30), nullable=False, server_default='CREATED'),
        sa.Column('payment_status', sa.String(length=30), nullable=False, server_default='PENDING'),
        sa.Column('ticket_status', sa.String(length=30), nullable=False, server_default='CREATED'),
        sa.Column('issued_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('valid_from', sa.DateTime(timezone=True), nullable=True),
        sa.Column('valid_until', sa.DateTime(timezone=True), nullable=True),
        sa.Column('qr_token_id', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_tickets_id', 'tickets', ['id'])
    op.create_index('ix_tickets_user_id', 'tickets', ['user_id'])
    op.create_index('ix_tickets_ticket_status', 'tickets', ['ticket_status'])

    # 7. ticket_events table
    op.create_table(
        'ticket_events',
        sa.Column('id', sa.String(length=36), primary_key=True),
        sa.Column('ticket_id', sa.String(length=36), sa.ForeignKey('tickets.id', ondelete='CASCADE'), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_ticket_events_id', 'ticket_events', ['id'])
    op.create_index('ix_ticket_events_ticket_id', 'ticket_events', ['ticket_id'])
    op.create_index('ix_ticket_events_event_type', 'ticket_events', ['event_type'])


def downgrade() -> None:
    op.drop_table('ticket_events')
    op.drop_table('tickets')
    op.drop_table('stations')
    op.drop_table('otp_requests')
    op.drop_table('sessions')
    op.drop_table('devices')
    op.drop_table('users')
